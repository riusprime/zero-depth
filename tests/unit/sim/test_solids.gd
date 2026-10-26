extends GutTest
## v0.9.5 SB (owner: "... you can't just go through them"): the props that look solid are solid. A hero driven into an
## altar, a pylon, the Loop device or the Ascension portal's frame stays outside its footprint, and still enters the
## devices that take the hero in.

const LONG := 1 << 24


func _bare() -> World:
	var w := World.new(5, PlayerTable.starting_values())
	w.set_walls([] as Array[Obb])
	w.solids.on = true
	w.actors.invuln[0] = LONG
	return w


## Drives the hero from `from` along `dir` for 120 ticks; the closest its centre came to `centre` along dir.
func _drive(w: World, from: Vector2, dir: Vector2, centre: Vector2) -> float:
	w.actors.set_pos(0, from)
	var closest := 1.0e9
	var mv := Vector2i(roundi(dir.x * 127.0), roundi(dir.y * 127.0))
	for t in 120:
		w.step(InputFrame.make(mv, 0, 100, 0, 0))
		closest = minf(closest, Kin.length(w.player_pos() - centre))
	return closest


func test_the_hero_cannot_walk_through_a_reward_altar() -> void:
	var w := _bare()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(5, 0), 0)
	var closest := _drive(w, Vector2(0, 0), Vector2(1, 0), Vector2(5, 0))
	assert_eq(w.solids.placed_count(), 1)
	assert_gte(closest, w.actors.radius[0] + Solids.PROP_HALF_M - 0.05)
	assert_lt(w.player_pos().x, 5.0 - Solids.PROP_HALF_M)


func test_a_prop_under_the_hero_waits_until_the_hero_is_clear() -> void:
	var w := _bare()
	w.actors.set_pos(0, Vector2(5, 0))
	w.add_reward(RewardStore.Kind.CHEST, Vector2(5, 0), 10)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
	assert_eq(w.solids.placed_count(), 0)
	_drive(w, Vector2(5, 0), Vector2(-1, 0), Vector2(5, 0))
	assert_eq(w.solids.placed_count(), 1)


func test_taking_a_reward_removes_its_footprint() -> void:
	var w := _bare()
	var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(5, 0), 0)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
	assert_eq(w.solids.placed_count(), 1)
	w.solids.remove(w, Solids.Kind.REWARD, id)
	assert_eq(w.solids.placed_count(), 0)
	assert_eq(w.walls.size(), 0)
	assert_true(w.solids.is_empty())


func test_the_hero_cannot_walk_through_a_pylon() -> void:
	var w := _bare()
	w.solids.add_square(Solids.Kind.PYLON, 0, Vector2(0, 6), Solids.PYLON_HALF_M)
	var closest := _drive(w, Vector2(0, 0), Vector2(0, 1), Vector2(0, 6))
	assert_gte(closest, w.actors.radius[0] + Solids.PYLON_HALF_M - 0.05)


func test_a_world_without_the_rules_adds_nothing() -> void:
	var w := _bare()
	w.solids.on = false
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(5, 0), 0)
	assert_true(w.solids.is_empty())


func test_a_floor_saved_before_sb_builds_no_solids() -> void:
	assert_false(Solids.rules_on(_run_with_rules(RunState.FLOOR_RULES_V090_CF2)))
	assert_true(Solids.rules_on(_run_with_rules(RunState.FLOOR_RULES_V095_SB)))


func _run_with_rules(rules: int) -> RunState:
	var r := RunState.start(1, _run_table())
	r.floor_rules = rules
	return r


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(_repo().get_def(&"run", RunSaver.RUN_ID))


func _floor_world(run: RunState) -> World:
	var repo := _repo()
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var w := FloorScenario.build(
		run.floor_seed(),
		PlayerTable.starting_values(),
		enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		run.floor_index,
		null,
		run,
		ContentCompiler.compile_combos(repo)
	)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	w.set_boss_tables(bosses)
	w.actors.invuln[0] = LONG
	return w


func _last_floor_world(seed_value: int) -> World:
	var r := RunState.start(seed_value, _run_table())
	for k in r.table.floors - 1:
		var w := _floor_world(r)
		w.boss_flow.route_taken = Routes.Route.NORMAL
		r.finish_floor(w)
	var last := _floor_world(r)
	last.boss_flow.state = BossFlow.State.OPEN
	last.boss_flow.ascend_open = true
	return last


## Generation safety (SB step 5): across seeds and floors, no prop's footprint blocks a doorway or the spot a step
## inside it (a 0.45 m circle, the hero and a hand to spare, stands free at each door's centre and approaches).
func test_no_footprint_blocks_a_doorway_over_many_seeds() -> void:
	var blocked := []
	var props := 0
	for s in range(1, 41):
		var r := RunState.start(s, _run_table())
		for fl in 3:
			var w := _floor_world(r)
			var f := w.floor_layout
			props += w.solids.size()
			for i in w.solids.size():
				var o := w.solids.obb(i)
				var spots := PackedVector2Array(f.door_centers)
				for room in f.rooms.size():
					spots.append_array(f.door_approaches(room, 1.0))
				for p in spots:
					if Collide.circle_vs_obb(p, 0.45, o) != Vector2.ZERO:
						blocked.append(
							(
								"seed %d floor %d kind %d at %s"
								% [s, fl, w.solids.kind[i], str(o.center)]
							)
						)
			w.boss_flow.route_taken = Routes.Route.NORMAL
			r.finish_floor(w)
	gut.p("%d props checked" % props)
	assert_gt(props, 100)
	assert_eq(blocked.size(), 0, "\n".join(blocked.slice(0, 10)))


func test_the_loop_device_is_solid_and_stepping_to_it_still_enters() -> void:
	var w := _last_floor_world(11)
	var f := w.floor_layout
	assert_true(f.has_loop_device)
	assert_ne(w.solids.find(Solids.Kind.LOOP_DEVICE, 0), -1)
	var front := Kin.dir(f.loop_angle)
	var at := f.loop_pos + front * 2.5
	w.actors.set_pos(0, at)
	var mv := Vector2i(roundi(-front.x * 127.0), roundi(-front.y * 127.0))
	var closest := 1.0e9
	for t in 120:
		w.step(InputFrame.make(mv, 0, 100, 0, 0))
		closest = minf(closest, Kin.length(w.player_pos() - f.loop_pos))
	assert_eq(w.boss_flow.ascend_choice, Ascension.Choice.LOOP, "stepping to the device enters it")
	assert_gte(closest, w.actors.radius[0] + Ascension.LOOP_HALF_M - 0.05)


func test_the_ascension_portal_is_solid_and_walking_into_it_still_enters() -> void:
	var w := _last_floor_world(11)
	var f := w.floor_layout
	var n := Kin.dir(f.portal_angle)
	w.actors.set_pos(0, f.portal_pos + n * 3.0)
	var mv := Vector2i(roundi(-n.x * 127.0), roundi(-n.y * 127.0))
	var closest := 1.0e9
	for t in 120:
		w.step(InputFrame.make(mv, 0, 100, 0, 0))
		closest = minf(closest, Kin.length(w.player_pos() - f.portal_pos))
	assert_eq(w.boss_flow.ascend_choice, Ascension.Choice.ASCENSION)
	assert_gte(closest, w.actors.radius[0] + FloorLayout.GATE_HALF_DEPTH - 0.05)
