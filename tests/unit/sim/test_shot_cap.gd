extends GutTest
## v0.8.0 PF (owner O9: Spread + Split + Explosive "goes two FPS"): the player's projectiles alive at once are capped
## at SimTuning.player_shots_max (data/tuning/sim.tres). A bolt past it is not launched and the tick's first such bolt
## leaves one LIMIT event; below the cap every bolt flies as before.


func _world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.dummy_speed = 0.0
	return w


## A fan of `count` slow, long-lived bolts (they stay alive across the test's ticks).
static func _fan(count: int) -> AttackSpec:
	var s := AttackSpec.new()
	s.form = AttackSpec.Form.BOLT
	s.count = count
	s.spread = 512
	s.speed = 0.01
	s.life_ticks = 600
	s.radius_m = 0.1
	s.damage = 1
	return s


func _fire(w: World, s: AttackSpec) -> void:
	Attacks.launch(
		w, s, AttackContext.make(w.player_pos(), 0, 1, w.take_root(), SimEvent.TAG_PROJECTILE, &"")
	)


func _limits(w: World) -> Array:
	return w.events_since(0).filter(
		func(e: SimEvent) -> bool:
			return e.kind == SimEvent.Kind.LIMIT and e.effect_id == Attacks.EFFECT_SHOT_CAP
	)


func _step(w: World) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))


func test_the_shipped_cap_is_the_tuning_default() -> void:
	assert_eq(SimTuning.new().player_shots_max, Attacks.MAX_PLAYER_SHOTS)
	var repo := ContentRepository.load_all()
	var t := RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	assert_eq(t.player_shots_max, Attacks.MAX_PLAYER_SHOTS, "data/tuning/sim.tres")


func test_below_the_cap_every_bolt_flies() -> void:
	var w := _world()
	_fire(w, _fan(9))
	assert_eq(w.pending_projectiles(), 9)
	_step(w)
	assert_eq(w.player_projectiles(), 9)
	assert_eq(_limits(w).size(), 0, "no LIMIT under the cap")


func test_past_the_cap_bolts_are_not_launched_with_one_limit_event() -> void:
	var w := _world()
	w.tuning.player_shots_max = 5
	_fire(w, _fan(4))
	_fire(w, _fan(4))
	_fire(w, _fan(4))
	assert_eq(w.pending_projectiles(), 5, "the first five of twelve")
	var lim := _limits(w)
	assert_eq(lim.size(), 1, "one LIMIT for the tick")
	assert_eq(lim[0].amount, 5)
	_step(w)
	assert_eq(w.player_projectiles(), 5)


func test_the_cap_counts_the_bolts_already_alive() -> void:
	var w := _world()
	w.tuning.player_shots_max = 6
	_fire(w, _fan(4))
	_step(w)
	_fire(w, _fan(4))
	assert_eq(w.pending_projectiles(), 2, "four alive: room for two")
	_step(w)
	assert_eq(w.player_projectiles(), 6)
	_fire(w, _fan(1))
	assert_eq(w.pending_projectiles(), 0, "still full")
	assert_eq(_limits(w).size(), 2, "one LIMIT in each capped tick")


func test_room_comes_back_as_bolts_end() -> void:
	var w := _world()
	w.tuning.player_shots_max = 3
	var s := _fan(3)
	s.life_ticks = 2
	_fire(w, s)
	for k in 4:
		_step(w)
	assert_eq(w.player_projectiles(), 0, "they ended")
	_fire(w, _fan(3))
	assert_eq(w.pending_projectiles(), 3)


func test_the_cap_is_deterministic() -> void:
	var a := _world()
	var b := _world()
	for w: World in [a, b]:
		w.tuning.player_shots_max = 7
		for k in 6:
			_fire(w, _fan(3))
			_step(w)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.player_projectiles(), 7)


func test_a_snapshot_without_the_cap_fields_restores() -> void:
	var w := _world()
	_fire(w, _fan(2))
	_step(w)
	var snap := WorldSnapshot.take(w)
	var data: Dictionary = snap["world"]
	assert_true(data.has(&"shot_count"), "the snapshot keeps the count")
	data.erase(&"shot_tick")
	data.erase(&"shot_count")
	var restored := World.new(3, PlayerTable.starting_values())
	assert_eq(WorldSnapshot.apply(restored, snap), "", "an older save lacks the fields")
	assert_eq(restored.state_hash(), w.state_hash())
