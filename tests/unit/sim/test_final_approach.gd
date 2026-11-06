extends GutTest
## v0.9.0 FA (owner C §3: "The player should no longer teleport directly into the final boss arena … The player must
## activate a small number of mechanisms, approximately two, around the altar … The boss sequence must only trigger
## once the required activations are complete … without adding a long or tedious gameplay section"; Q18: the stair
## causeway, one press per pylon, the plateau is the arena). The final approach in the sim (FinalApproach,
## FinalArena.approach_layout): the hero arrives at the causeway's foot about 25 m below the plateau; nothing else
## lives there; the boss never starts before both pylons are on (one press each, either order); the buildup then runs
## and when it ends the walls of light close the ring (a hero still on the causeway is set back on the plateau) and the
## Colossus rises from the altar. Saves on the approach and at the fight's start resume exactly; a save made in the
## final arena before FA resumes its ring arena bare. The whole approach takes well under 30 s at a walk.

const SEED := 20261022


func _press(dir: Vector2 = Vector2.ZERO) -> InputFrame:
	var f := InputFrame.make(
		Vector2i(roundi(dir.x * SimTick.MOVE_MAX), roundi(dir.y * SimTick.MOVE_MAX)),
		0,
		1000,
		InputFrame.INTERACT,
		InputFrame.INTERACT
	)
	return f


