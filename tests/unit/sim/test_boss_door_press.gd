extends GutTest
## v0.8.0 BD (owner O83: "opening the door now is a press button (X on controller F on keyboard) and when opened the
## sound play"): on today's floors the boss door is shut and solid from the floor's first tick; the interact press
## within reach of its outer face starts its opening (BOSS_DOOR_OPENING), BossFlow.DOOR_OPEN_TICKS later its collider
## leaves the walls (BOSS_DOOR_OPENED) and walking in seals it as before. A floor saved before BD (floor rules 1-8)
## keeps its open doorway. Same seed, same hash; a snapshot taken mid-opening restores and finishes the same.

const LONG := 1 << 24


func _world(run_seed: int, rules: int = RunState.FLOOR_RULES) -> World:
	var lab := RunLab.new(ContentRepository.load_all(), run_seed, &"blade")
	lab.run.floor_rules = rules
	var w := lab.floor_world()
	w.actors.invuln[0] = LONG
	return w


func _frame(dir: Vector2 = Vector2.ZERO, press: bool = false) -> InputFrame:
	var f := InputFrame.new()
	f.move = Vector2i(roundi(dir.x * SimTick.MOVE_MAX), roundi(dir.y * SimTick.MOVE_MAX))
	if press:
		f.pressed = InputFrame.INTERACT
	return f


func _count(w: World, kind: SimEvent.Kind, after: int = 0) -> int:
	var n := 0
	for e in w.events_since(after):
		if e.kind == kind:
			n += 1
	return n


func _into(w: World) -> Vector2:
	return Kin.dir(w.floor_layout.boss_door_angle)


## Stands the hero `m` metres in front of the door's outer face, at rest.
func _stand_out(w: World, m: float) -> void:
	w.actors.set_pos(0, w.floor_layout.boss_door_outside(m))
	w.vel = Vector2.ZERO


func test_the_door_is_shut_and_solid_until_pressed() -> void:
	var w := _world(8301)
	var walls_open := w.walls.size()
	assert_eq(w.boss_flow.door, BossFlow.Door.SET, "today's floor: the door waits for the press")
	w.step(_frame())
	assert_eq(w.boss_flow.door, BossFlow.Door.SHUT)
	assert_eq(w.walls.size(), walls_open + 1, "the door's collider joined the walls")
	_stand_out(w, 1.0)
	for k in 240:
		w.step(_frame(_into(w)))
	assert_lt(w.floor_layout.boss_door_depth(w.player_pos()), 0.0, "walking into it: still outside")
	assert_eq(w.boss_flow.state, BossFlow.State.WAITING, "no fight")


func test_the_press_opens_it_over_the_opening_ticks() -> void:
	var w := _world(8302)
	var walls_open := w.walls.size()
	w.step(_frame())
	_stand_out(w, BossFlow.DOOR_REACH_M + 1.5)
	w.step(_frame(Vector2.ZERO, true))
	assert_eq(w.boss_flow.door, BossFlow.Door.SHUT, "a press out of reach does nothing")
	_stand_out(w, 0.8)
	assert_true(WorldReader.new(w).boss_door_in_reach(), "the prompt shows in reach")
	var seq := w.last_event_seq()
	w.step(_frame(Vector2.ZERO, true))
	assert_eq(w.boss_flow.door, BossFlow.Door.OPENING, "pressed")
	assert_eq(_count(w, SimEvent.Kind.BOSS_DOOR_OPENING, seq), 1, "the opening sound's event")
	assert_false(WorldReader.new(w).boss_door_in_reach(), "no prompt while it opens")
	for k in BossFlow.DOOR_OPEN_TICKS / 2:
		w.step(_frame())
	assert_almost_eq(WorldReader.new(w).boss_door_progress(), 0.5, 0.02, "half way down")
	assert_eq(w.walls.size(), walls_open + 1, "still solid while it slides")
	seq = w.last_event_seq()
	for k in BossFlow.DOOR_OPEN_TICKS / 2 + 1:
		w.step(_frame())
	assert_eq(w.boss_flow.door, BossFlow.Door.OPEN)
	assert_eq(_count(w, SimEvent.Kind.BOSS_DOOR_OPENED, seq), 1, "the impact sound's event")
	assert_eq(w.walls.size(), walls_open, "the passage is open")
	assert_eq(WorldReader.new(w).boss_door_progress(), 1.0)
	var nav_closed: NavField = w.get(&"_nav_next")
	assert_not_null(nav_closed, "the shut door's flow field is kept for the sealing")
	for k in 300:
		w.step(_frame(_into(w)))
		if w.boss_flow.state == BossFlow.State.FIGHT:
			break
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "walking in seals it, as before")
	assert_eq(w.walls.size(), walls_open + 1, "sealed: the door is a wall again")
	assert_same(w.nav, nav_closed, "the kept field swapped in (no rebuild)")
	assert_eq(WorldReader.new(w).boss_door_progress(), -1.0, "the fight drives the door now")


func test_a_floor_saved_before_bd_keeps_its_open_doorway() -> void:
	var w := _world(8303, RunState.FLOOR_RULES_V080_N19)
	var walls_open := w.walls.size()
	assert_eq(w.boss_flow.door, BossFlow.Door.PASSAGE)
	w.step(_frame())
	assert_eq(w.walls.size(), walls_open, "no door collider before the fight")
	assert_eq(
		WorldReader.new(w).boss_door_progress(), -1.0, "the view opens it by nearness, as before"
	)
	_stand_out(w, 1.0)
	for k in 300:
		w.step(_frame(_into(w)))
		if w.boss_flow.state == BossFlow.State.FIGHT:
			break
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "walked straight in")


func test_a_hero_put_inside_past_the_shut_door_still_seals_once() -> void:
	var w := _world(8304)
	var walls_open := w.walls.size()
	w.step(_frame())
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.step(_frame())
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	assert_eq(w.walls.size(), walls_open + 1, "the door's collider once, not twice")


func _press_and_wait(w: World, ticks: int) -> void:
	w.step(_frame())
	_stand_out(w, 0.8)
	w.step(_frame(Vector2.ZERO, true))
	for k in ticks:
		w.step(_frame())


func test_same_seed_same_hash_and_a_save_mid_opening_finishes_the_same() -> void:
	var a := _world(8305)
	var b := _world(8305)
	_press_and_wait(a, 40)
	_press_and_wait(b, 40)
	assert_eq(a.state_hash(), b.state_hash(), "same inputs, same hash")
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(a, errors)
	assert_eq(errors, PackedStringArray())
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), _world(8305))
	assert_not_null(restored, "the snapshot fits its base")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "restored hash")
	assert_eq(restored.walls.size(), a.walls.size(), "the shut door came back")
	for k in BossFlow.DOOR_OPEN_TICKS:
		a.step(_frame())
		restored.step(_frame())
	assert_eq(restored.boss_flow.door, BossFlow.Door.OPEN)
	assert_eq(restored.state_hash(), a.state_hash(), "equal once open")
	assert_eq(restored.walls.size(), a.walls.size())
