extends GutTest
## v0.9.0 DP (owner Q26b: "the purple portal should be linked to one of the new puzzles or events, not be there as
## default"; "one of the event rooms, in a big room, has activation purple runes … when you kill the boss the purple
## portal appears"; "never in floor 1, 50% of appearing in floor 2 if does not appear, then warrantee on the next
## floor"; the lead's reading: one a loop, none on floors 4-5): the sim side of the Purple Portal being earned.
## - The chance: floor 1 never, floor 2 at the data's 50 % (over 2,000 run seeds), floor 3 certain when floor 2 had
##   none and never when it had one, floors 4-5 never, the same again on each loop, none on a floor saved before DP.
## - Whole runs as Main builds them (FloorPlan, the normal route): one purple room a loop, on floor 2 or 3 only.
## - No Deep gate unless earned: the boss's death opens the gate alone; the dais (one press, "Awaken") earns it: the
##   Deep gate's footprint stands, the boss's death opens both (PORTAL_OPENED amount 1), walking in makes the next
##   floor Deep. Awakened after the boss died, it opens at once. A second press does nothing; the runes stay lit.
## - A floor saved before DP (floor rules 11) keeps the Deep gate as it was (every floor before the last).
## - A save after the runes were awakened resumes exactly (the Deep gate's footprint comes back with the walls).

const LONG := 1 << 24

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _secrets() -> SecretsDefinition:
	return _repo.get_def(&"secrets", &"secrets")


func _run(seed_value: int = 1) -> RunState:
	return RunState.start(
		seed_value, ContentCompiler.compile_run(_repo.get_def(&"run", RunSaver.RUN_ID)), &"blade"
	)


## Floor 2 of the first run seed from `first` whose floor 2 holds the purple runes (as Main builds it).
func _purple_floor(first: int = 1) -> World:
	for s in range(first, first + 40):
		var w := SaveLab.floor_world(s, 2)
		if w.purple != null:
			w.actors.invuln[0] = LONG
			w.spawner = null
			w.boss_flow.arrive_left = 0  # no arrival hold (the floor starts at once)
			return w
	return null


func _press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


## Stands the hero on the dais and presses interact (two ticks).
func _awaken(w: World) -> void:
	w.actors.set_pos(0, w.floor_layout.purple_pos + Vector2(0.3, 0.0))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	w.step(_press())


func _beat_boss(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 4)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "the fight began")
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 9999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the boss is dead, the gates formed")


func _opened_amount(w: World) -> int:
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.PORTAL_OPENED:
			return e.amount
	return -1


func test_the_chance_per_floor_and_one_a_loop() -> void:
	var per := _secrets().purple_floor_permille
	assert_eq(
		per,
		PackedInt32Array([0, 500, 1000, 0, 0]),
		"the data: never 1, half on 2, sure on 3, none on 4-5"
	)
	var r := _run()
	var want := {1: 0, 2: 500, 3: 1000, 4: 0, 5: 0}
	for f: int in want:
		r.floor_index = f
		assert_eq(PurpleRunes.chance(r, per), want[f], "floor %d with none yet" % f)
	r.purple_floors = PackedInt32Array([2])
	r.floor_index = 3
	assert_eq(PurpleRunes.chance(r, per), 0, "floor 2 had it: never floor 3 too")
	r.loop = 2
	r.loop_floors = 5
	r.floor_index = 2
	assert_eq(PurpleRunes.chance(r, per), 500, "a new loop: the same rule again")
	r.floor_index = 1
	assert_eq(PurpleRunes.chance(r, per), 0, "never a loop's floor 1")
	r.floor_index = 2
	r.floor_rules = RunState.FLOOR_RULES_V090_RA
	assert_eq(PurpleRunes.chance(r, per), 0, "a floor saved before DP holds none")


func test_floor_two_draws_it_half_the_time() -> void:
	var hits := 0
	var n := 2000
	for s in n:
		var r := _run(1 + s * 7919)
		r.floor_index = 2
		var draw := RngStream.derive(r.floor_seed(), PurpleRooms.STREAM)
		if draw.chance_permille(PurpleRunes.chance(r, _secrets().purple_floor_permille)):
			hits += 1
	gut.p("PURPLE_CHANCE| floor2 seeds=%d drawn=%d" % [n, hits])
	assert_between(hits, n * 46 / 100, n * 54 / 100, "about 50 % of floor 2s")


func test_whole_runs_hold_one_purple_room_on_floor_two_or_three() -> void:
	var on2 := 0
	var on3 := 0
	var runs := 16
	for s in runs:
		var plan := FloorPlan.new_run(RunSaver.RUN_ID, 300 + s, &"blade", false)
		plan.repo = _repo
		plan.build()
		var r := plan.run
		var held := PackedInt32Array()
		var w := plan.world
		for f in range(1, r.table.floors + 1):
			assert_false(
				w.boss_flow.routes, "run %d floor %d: no Deep gate before it is earned" % [s, f]
			)
			if w.purple != null:
				held.append(f)
			r.finish_floor(w)
			if f == r.table.floors:
				break
			var next := FloorPlan.next_floor(r, plan.run_biomes, {}, false)
			next.repo = _repo
			next.build()
			w = next.world
		assert_eq(held.size(), 1, "run %d: one purple room (%s)" % [s, str(held)])
		assert_true(held.size() == 1 and held[0] in [2, 3], "run %d: on floor 2 or 3" % s)
		on2 += 1 if held.has(2) else 0
		on3 += 1 if held.has(3) else 0
	gut.p("PURPLE_RUNS| runs=%d on_floor2=%d on_floor3=%d" % [runs, on2, on3])
	assert_gt(on2, 0, "some on floor 2")
	assert_gt(on3, 0, "some on floor 3")


