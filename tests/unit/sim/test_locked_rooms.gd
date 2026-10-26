extends GutTest
## v0.9.5 DR (owner Q6: "we will only have locked rooms, where enemies spawn, no rounds ... and overrun"): the two
## sealed kinds. A locked room (a Lockdown) fights one burst: two formations 1 s apart, nothing after, a free altar on
## the clear; the floor's arena rooms are locked rooms on floor rules 20 and the wave Arenas on rules 19; every seal
## drops bars; the Overrun keeps its waves.


func _arena_seed(floor_index: int) -> int:
	for s in range(1, 60):
		var w := SaveLab.floor_world(s, floor_index)
		if w.lockdown != null and not w.floor_layout.arena_rooms.is_empty():
			return s
	return -1


func test_a_locked_room_spawns_two_formations_one_second_apart_and_nothing_after() -> void:
	var w := LockLab.world()
	assert_not_null(w, "a floor with a locked room")
	if w == null:
		return
	var f := w.floor_layout
	f.lockdown_kinds[0] = LockdownTable.Kind.NORMAL  # forced: the kind's rule is the placement test's
	var s := w.lockdown
	s.table.area_per_enemy_m2 = 0.0  # the room holds the whole burst at once (no queue)
	var r := LockLab.room(w)
	LockLab.enter(w, r)
	assert_eq(s.waves, 2, "two formations")
	var t1 := -1
	var t2 := -1
	for k in 400:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
		if s.wave == 1 and t1 < 0:
			t1 = w.tick
		if s.wave == 2 and t2 < 0:
			t2 = w.tick
			break
	assert_gt(t1, 0, "the first formation came")
	assert_eq(t2 - t1, 60, "the second 1 s later, whoever is left")
	var size := s.table.size_on(w.floor_index)
	assert_eq(s.members.size(), size * 2, "a room holds 2 x the floor's formation size")
	for k in 300:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
	assert_eq(s.wave, 2, "nothing after the second formation")
	assert_eq(s.members.size(), size * 2, "no round three")
	var altars := w.rewards.size()
	LockLab.clear(w)
	assert_false(s.sealed(), "cleared")
	assert_eq(s.forced.size(), 0, "by the clear")
	assert_eq(s.reward_ids.size(), 1, "a free reward")
	var i := w.rewards.index_of(s.reward_ids[0])
	assert_eq(w.rewards.kind[i], RewardStore.Kind.ALTAR, "an altar")
	assert_eq(w.rewards.size(), altars + 1)


func test_an_arena_room_is_a_locked_room_on_rules_20_and_a_wave_arena_on_rules_19() -> void:
	var seed_value := _arena_seed(2)
	assert_gt(seed_value, 0, "a floor-2 seed with a locked room and an arena room")
	if seed_value < 0:
		return
	var now := SaveLab.floor_world(seed_value, 2)
	var run19 := SaveLab.run_state(seed_value, 2)
	run19.floor_rules = RunState.FLOOR_RULES_V095_AQ
	var old := SaveLab.build_floor(run19)
	assert_eq(
		now.floor_layout.arena_rooms, old.floor_layout.arena_rooms, "the same rooms: same count"
	)
	assert_eq(now.floor_layout.lockdown_rooms, old.floor_layout.lockdown_rooms)
	var room := now.floor_layout.arena_rooms[0]
	LockLab.calm(now)
	LockLab.calm(old)
	# Rules 20: a locked room (Normal kind), bars in every doorway, no wave Arena.
	assert_true(Lockdowns.takes_arenas(now))
	assert_true(Lockdowns.is_locked_room(now, room))
	assert_false(Arenas.is_arena(now, room), "not a wave Arena any more")
	var walls := now.walls.size()
	LockLab.enter(now, room)
	var doors := ArenaRooms.doors_of(now.floor_layout, room).size()
	assert_eq(now.lockdown.room, room, "sealed as a locked room")
	assert_eq(now.lockdown.kind, LockdownTable.Kind.NORMAL)
	assert_false(now.arenas.sealed())
	assert_eq(now.lockdown.barriers.size(), doors, "bars in every doorway")
	assert_eq(now.walls.size(), walls + doors)
	assert_eq(now.lockdown.waves, 2, "one burst")
	LockLab.clear(now)
	assert_true(Lockdowns.is_open(now, room), "opened by the clear")
	# Rules 19: the old Arena, its waves and its own seal.
	assert_false(Lockdowns.takes_arenas(old))
	assert_true(Arenas.is_arena(old, room))
	assert_eq(old.lockdown.table.burst_gap_ticks, 0, "the old three-formation Lockdowns")
	old.actors.set_pos(0, old.floor_layout.rooms[room].get_center())
	old.step(InputFrame.new())
	assert_true(old.arenas.sealed(), "the Arena seals on rules 19")
	assert_eq(old.arenas.room, room)
	assert_false(old.lockdown.sealed())


func test_an_old_lockdown_keeps_its_three_formations() -> void:
	var w := LockLab.world()
	if w == null:
		return
	var seed_value := 1
	for s in range(1, 60):
		if SaveLab.floor_world(s, 2).lockdown != null:
			seed_value = s
			break
	var run := SaveLab.run_state(seed_value, 2)
	run.floor_rules = RunState.FLOOR_RULES_V095_AQ
	var old := SaveLab.build_floor(run)
	LockLab.calm(old)
	old.floor_layout.lockdown_kinds[0] = LockdownTable.Kind.NORMAL
	LockLab.enter(old, LockLab.room(old))
	assert_eq(old.lockdown.waves, old.lockdown.table.waves, "3 formations, as before")
	assert_eq(old.lockdown.table.waves, 3)