func _world(seed_value: int = SEED) -> World:
	var w := FinalLab.approach(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = 1 << 24
	return w


## Walks the hero to `to` (straight, FinalLab.walk), at most `limit` ticks; the ticks it took.
func _walk(w: World, to: Vector2, limit: int = 1200) -> int:
	for k in limit:
		if w.player_pos().distance_to(to) < 1.4:  # v0.9.5 SB: a pylon is solid (1 m square): the hero stops at its surface
			return k
		w.step(FinalLab.walk(w, to))
	return limit


## Up the causeway onto the plateau, then to pylon k.
func _to_pylon(w: World, k: int) -> int:
	var f := w.floor_layout
	var t := 0
	if w.player_pos().length() > FinalArena.radius_of(f) - 2.0:
		t += _walk(w, f.causeway_top * 0.8)
	return t + _walk(w, f.pylons[k])


func test_the_approach_is_a_causeway_up_to_the_plateau() -> void:
	var w := _world()
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	assert_true(reader.final_approach(), "the run's way in is the approach")
	assert_true(reader.final_arena(), "it is the final arena's world")
	assert_false(reader.has_gate(), "no run gate")
	assert_false(reader.floor_receiver(), "no floor receiver")
	assert_eq(reader.approach_state(), WorldReader.APPROACH_WALK)
	var r := FinalArena.radius_of(f)
	assert_almost_eq(r, 15.0, 0.01, "the plateau is the arena's ring")
	assert_eq(f.light_walls.size(), FinalArena.GAP_SEGMENTS, "the gap the walls of light close")
	assert_almost_eq(
		f.causeway_top.distance_to(f.causeway_foot),
		FinalArena.CAUSEWAY_M - FinalArena.FOOT_IN,
		0.01,
		"about 25 m of causeway"
	)
	assert_eq(w.player_pos(), f.causeway_foot, "the hero arrives at its foot")
	assert_gt(w.player_pos().length(), r + 20.0, "below the plateau")
	assert_eq(f.altar_pos, f.boss_spawn, "the boss rises from the altar")
	assert_eq(f.pylons.size(), 2, "two pylons")
	for p in f.pylons:
		assert_lt(p.length(), r - 2.0, "on the plateau")
		assert_gt(
			p.distance_to(f.altar_pos), AltarStage.RADIUS + 2.0, "beside the altar, not on it"
		)
	var path := [f.causeway_foot, f.causeway_top * 0.8, f.altar_pos]
	for o in w.walls:
		for j in 2:
			var a: Vector2 = path[j]
			var b: Vector2 = path[j + 1]
			for s in 21:
				var q := a.lerp(b, s / 20.0)
				assert_eq(Collide.circle_vs_obb(q, 0.5, o), Vector2.ZERO, "a clear path up")
	assert_null(w.final_fight, "no fight yet")
	CombatLab.idle(w, 600)
	var others := 0
	for i in range(1, w.actors.size()):
		others += 1 if w.actors.dead[i] == 0 else 0
	assert_eq(others, 0, "nobody but the hero, however long (no horde, no boss)")
	assert_eq(w.shards, 0, "no shards")


func test_the_boss_never_starts_before_both_pylons() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	CombatLab.idle(w, 60)
	for k in 30:
		w.step(_press())  # far from any pylon: nothing
	assert_eq(reader.approach_pylons_lit(), 0)
	_to_pylon(w, 0)
	assert_eq(reader.approach_pylon_in_reach(), 0, "the prompt shows by pylon A")
	w.step(_press())
	assert_true(reader.approach_pylon_lit(0), "one press switches it on")
	assert_eq(reader.approach_pylon_in_reach(), -1, "a lit one takes no more presses")
	for k in 600:
		w.step(_press() if k % 2 == 0 else InputFrame.new())
	assert_eq(reader.approach_pylons_lit(), 1, "still one")
	assert_eq(reader.approach_state(), WorldReader.APPROACH_WALK)
	assert_null(w.final_fight, "no boss with one pylon, however long")
	assert_lt(reader.approach_buildup_progress(), 0.0)


func test_both_pylons_start_the_buildup_then_the_walls_and_the_colossus() -> void:
	for order: Array in [[0, 1], [1, 0]]:
		var w := _world()
		var reader := WorldReader.new(w)
		var tag := "order %s" % str(order)
		var walls0 := w.walls.size()  # v0.9.5 SB: the pylons stand apart
		_to_pylon(w, order[0])
		w.step(_press())
		_to_pylon(w, order[1])
		w.step(_press())
		assert_eq(reader.approach_state(), WorldReader.APPROACH_BUILDUP, "%s: the buildup" % tag)
		assert_null(w.final_fight, "%s: not yet" % tag)
		var t0 := w.tick
		while reader.approach_state() == WorldReader.APPROACH_BUILDUP and w.tick - t0 < 400:
			assert_eq(w.walls.size(), walls0, "%s: open during the buildup" % tag)
			w.step(InputFrame.new())
		assert_eq(w.tick - t0, FinalApproach.BUILDUP_TICKS, "%s: ~3 s of buildup" % tag)
		assert_true(reader.approach_walls_up(), "%s: the walls of light" % tag)
		assert_eq(w.walls.size(), walls0 + FinalArena.GAP_SEGMENTS, "%s: the ring closed" % tag)
		assert_not_null(w.final_fight, "%s: the fight began" % tag)
		var i := FinalLab.body(w)
		assert_eq(w.actors.kinds[i], ActorStore.Kind.COLOSSUS, "%s: the Colossus" % tag)
		assert_eq(w.actors.pos(i), w.floor_layout.altar_pos, "%s: from the altar" % tag)
		assert_ne(w.final_fight.name_key, &"", "%s: its name" % tag)


func test_a_hero_on_the_causeway_is_set_back_on_the_plateau() -> void:
	var w := _world()
	_to_pylon(w, 0)
	w.step(_press())
	_to_pylon(w, 1)
	w.step(_press())
	w.actors.set_pos(0, w.floor_layout.causeway_foot)  # TEST: back down the causeway mid-buildup
	CombatLab.idle(w, FinalApproach.BUILDUP_TICKS + 2)
	var r := FinalArena.radius_of(w.floor_layout)
	assert_lt(w.player_pos().length(), r, "inside the ring when it closed")
	for k in 240:  # walking out toward the causeway: the light walls hold
		w.step(FinalLab.walk(w, w.floor_layout.causeway_foot))
	assert_lt(w.player_pos().length(), r, "nothing leaves the ring")


func test_the_approach_takes_well_under_thirty_seconds_at_a_walk() -> void:
	var w := _world()
	var t := _to_pylon(w, 0) + 1
	w.step(_press())
	t += _to_pylon(w, 1) + 1
	w.step(_press())
	t += FinalApproach.BUILDUP_TICKS
	CombatLab.idle(w, FinalApproach.BUILDUP_TICKS + 1)
	assert_not_null(w.final_fight)
	gut.p("arrival to the Colossus at a walk: %d ticks (%.1f s)" % [t, t / 60.0])
	assert_lt(t, 30 * SimTick.TICKS_PER_SECOND, "under 30 s (C33)")


func test_saves_on_the_approach_and_at_the_fight_resume_exactly() -> void:
	var w := _world()
	_to_pylon(w, 0)
	w.step(_press())
	var snap := WorldSnapshot.take(w)
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save with one pylon on fits")
	assert_eq(base.state_hash(), w.state_hash(), "restored exactly")
	assert_true(WorldReader.new(base).approach_pylon_lit(0))
	_to_pylon(w, 1)
	w.step(_press())
	CombatLab.idle(w, FinalApproach.BUILDUP_TICKS + 1)
	assert_not_null(w.final_fight)
	var fight := WorldSnapshot.take(w)  # RunSaver's save at the first body's start
	var base2 := _world()
	assert_eq(WorldSnapshot.apply(base2, fight), "", "a save at the fight fits")
	assert_eq(base2.state_hash(), w.state_hash(), "restored exactly")
	assert_eq(base2.walls.size(), w.walls.size(), "the walls of light come back")
	assert_true(WorldReader.new(base2).approach_walls_up())
	for k in 120:
		w.step(InputFrame.new())
		base2.step(InputFrame.new())
	assert_eq(base2.state_hash(), w.state_hash(), "the same fight after it")
	assert_true(FloorPlan.approach_of({}), "a fresh arrival: the approach")
	assert_true(FloorPlan.approach_of({"world": snap}), "a save on the approach")
	var bare := FinalLab.arena(FinalLab.run_state(SEED))
	var old := WorldSnapshot.take(bare)
	(old["world"] as Dictionary).erase(&"approach")  # a save from before FA
	(old["world"] as Dictionary).erase("approach")
	assert_false(FloorPlan.approach_of({"world": old}), "an older save: the ring arena bare")
	var base3 := FinalLab.arena(FinalLab.run_state(SEED), false)
	assert_eq(WorldSnapshot.apply(base3, old), "", "it still resumes")
	assert_null(base3.approach)


func test_the_direct_path_is_unchanged() -> void:
	var w := FinalLab.arena(FinalLab.run_state(SEED))
	assert_null(w.approach, "the tests' and tools' path: no approach")
	assert_not_null(w.final_fight, "the fight from the start")
	assert_eq(FinalArena.segments_of(w.floor_layout), 32, "the whole ring")
