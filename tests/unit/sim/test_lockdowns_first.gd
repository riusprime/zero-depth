extends GutTest
## Owner: "Lockdowns get rooms first": the Lockdowns (Elite ones too) pick their
## rooms right after the arenas and the Overrun room, before the shrine, the fountain, the events, the curse room and
## the secrets, over RUNS run seeds x floors 1-5 as Main builds them (SaveLab.build_floor):
## - no other kind stands in a Lockdown room, and no secret's host is one; every Lockdown keeps LK's and CF's rules
##   (its kind's least cells, never two side by side, never the only way on);
## - the same seed builds the same floor.

const RUNS := 40
const FLOORS := 5

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	NavField.skip_build = true  # no placement reads the flow field (test_special_room_rules)


func after_each() -> void:
	NavField.skip_build = false


func _run(s: int, floor_index: int) -> RunState:
	return SaveLab.run_state(s, floor_index, &"blade", 0, _repo)


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
	var t := RunSaver.lockdown_table(_repo)
	assert_not_null(t, "the Lockdowns' data")
	var with_now := 0
	var bad := PackedStringArray()
	for s in range(1, RUNS + 1):
		var purple := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			var run := _run(s, floor_index)
			run.purple_floors = purple.duplicate()
			var w := SaveLab.build_floor(run, &"", _repo)
			if w.purple != null and not purple.has(run.run_floor()):
				purple.append(run.run_floor())
			var f := w.floor_layout
			with_now += 1 if not f.lockdown_rooms.is_empty() else 0
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
	assert_gt(with_now, 0, "floors hold Lockdowns")
	gut.p("floors with a Lockdown: %d of %d" % [with_now, RUNS * FLOORS])


func test_the_same_seed_builds_the_same_floor() -> void:
	for s in [3, 17, 29]:
		for floor_index in [1, 4]:
			var a := SaveLab.build_floor(_run(s, floor_index), &"", _repo)
			var b := SaveLab.build_floor(_run(s, floor_index), &"", _repo)
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