func test_no_deep_gate_unless_the_runes_are_awakened() -> void:
	var w := _purple_floor()
	assert_not_null(w, "a floor 2 with purple runes")
	if w == null:
		return
	var f := w.floor_layout
	assert_true(f.has_deep_portal, "the Deep gate's spot is placed")
	assert_false(w.boss_flow.routes, "but not earned")
	var walls := _walls(w)
	_beat_boss(w)
	assert_eq(_opened_amount(w), 0, "the boss opened the gate alone")
	assert_false(w.boss_flow.gate_open(Routes.Route.DEEP), "no Deep gate")
	assert_true(w.boss_flow.gate_open(Routes.Route.NORMAL))
	assert_eq(_walls(w), walls, "no Deep gate footprint")


func test_awakened_runes_open_the_purple_portal_beside_the_gate() -> void:
	var w := _purple_floor()
	if w == null:
		return
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	w.actors.set_pos(0, f.purple_pos + Vector2(0.3, 0.0))
	w.step(InputFrame.new())
	assert_eq(
		reader.interact_prompt_key(), &"APPROACH_PYLON_PROMPT", "the prompt by the dais: Awaken"
	)
	var walls := _walls(w)
	w.step(_press())
	assert_true(PurpleRunes.earned(w), "one press awakens the runes")
	assert_gte(w.purple.lit_tick, 0, "at that tick")
	assert_true(w.boss_flow.routes, "the floor earned the Purple Portal")
	assert_eq(_walls(w), walls + 1, "the Deep gate's footprint stands")
	assert_eq(w.interactables.enabled[w.purple.entry], 0, "the dais takes no more presses")
	var tick := w.purple.lit_tick
	w.step(_press())
	assert_eq(w.purple.lit_tick, tick, "a second press does nothing; the runes stay lit")
	assert_true(reader.purple_lit())
	_beat_boss(w)
	assert_eq(_opened_amount(w), 1, "the boss opened the Deep gate too")
	assert_true(w.boss_flow.gate_open(Routes.Route.DEEP), "the Purple Portal beside the gate")
	CombatLab.idle(w, BossFlow.PORTAL_FORM_TICKS + 2)
	var into := -Kin.dir(f.deep_portal_angle)
	w.actors.set_pos(0, f.deep_portal_pos - into * 1.6)
	w.vel = Vector2.ZERO
	var frame := InputFrame.new()
	frame.move = Vector2i(roundi(into.x * SimTick.MOVE_MAX), roundi(into.y * SimTick.MOVE_MAX))
	for k in 90:
		if w.boss_flow.route_taken >= 0:
			break
		w.step(frame)
	assert_eq(w.boss_flow.route_taken, Routes.Route.DEEP, "walking in takes the Deep route")


func test_awakened_after_the_boss_died_it_opens_at_once() -> void:
	var w := _purple_floor()
	if w == null:
		return
	_beat_boss(w)
	assert_false(w.boss_flow.gate_open(Routes.Route.DEEP))
	_awaken(w)
	assert_true(w.boss_flow.gate_open(Routes.Route.DEEP), "awakened late: the Deep gate is open")


func test_a_floor_saved_before_dp_keeps_the_deep_gate() -> void:
	var r := SaveLab.run_state(1, 1)
	r.floor_rules = RunState.FLOOR_RULES_V090_RA
	var w := SaveLab.build_floor(r)
	assert_null(w.purple, "no purple runes under the old rules")
	assert_true(w.boss_flow.routes, "the Deep gate on every floor before the last, as saved")
	var now := SaveLab.floor_world(1, 1)
	assert_false(now.boss_flow.routes, "today's floor 1 has none")
	assert_eq(_walls(w), _walls(now) + 1, "its footprint stands from the start, as before")


func test_a_save_after_the_awakening_resumes_exactly() -> void:
	var w := _purple_floor()
	if w == null:
		return
	var snap0 := WorldSnapshot.take(w)
	var base0 := _purple_floor()
	assert_eq(WorldSnapshot.apply(base0, snap0), "", "a save before it fits")
	assert_eq(base0.state_hash(), w.state_hash())
	_awaken(w)
	for k in 30:
		w.step(InputFrame.new())
	var snap := WorldSnapshot.take(w)
	var base := _purple_floor()
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save with the Deep gate's footprint fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	assert_true(PurpleRunes.earned(base) and base.boss_flow.routes, "still earned")
	assert_eq(_walls(base), _walls(w))
	_beat_boss(w)
	_beat_boss(base)
	assert_eq(base.state_hash(), w.state_hash(), "and the boss opens both the same")


func test_the_run_records_the_floor_that_held_it() -> void:
	var r := SaveLab.run_state(1, 2)
	var w := SaveLab.build_floor(r)
	var had := w.purple != null
	r.finish_floor(w)
	assert_eq(r.purple_floors.has(2), had, "finishing floor 2 records it")
	var payload := RunSaver.payload_of(w, r, 1, PackedByteArray())
	var back := SaveLab.run_from(payload)
	assert_eq(back.purple_floors, r.purple_floors, "saved with the run")
	var old := payload.duplicate(true)
	(old["run"] as Dictionary).erase("purple_floors")
	assert_eq(
		SaveLab.run_from(old).purple_floors, PackedInt32Array(), "an older payload has had none"
	)


## v0.9.5 SB: the walls that are not a solid prop's footprint (a prop joins the walls once the hero is clear of it).
func _walls(w: World) -> int:
	return w.walls.size()
