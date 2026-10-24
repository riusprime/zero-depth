extends GutTest
## v0.9.0 CF2 (owner: "Lockdowns get rooms first"): from floor rules 17 the Lockdowns (Elite ones too) pick their
## rooms right after the arenas and the Overrun room, before the shrine, the fountain, the events, the curse room and
## the secrets, over RUNS run seeds x floors 1-5 as Main builds them (SaveLab.build_floor):
## - no other kind stands in a Lockdown room, and no secret's host is one; every Lockdown keeps LK's and CF's rules
##   (its kind's least cells, never two side by side, never the only way on);
## - more floors hold a Lockdown than under the order before CF2 (rules 16), on the same seeds;
## - the same seed builds the same floor;
## - a floor saved under rules 16 marks its Lockdowns last, as it was built (the rooms every other kind took first are
##   theirs: a fresh mark with those rooms taken picks the same Lockdowns).

const RUNS := 40
const FLOORS := 5

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	NavField.skip_build = true  # no placement reads the flow field (test_special_room_rules)


func after_each() -> void:
	NavField.skip_build = false


func _run(s: int, floor_index: int, rules: int) -> RunState:
	var run := SaveLab.run_state(s, floor_index, &"blade", 0, _repo)
	run.floor_rules = rules
	return run


## The rooms the other kinds hold (an event's, the shrine's, the fountain's, the curse room, the secrets' rooms and
## hosts, the purple-rune room).
func _others(w: World) -> PackedInt32Array:
	var f := w.floor_layout
	var out := PackedInt32Array()
	for k in w.ev.ids.size():
		out.append(w.ev.room[k])
	if w.gamble_id >= 0:
		out.append(f.room_of(w.gamble_pos))
	out.append_array(Shrines.taken_rooms(w))
	for r in [f.curse_room, f.purple_room, f.timed_room, f.timed_host, f.rune_room, f.rune_host]:
		if r >= 0:
			out.append(r)
	for r in [f.crack_room, f.crack_host]:
		if r >= 0:
			out.append(r)
	return out


func test_lockdowns_take_their_rooms_first_and_keep_their_rules() -> void:
	var t := RunSaver.lockdown_table(_run(1, 1, RunState.FLOOR_RULES), _repo)
	assert_not_null(t, "the Lockdowns' data")
	var with_now := 0
	var with_before := 0
	var bad := PackedStringArray()
	for s in range(1, RUNS + 1):
		var purple := PackedInt32Array()
		var purple_old := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			var run := _run(s, floor_index, RunState.FLOOR_RULES)
			run.purple_floors = purple.duplicate()
			var w := SaveLab.build_floor(run, &"", _repo)
			if w.purple != null and not purple.has(run.run_floor()):
				purple.append(run.run_floor())
			var old_run := _run(s, floor_index, RunState.FLOOR_RULES_V090_CF)
			old_run.purple_floors = purple_old.duplicate()
			var old := SaveLab.build_floor(old_run, &"", _repo)
			if old.purple != null and not purple_old.has(old_run.run_floor()):
				purple_old.append(old_run.run_floor())
			var f := w.floor_layout
			with_now += 1 if not f.lockdown_rooms.is_empty() else 0
			with_before += 1 if not old.floor_layout.lockdown_rooms.is_empty() else 0
			var others := _others(w)
			var shut := f.arena_rooms.duplicate()
			if f.overrun_room >= 0:
				shut.append(f.overrun_room)
			var before := LockdownRooms.reached(f, shut)
			shut.append_array(f.lockdown_rooms)
			var now := LockdownRooms.reached(f, shut)
			for r in f.lockdown_rooms:
				var at := "seed %d floor %d room %d" % [s, floor_index, r]
				if others.has(r):
					bad.append(at + ": another kind's room")
				if not ClosedFights.fits(f, r, t.min_cells):
					bad.append(at + ": too small")
				for nb in f.neighbours(r):
					if f.lockdown_rooms.has(nb):
						bad.append(at + ": next to another Lockdown")
			for r in f.room_count():
				if before[r] == 1 and now[r] == 0 and not shut.has(r):
					bad.append("seed %d floor %d: room %d cut off" % [s, floor_index, r])
			if f.boss_room >= 0 and before[f.boss_room] == 1 and now[f.boss_room] == 0:
				bad.append("seed %d floor %d: the boss cut off" % [s, floor_index])
	assert_eq(bad, PackedStringArray(), "every Lockdown room is its own and keeps the rules")
	assert_gt(with_now, with_before, "more floors hold a Lockdown than in the order before CF2")
	gut.p(
		(
			"floors with a Lockdown: %d (rules 17) vs %d (rules 16) of %d"
			% [with_now, with_before, RUNS * FLOORS]
		)
	)


func test_the_same_seed_builds_the_same_floor() -> void:
	for s in [3, 17, 29]:
		for floor_index in [1, 4]:
			var a := SaveLab.build_floor(_run(s, floor_index, RunState.FLOOR_RULES), &"", _repo)
			var b := SaveLab.build_floor(_run(s, floor_index, RunState.FLOOR_RULES), &"", _repo)
			var at := "seed %d floor %d" % [s, floor_index]
			assert_eq(a.state_hash(), b.state_hash(), at + ": the same hash")
			assert_eq(
				a.floor_layout.lockdown_rooms,
				b.floor_layout.lockdown_rooms,
				at + ": the same rooms"
			)
			assert_eq(
				a.floor_layout.lockdown_kinds,
				b.floor_layout.lockdown_kinds,
				at + ": the same kinds"
			)


func test_a_floor_saved_under_rules_16_marks_its_lockdowns_last() -> void:
	var differ := 0
	for s in range(1, RUNS + 1):
		for floor_index in [1, 3]:
			var run := _run(s, floor_index, RunState.FLOOR_RULES_V090_CF)
			var w := SaveLab.build_floor(run, &"", _repo)
			var f := w.floor_layout
			var rooms := f.lockdown_rooms.duplicate()
			var kinds := f.lockdown_kinds.duplicate()
			var at := "seed %d floor %d" % [s, floor_index]
			var others := _others(w)
			for r in rooms:
				assert_false(others.has(r), at + ": never another kind's room (marked last)")
			# the same mark, with every other kind's rooms taken, picks the same rooms: they came last
			LockdownRooms.mark(
				f, RunSaver.lockdown_table(run, _repo), floor_index, Lockdowns.taken_rooms(w)
			)
			assert_eq(f.lockdown_rooms, rooms, at + ": the rooms a last mark picks")
			assert_eq(f.lockdown_kinds, kinds, at + ": the kinds a last mark draws")
			var now := SaveLab.build_floor(_run(s, floor_index, RunState.FLOOR_RULES), &"", _repo)
			if now.floor_layout.lockdown_rooms != rooms:
				differ += 1
	assert_gt(differ, 0, "rules 17 moves some floors' Lockdowns (the order changed)")
