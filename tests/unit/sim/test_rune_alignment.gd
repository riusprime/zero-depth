extends GutTest
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22 "3 pillars, 4 faces": interact turns one a quarter, solved opens a chest or a hidden room;
## puzzle calm; Q23 the hidden room unseen until it opens): the rune puzzle in the sim (RuneAlignment on the shared
## interactables). A press turns a pillar a quarter (four presses bring it round); no pillar starts solved and each
## needs 1-3 presses; the last match solves it, the slab goes, the hidden room is seen and its reward is there, once;
## the pillars take no press after; calm holds in the pillars' room until solved; a save mid-puzzle and one after
## resume exactly; a floor may hold it beside a timed door.


func _slab_up(w: World) -> bool:
	var o := w.floor_layout.rune_door_wall
	for x in w.walls:
		if x.center == o.center and x.half == o.half and x.angle == o.angle:
			return true
	return false


func test_a_press_turns_a_pillar_a_quarter() -> void:
	var w := RuneLab.world()
	assert_not_null(w, "a floor with a rune puzzle")
	if w == null:
		return
	var reader := WorldReader.new(w)
	w.step(InputFrame.new())
	assert_eq(reader.rune_pillar_count(), 3, "three pillars")
	for k in 3:
		var from := reader.rune_face(k)
		var need := RuneRooms.presses_needed(from, reader.rune_target(k))
		assert_between(need, 1, 3, "pillar %d: not solved at the start, at most 3 presses" % k)
	var start := reader.rune_face(0)
	RuneLab.turn(w, 0)
	assert_eq(reader.rune_face(0), (start + 1) % 4, "one press: a quarter turn")
	assert_eq(reader.interactable_press_tick(reader.rune_pillar_entry(0)), w.tick - 1)
	assert_eq(reader.interact_prompt_key(), &"RUNE_PILLAR_PROMPT", "the shared prompt says Turn")
	for k in 3:
		RuneLab.turn(w, 0)
	assert_eq(reader.rune_face(0), start, "four presses bring it round")


func test_matching_all_three_solves_it_once() -> void:
	var w := RuneLab.world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	w.step(InputFrame.new())
	assert_true(_slab_up(w), "the slab stands from the first tick")
	assert_true(reader.hidden_rooms().has(f.rune_room), "the hidden room unseen")
	var i := w.rewards.index_of(w.runes.reward_id)
	assert_gte(i, 0, "the reward is placed")
	assert_eq(f.room_of(w.rewards.pos(i)), f.rune_room, "in the hidden room")
	assert_true(reader.reward_hidden(i), "unseen until solved")
	for q in w.spawn_points:
		assert_ne(f.room_of(q), f.rune_room, "no enemy spawns inside")
	var presses := RuneLab.solve(w)
	assert_lte(presses, 9, "at most 3 presses a pillar")
	gut.p("RUNES| presses_to_solve=%d" % presses)
	assert_true(reader.rune_solved(), "every face matches: solved")
	assert_eq(reader.rune_solve_tick(), w.tick - 1)
	assert_false(_slab_up(w), "the slab is gone")
	assert_false(reader.hidden_rooms().has(f.rune_room), "the hidden room is seen")
	assert_false(reader.reward_hidden(i))
	var rewards := w.rewards.size()
	var face := reader.rune_face(0)
	RuneLab.turn(w, 0)
	assert_eq(reader.rune_face(0), face, "solved: the pillars take no more presses")
	for k in 120:
		w.step(InputFrame.new())
	assert_true(reader.rune_solved(), "it stays solved")
	assert_false(_slab_up(w), "and the slab stays down")
	assert_eq(w.rewards.size(), rewards, "the reward came once")
	if w.runes.reward_epic == 1:
		assert_eq(w.rewards.kind[i], RewardStore.Kind.ALTAR, "an epic altar")
		assert_true(reader.reward_is_epic(i))
	else:
		assert_eq(w.rewards.kind[i], RewardStore.Kind.CHEST, "a chest")


func test_puzzle_calm_until_solved() -> void:
	var w := RuneLab.world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	w.actors.set_pos(0, f.rune_pillars[0] + Vector2(0.3, 0.0))
	var steps := 0
	for k in 8:
		w.run_ticks += 1
		steps += Interactables.spawn_clock_step(w)
	assert_true(reader.puzzle_calm(), "calm in the pillars' room")
	assert_eq(steps, 2, "the spawn clock at a quarter of the rate")
	w.actors.set_pos(0, f.start_pos)
	assert_false(reader.puzzle_calm(), "left the room: normal spawning")
	RuneLab.solve(w)
	w.actors.set_pos(0, f.rune_pillars[0] + Vector2(0.3, 0.0))
	assert_false(reader.puzzle_calm(), "solved: normal spawning in it from now on")


func test_a_save_mid_puzzle_and_after_resumes_exactly() -> void:
	var w := RuneLab.world()
	if w == null:
		return
	w.step(InputFrame.new())
	RuneLab.turn(w, 1)
	var snap := WorldSnapshot.take(w)
	var base := RuneLab.world()
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save with the slab up fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	RuneLab.solve(w)
	RuneLab.solve(base)
	assert_eq(base.state_hash(), w.state_hash(), "and solves the same")
	for k in 60:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	var after := WorldSnapshot.take(w)
	var base2 := RuneLab.world()
	assert_eq(WorldSnapshot.apply(base2, after), "", "a save after it is solved fits")
	assert_eq(base2.state_hash(), w.state_hash())
	assert_true(base2.runes.solved == 1 and base2.runes.wall_up == 0, "solved, no slab")


func test_beside_a_timed_door_when_both_fit() -> void:
	var w := RuneLab.world(1, true, 3)  # v0.9.0 FV: floor 3 has room for both
	assert_not_null(w, "a floor with both")
	if w == null:
		return
	var f := w.floor_layout
	assert_ne(f.rune_room, f.timed_room, "two different dead ends")
	assert_false(
		f.rune_host in [f.timed_room, f.timed_host], "the pillars' room is not the timed door's"
	)
	w.step(InputFrame.new())
	var reader := WorldReader.new(w)
	assert_eq(reader.hidden_rooms().size(), 2, "both rooms unseen")
	RuneLab.solve(w)
	assert_eq(
		reader.hidden_rooms(), PackedInt32Array([f.timed_room]), "solving one shows only its own"
	)
	assert_eq(w.timed.state, TimedDoor.State.SHUT, "the timed door untouched")
