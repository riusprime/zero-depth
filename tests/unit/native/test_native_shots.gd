extends GutTest
## The projectile sweep run by the native side (NativeShots, native/src/zd_shots.*), with the contacts' rules in
## GDScript (ProjectileContacts). A tie goes to the wall, then to the lower body; a Void or Wave shot meets walls
## only; a body killed earlier in the same phase is not hit, the shot behind it is; a piercing shot goes on through
## and a bouncing one comes off the wall; a shot out of life ends. The kernel gives the same result from the same
## start, and a snapshot restored mid-run goes on as the run did.


func test_a_tie_goes_to_the_wall_then_to_the_lower_body() -> void:
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
	var w := _scene([], [])
	_shoot(w, Vector2(0.0, 0.0), Vector2(0.25, 0.5), 0.1, 2)
	var ev := _sweep(w)
	assert_eq(ev.size(), 0, "no event while it has life")
	assert_eq(Vector2(w.projectiles.pos_x[0], w.projectiles.pos_y[0]), Vector2(0.25, 0.5))
	assert_eq(w.projectiles.life[0], 1)
	ev = _sweep(w)
	assert_eq([ev[0], ev[1]], [NativeShots.END, 0], "its life ran out")


## The contacts' rules through the whole phase (ProjectileContacts on the native sweep's events): a hit hurts the body
## and ends the shot; a piercing shot hurts the body and goes on to the next; a bouncing one comes back off the wall;
## a shot out of life ends, the others fly on.
func test_the_phase_applies_hits_pierce_bounce_and_range() -> void:
	var hit := _case_hit()
	_phases(hit, 1)
	assert_eq(hit.actors.hp[1], 9, "a body hit")
	assert_eq(hit.projectiles.size(), 0, "the shot ends on it")
	var pierce := _case_pierce()
	_phases(pierce, 3)
	assert_eq([pierce.actors.hp[1], pierce.actors.hp[2]], [9, 9], "a pierce hurts both bodies")
	var bounce := _case_bounce()
	_phases(bounce, 1)
	assert_eq(bounce.projectiles.size(), 1, "a bounce keeps the shot")
	assert_lt(bounce.projectiles.vel_x[0], 0.0, "off the wall")
	var ranged := _case_range()
	_phases(ranged, 1)
	assert_eq(ranged.projectiles.size(), 1, "the shot out of life ends, the other flies on")
	assert_eq(ranged.actors.hp[1], 10)


func test_a_body_killed_earlier_in_the_phase_is_not_hit() -> void:
	var w := _case_dead_mid_phase()
	w._projectile_hits()
	assert_eq(w.actors.dead[1], 1, "the first shot killed the near body")
	assert_eq(w.actors.hp[2], 9, "the second shot hit the body behind")
	assert_eq(w.projectiles.size(), 0)


func test_the_same_start_gives_the_same_result() -> void:
	assert_eq(_scenario_hashes(), _scenario_hashes())


func test_a_snapshot_restored_mid_run_goes_on_as_the_run() -> void:
	var w := KernelScenario.build(5, 20, 5, 240, 8)
	for t in 300:
		w.step(InputFrame.new())
	var snap := w.to_snapshot()
	for t in 300:
		w.step(InputFrame.new())
	var base := KernelScenario.build(5, 20, 5, 240, 8)
	var again := World.from_snapshot(snap, base)
	assert_not_null(again)
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


## A world with the hero far away, still dummies of 10 HP (radius 0.5) at `at`, and the walls.
func _scene(at: Array, walls: Array) -> World:
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native, "every World has its native side")
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


## 20 firing dummies around the hero among 8 walls, 240 ticks; the state hash every 30.
func _scenario_hashes() -> PackedStringArray:
	var w := KernelScenario.build(5, 20, 5, 240, 8)
	var out := PackedStringArray()
	for t in 240:
		w.step(InputFrame.new())
		if t % 30 == 29:
			out.append(w.state_hash())
	return out


## `n` projectile phases on world w, with the body grid the move phase would leave.
func _phases(w: World, n: int) -> void:
	for k in n:
		w._actor_grid.build_circles(w.actors.pos_x, w.actors.pos_y, w.actors.radius)
		w._projectile_hits()
