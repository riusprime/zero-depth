extends GutTest
## The projectile sweep run by the native side (NativeShots, native/src/zd_shots.*): the same rules as the GDScript
## loop of World._projectile_hits. A tie goes to the wall, then to the lower body; a Void or Wave shot meets walls
## only; a body killed earlier in the same phase is not hit, the shot behind it is; a piercing shot goes on through
## and a bouncing one comes off the wall as in GDScript; a shot out of life ends. The kernel gives the same result
## from the same start, and a snapshot restored mid-run goes on as the run did. Pending without the native library.

var _kept := Callable()
var _kept_kernels := 0


func before_all() -> void:
	_kept = World.native_factory
	_kept_kernels = World.native_kernels


func after_all() -> void:
	World.native_factory = _kept
	World.native_kernels = _kept_kernels


func test_a_tie_goes_to_the_wall_then_to_the_lower_body() -> void:
	if not _have_lib():
		return
	var wall := Obb.make(Vector2(2.0, 0.0), Vector2(0.5, 3.0), 0)
	var w := _scene([Vector2(1.45, 0.0), Vector2(1.45, 0.05)], [wall])
	_shoot(w, Vector2(1.45, 0.0), Vector2(0.5, 0.0), 0.1, 30)  # Starts inside both bodies and the wall's reach
	_shoot(w, Vector2(-3.0, 0.0), Vector2(0.0, 0.0), 0.1, 30)  # Still, away from everything
	var ev := _sweep(w)
	assert_eq(ev.size(), 4, "one contact")
	assert_eq([ev[0], ev[1], ev[2], ev[3]], [NativeShots.CONTACT, 0, -1, 0], "the wall wins a tie")
	assert_eq(w.native.shot_t()[0], 0.0)
	w.actors.set_pos(1, Vector2(-3.0, 0.0))
	w.actors.set_pos(2, Vector2(-3.0, 0.05))
	ev = _sweep(w)
	assert_eq(ev.size(), 8, "two contacts")
	assert_eq(
		[ev[4], ev[5], ev[6], ev[7]], [NativeShots.CONTACT, 1, 1, -1], "the lower body wins a tie"
	)


func test_a_void_shot_meets_walls_only() -> void:
	if not _have_lib():
		return
	var wall := Obb.make(Vector2(3.0, 0.0), Vector2(0.5, 3.0), 0)
	var w := _scene([Vector2(1.0, 0.0)], [wall])
	_shoot(w, Vector2(0.0, 0.0), Vector2(4.0, 0.0), 0.1, 30)
	var ev := _sweep(w)
	assert_eq([ev[0], ev[2], ev[3]], [NativeShots.CONTACT, 1, -1], "a plain shot meets the body")
	var through := PackedByteArray([1])
	assert_eq(w.native.sweep_shots(w.projectiles, w.actors, PackedByteArray(), through), 1)
	ev = w.native.shot_events()
	assert_eq(
		[ev[0], ev[2], ev[3]], [NativeShots.CONTACT, -1, 0], "a Void shot passes it to the wall"
	)
	var t: float = w.native.shot_t()[0]
	assert_almost_eq(t, (2.5 - 0.1) / 4.0, 0.0001)


func test_a_shot_that_meets_nothing_is_advanced_and_ends_with_its_life() -> void:
	if not _have_lib():
		return
	var w := _scene([], [])
	_shoot(w, Vector2(0.0, 0.0), Vector2(0.25, 0.5), 0.1, 2)
	var ev := _sweep(w)
	assert_eq(ev.size(), 0, "no event while it has life")
	assert_eq(Vector2(w.projectiles.pos_x[0], w.projectiles.pos_y[0]), Vector2(0.25, 0.5))
	assert_eq(w.projectiles.life[0], 1)
	ev = _sweep(w)
	assert_eq([ev[0], ev[1]], [NativeShots.END, 0], "its life ran out")


func test_the_phase_gives_what_gdscript_gives() -> void:
	if not _have_lib():
		return
	var cases := {
		"a body hit": _case_hit,
		"a dead body passed for the one behind": _case_dead_mid_phase,
		"a pierce": _case_pierce,
		"a bounce": _case_bounce,
		"the end of range": _case_range,
	}
	for name: String in cases:
		var got: Array = []
		for native in [false, true]:
			var w: World = (cases[name] as Callable).call()
			if not native:
				w.native_on = 0
			# The GDScript loop reads the body grid the move phase leaves (World._resolve_bodies)
			w._actor_grid.build_circles(w.actors.pos_x, w.actors.pos_y, w.actors.radius)
			w._projectile_hits()
			got.append(_outcome(w))
		assert_eq(got[1], got[0], "%s: native as GDScript" % name)


func test_a_body_killed_earlier_in_the_phase_is_not_hit() -> void:
	if not _have_lib():
		return
	var w := _case_dead_mid_phase()
	w._projectile_hits()
	assert_eq(w.actors.dead[1], 1, "the first shot killed the near body")
	assert_eq(w.actors.hp[2], 9, "the second shot hit the body behind")
	assert_eq(w.projectiles.size(), 0)


