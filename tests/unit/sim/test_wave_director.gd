extends GutTest
## The Combat Lab encounter (PLAN v0.1.0 Step 5): waves arrive in order, away from the player; clearing the last
## wins; a dead player stops the director and is told what killed them.


func _world() -> World:
	var repo := ContentRepository.load_all()
	var enc := ContentCompiler.compile_encounter(repo.get_def(&"encounters", &"combat_lab"), repo)
	return StageScenario.build(77, PlayerTable.starting_values(), CombatLab.tables(), enc)


func _kill_all(w: World) -> void:
	for i in range(1, w.actors.size()):
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 9999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))  # from inside: no shield


func _kinds(w: World) -> Array:
	var out := []
	for i in range(1, w.actors.size()):
		out.append(w.actors.kinds[i])
	out.sort()
	return out


func test_waves_arrive_in_order_and_far_from_the_player() -> void:
	var w := _world()
	var expected := w.encounter.waves
	assert_eq(expected.size(), 3)
	for k in expected.size():
		var waited := CombatLab.until(w, func(x: World) -> bool: return x.wave_index == k, 200)
		assert_gte(waited, 0, "wave %d arrives" % (k + 1))
		var want: Array = expected[k].duplicate()
		want.sort()
		assert_eq(_kinds(w), want, "wave %d has its enemies" % (k + 1))
		for i in range(1, w.actors.size()):
			assert_gte(
				Kin.length(w.actors.pos(i) - w.player_pos()), 6.0, "spawned at least 6 m away"
			)
		assert_false(w.cleared)
		_kill_all(w)
	CombatLab.idle(w, 3)
	assert_true(w.cleared, "the last wave cleared wins")


func test_a_dead_player_stops_the_waves_and_knows_the_killer() -> void:
	var w := _world()
	CombatLab.until(w, func(x: World) -> bool: return x.wave_index == 0, 200)
	var i := 1
	Damage.hit(
		w,
		0,
		9999,
		w.actors.ids[i],
		w.actors.ids[i],
		5,
		SimEvent.TAG_MELEE,
		Vector2.ZERO,
		Vector2.ZERO
	)
	assert_eq(w.killer_kind, w.actors.kinds[i])
	_kill_all(w)
	CombatLab.idle(w, 200)
	assert_eq(w.wave_index, 0, "no more waves after death")