func test_the_same_start_gives_the_same_result() -> void:
	if not _have_lib():
		return
	assert_eq(_scenario_hashes(), _scenario_hashes())


func test_a_snapshot_restored_mid_run_goes_on_as_the_run() -> void:
	if not _have_lib():
		return
	NativeSwitch.install(NativeWorld.SHOTS)
	var w := KernelScenario.build(5, 20, 5, 240, 8)
	for t in 300:
		w.step(InputFrame.new())
	var snap := w.to_snapshot()
	for t in 300:
		w.step(InputFrame.new())
	var base := KernelScenario.build(5, 20, 5, 240, 8)
	var again := World.from_snapshot(snap, base)
	assert_not_null(again)
	assert_ne(again.native_on & NativeWorld.SHOTS, 0)
	for t in 300:
		again.step(InputFrame.new())
	assert_eq(again.state_hash(), w.state_hash())


# --- Scenes -----------------------------------------------------------------------------------------------------


func _case_hit() -> World:
	var w := _scene([Vector2(2.0, 0.0)], [])
	_shoot(w, Vector2(0.0, 0.0), Vector2(2.0, 0.0), 0.1, 30)
	return w


## Two shots at a body of 1 HP with a body of 10 behind it: the first kills it, the second goes on to the other.
func _case_dead_mid_phase() -> World:
	var w := _scene([Vector2(5.0, 0.0), Vector2(6.2, 0.0)], [])
	w.actors.hp[1] = 1
	_shoot(w, Vector2(4.0, 0.0), Vector2(2.0, 0.0), 0.1, 30)
	_shoot(w, Vector2(4.0, 0.0), Vector2(2.0, 0.0), 0.1, 30)
	return w


func _case_pierce() -> World:
	var w := _scene([Vector2(2.0, 0.0), Vector2(4.0, 0.0)], [])
	_shoot(w, Vector2(0.0, 0.0), Vector2(2.0, 0.0), 0.1, 30)
	w.projectiles.moves = true
	w.projectiles.pierce_left[0] = 1
	return w


func _case_bounce() -> World:
	var wall := Obb.make(Vector2(2.0, 0.0), Vector2(0.5, 3.0), 0)
	var w := _scene([], [wall])
	_shoot(w, Vector2(0.0, 0.3), Vector2(2.0, 0.0), 0.1, 30, 1)
	return w


func _case_range() -> World:
	var w := _scene([Vector2(0.0, 5.0)], [])
	_shoot(w, Vector2(0.0, 0.0), Vector2(1.0, 0.0), 0.1, 1)
	_shoot(w, Vector2(0.0, 0.0), Vector2(0.0, 1.0), 0.1, 5)
	return w


## A world with the hero far away, still dummies of 10 HP (radius 0.5) at `at`, and the walls; the shots kernel on.
func _scene(at: Array, walls: Array) -> World:
	NativeSwitch.install(NativeWorld.SHOTS)
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native, "the factory made a native side")
	var list: Array[Obb] = []
	list.assign(walls)
	w.set_walls(list)
	w.dummy_speed = 0.0
	w.actors.set_pos(0, Vector2(-40, -40))
	for p: Vector2 in at:
		w.add_dummy(p, 0.5, 10)
	return w


## A hero's shot of 1 damage, in flight now (the spawn phase run).
func _shoot(w: World, at: Vector2, vel: Vector2, r: float, life: int, bounces := 0) -> void:
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		at,
		vel,
		1,
		r,
		life,
		SimEvent.TAG_PROJECTILE,
		bounces
	)
	w._apply_spawns()


func _sweep(w: World) -> PackedInt32Array:
	NativeWorld.sync_walls(w)
	var n: int = w.native.sweep_shots(w.projectiles, w.actors, PackedByteArray(), PackedByteArray())
	assert_gte(n, 0)
	return w.native.shot_events()


## What a projectile phase left: the bodies' HP and deaths, each shot's place, velocity and life.
func _outcome(w: World) -> Array:
	var p := w.projectiles
	var shots := []
	for i in p.size():
		shots.append([p.ids[i], p.pos_x[i], p.pos_y[i], p.vel_x[i], p.vel_y[i], p.life[i]])
	return [Array(w.actors.hp), Array(w.actors.dead), shots]


## 20 firing dummies around the hero among 8 walls, 240 ticks; the state hash every 30.
func _scenario_hashes() -> PackedStringArray:
	NativeSwitch.install(NativeWorld.SHOTS)
	var w := KernelScenario.build(5, 20, 5, 240, 8)
	assert_ne(w.native_on & NativeWorld.SHOTS, 0)
	var out := PackedStringArray()
	for t in 240:
		w.step(InputFrame.new())
		if t % 30 == 29:
			out.append(w.state_hash())
	return out


func _have_lib() -> bool:
	if NativeSwitch.available():
		return true
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false
