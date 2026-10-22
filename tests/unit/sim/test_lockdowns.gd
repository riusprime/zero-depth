extends GutTest
## v0.9.0 LK (owner Q21: "A new room type"; "1-2 a floor, short"; W20-W26): the sim side of the Lockdown rooms.
## - Placement over SEEDS floor seeds a floor (floors 1-5, built as the run sizes them, with the boss room, the Overrun
##   room, the arenas, the Deep gate's spot and the three secrets at the data's chances): 1-2 a floor where rooms fit;
##   never the start hall, boss room, its host, portal, Overrun, shop, curse, arena, secret, secret host or purple
##   room; always skippable (every other room reached with the Lockdowns, arenas and Overrun shut); never two side by
##   side; Normal only on floor 1, no Elite (EL's hook, weight 0); the counts and kinds printed (LK_PLACEMENT).
## - On a real floor (FloorPlan): the seal drops bars in every doorway, the horde waits, the formations spawn inside,
##   the clear opens the bars and leaves a free altar; a stuck enemy is pulled back after 3 s; the 90 s cap opens the
##   exits with enemies left; a Hazard Lockdown marks a strike on the ground before it lands and hurts; a save while
##   sealed resumes exactly; a floor saved before LK (floor rules 12) has none.
## - The encounter's length: FightBot (the base Blade, no cards, unhurt) clears one per floor; the seconds printed
##   (LK_SIZING), against the 20-40 s target.

const SEEDS := 200

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table() -> LockdownTable:
	return RunContentCompiler.compile_lockdown(_repo.get_def(&"lockdown", &"lockdown"))


func _layout(seed_value: int, run: RunState, floor_index: int) -> FloorLayout:
	var map := RunContentCompiler.compile_map(_repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(_repo)
	var arenas := RunContentCompiler.compile_arena(_repo.get_def(&"arena", &"arena"))
	var secrets: SecretsDefinition = _repo.get_def(&"secrets", &"secrets")
	var p := FloorShape.size_floor(run, map, floor_index)
	var f := FloorGenerator.generate(seed_value, p)
	BossRoomBuilder.attach(f, BossArenaSpec.make(Vector2i(4, 4), FloorLayout.Template.OPEN))
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas.share_permille)
	Routes.place_deep_gate(f)
	var speed := PlayerTable.starting_values().move_speed
	var none := PackedInt32Array()
	TimedDoorRooms.mark(f, map.timed_door_permille, 900, speed, none, PackedVector2Array())
	RuneRooms.mark(f, secrets.rune_permille, none, PackedVector2Array())
	CrackedRooms.mark(f, secrets.crack_permille, none)
	PurpleRooms.mark(f, 500, none, PackedVector2Array())
	return f


## The rooms reached from the start hall without entering `shut` (an independent BFS).
func _reached(f: FloorLayout, shut: PackedInt32Array) -> Dictionary:
	var seen := {f.start_room: true}
	var queue := [f.start_room]
	while not queue.is_empty():
		var r: int = queue.pop_front()
		for d in f.door_rooms:
			var other := d.y if d.x == r else (d.x if d.y == r else -1)
			if other >= 0 and not shut.has(other) and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return seen


func test_placement_over_many_seeds() -> void:
	var run := RunState.start(
		1, ContentCompiler.compile_run(_repo.get_def(&"run", RunSaver.RUN_ID))
	)
	var t := _table()
	var bad := 0
	var lines := PackedStringArray()
	for floor_index in range(1, 6):
		var counts := [0, 0, 0]
		var kinds := [0, 0, 0]
		var on_path := 0
		for s in SEEDS:
			var f := _layout(7001 + s * 7919 + floor_index * 104729, run, floor_index)
			var rooms := LockdownRooms.mark(f, t, floor_index, PackedInt32Array())
			counts[mini(rooms.size(), 2)] += 1
			var never := [
				f.start_room, f.boss_room, f.boss_host_room, f.portal_room, f.overrun_room
			]
			never.append_array([f.curse_room, f.purple_room, Routes.shop_room_of(f)])
			never.append_array(
				[f.timed_room, f.timed_host, f.rune_room, f.rune_host, f.crack_room, f.crack_host]
			)
			var path := LockdownRooms.main_path(f)
			for k in rooms.size():
				var r := rooms[k]
				kinds[f.lockdown_kinds[k]] += 1
				if r in never or f.arena_rooms.has(r):
					bad += 1
					gut.p("forbidden room %d on seed %d floor %d" % [r, s, floor_index])
				if path.has(r):
					on_path += 1
				for nb in f.neighbours(r):
					if rooms.has(nb):
						bad += 1
						gut.p("two side by side on seed %d floor %d" % [s, floor_index])
			var shut := f.arena_rooms.duplicate()
			if f.overrun_room >= 0:
				shut.append(f.overrun_room)
			var before := _reached(f, shut)  # (the Overrun room may close a dead end itself)
			shut.append_array(rooms)
			var now := _reached(f, shut)
			var cut := false
			for x in f.room_count():
				if before.has(x) and not now.has(x) and not shut.has(x):
					cut = true
			if cut:
				bad += 1
				gut.p("a room cut off on seed %d floor %d" % [s, floor_index])
			if floor_index == 1 and (f.lockdown_kinds.has(1) or f.lockdown_kinds.has(2)):
				bad += 1
			if f.lockdown_kinds.has(LockdownTable.Kind.ELITE):
				bad += 1
		(
			lines
			. append(
				(
					"LK_PLACEMENT| floor=%d seeds=%d none=%d one=%d two=%d normal=%d hazard=%d elite=%d on_short_path=%d"
					% [
						floor_index,
						SEEDS,
						counts[0],
						counts[1],
						counts[2],
						kinds[0],
						kinds[1],
						kinds[2],
						on_path
					]
				)
			)
		)
		if floor_index > 1:
			assert_gt(
				counts[1] + counts[2],
				SEEDS * 8 / 10,
				"floor %d: most floors hold one" % floor_index
			)
	for l in lines:
		gut.p(l)
	assert_eq(bad, 0, "never a forbidden room, never cut off, never side by side, kinds by floor")


func test_the_seal_the_formations_and_the_clear() -> void:
	var w := LockLab.world()
	assert_not_null(w, "a floor-2 seed with a Lockdown")
	if w == null:
		return
	var f := w.floor_layout
	var r := LockLab.room(w)
	var walls := w.walls.size()
	assert_eq(w.lockdown.cleared.size(), 0)
	for q in w.spawn_points:
		assert_ne(f.room_of(q), r, "the horde never spawns inside")
	LockLab.enter(w, r)
	var s := w.lockdown
	assert_eq(s.room, r, "sealed on entry")
	var doors := ArenaRooms.doors_of(f, r).size()
	assert_eq(s.barriers.size(), doors, "bars in every doorway")
	assert_eq(w.walls.size(), walls + doors, "they stand as walls")
	assert_true(Lockdowns.holds_spawns(w), "the horde waits")
	assert_false(Lockdowns.blink_may_land(w, f.rooms[f.start_room].get_center()), "no blink out")
	LockLab.to_wave(w)
	assert_eq(s.wave, 1, "the first formation")
	assert_eq(s.members.size(), s.table.size_on(w.floor_index), "its size for the floor")
	for i in Lockdowns.fighters(w):
		assert_eq(f.room_of(w.actors.pos(i)), r, "it stands inside")
	var ticks := LockLab.clear(w)
	assert_false(s.sealed(), "cleared in %d ticks" % ticks)
	assert_eq(s.cleared, PackedInt32Array([r]))
	assert_eq(s.forced.size(), 0, "a clear, not the cap")
	assert_eq(s.wave, s.waves, "every formation was fought")
	assert_eq(w.walls.size(), walls, "the bars are gone")
	assert_eq(s.reward_ids.size(), 1, "a reward")
	var i := w.rewards.index_of(s.reward_ids[0])
	assert_eq(w.rewards.kind[i], RewardStore.Kind.ALTAR, "a free altar")
	assert_eq(f.room_of(w.rewards.pos(i)), r, "in the room")
	w.step(InputFrame.new())
	assert_false(s.sealed(), "an opened Lockdown never seals again")


func test_a_stuck_enemy_is_pulled_back_after_3_s() -> void:
	var w := LockLab.world()
	if w == null:
		return
	var f := w.floor_layout
	var r := LockLab.room(w)
	LockLab.enter(w, r)
	LockLab.to_wave(w)
	var s := w.lockdown
	var id := s.members[0]
	var i := w.actors.index_of(id)
	# Stuck on purpose: behind the bars in the next room, put back there before every tick until the safety acts.
	var other := f.door_rooms[ArenaRooms.doors_of(f, r)[0]]
	var outside := Lockdowns.reward_spot(f, other.y if other.x == r else other.x)
	var held := 0
	while s.pulled == 0 and held < s.table.stuck_ticks + 30 and w.actors.index_of(id) >= 0:
		w.actors.set_pos(w.actors.index_of(id), outside)
		w.step(InputFrame.new())
		held += 1
	i = w.actors.index_of(id)
	assert_gte(i, 0, "the stuck enemy is alive")
	assert_eq(f.room_of(w.actors.pos(i)), r, "pulled back into the room")
	assert_eq(s.pulled, 1, "once")
	assert_between(held, s.table.stuck_ticks - 1, s.table.stuck_ticks + 1, "after 3 s unreachable")
	gut.p(
		"LK_STUCK| held_ticks=%d stuck_ticks=%d pulled=%d" % [held, s.table.stuck_ticks, s.pulled]
	)
	LockLab.clear(w)
	assert_false(s.sealed(), "and the Lockdown still clears")


func test_the_90_s_cap_opens_the_exits() -> void:
	var w := LockLab.world()
	if w == null:
		return
	var r := LockLab.room(w)
	var walls := w.walls.size()
	LockLab.enter(w, r)
	var s := w.lockdown
	var t0 := s.sealed_tick
	while s.sealed() and w.tick - t0 < s.table.cap_ticks + 5:
		w.step(InputFrame.new())  # nobody fights: the hero is unhurt, the formation lives
	assert_false(s.sealed(), "the exits open")
	assert_eq(s.clear_tick - t0, s.table.cap_ticks, "at 90 s")
	assert_eq(s.forced, PackedInt32Array([r]), "by the cap")
	assert_gt(Lockdowns.fighters(w).size() + _alive(w, s.members), 0, "with enemies left")
	assert_eq(w.walls.size(), walls, "the bars are gone")
	assert_eq(s.reward_ids.size(), 1, "the reward stands anyway")


func _alive(w: World, ids: PackedInt32Array) -> int:
	var n := 0
	for id in ids:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.dead[i] == 0:
			n += 1
	return n


func test_a_hazard_lockdown_warns_on_the_ground_then_hurts() -> void:
	var w := LockLab.world()
	if w == null:
		return
	var f := w.floor_layout
	f.lockdown_kinds[0] = LockdownTable.Kind.HAZARD  # forced: the kind's rule is the placement test's
	# Only the strikes here: no formation spawns (no spawner) and the room stays sealed while they come.
	w.spawner = null
	w.lockdown.table.waves = 20
	var r := LockLab.room(w)
	LockLab.enter(w, r)
	var s := w.lockdown
	assert_eq(s.kind, LockdownTable.Kind.HAZARD)
	assert_gte(s.table.hazard_warn_ticks, SimTick.MIN_TELEGRAPH_TICKS, "the warning is readable")
	while s.strike_pos.is_empty() and w.tick - s.sealed_tick < 600:
		w.step(InputFrame.new())
	assert_eq(s.strike_pos.size(), 1, "a strike marked")
	var at := s.strike_pos[0]
	assert_lt((at - w.player_pos()).length(), 0.3, "where the hero stands")
	assert_eq(
		s.strike_tick[0] - w.tick + 1, s.table.hazard_warn_ticks, "it lands after the warning"
	)
	var hp := w.actors.hp[0]
	var hits := 0
	var warned := 0
	while s.landed_tick < 0 and w.tick - s.sealed_tick < 900:
		w.actors.invuln[0] = 0
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		if s.landed_tick < 0:
			warned += 1
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == Lockdowns.HAZARD_EFFECT:
				hits += 1
	assert_eq(s.landed_pos, at, "it landed on its mark")
	assert_eq(warned, s.table.hazard_warn_ticks - 1, "after its whole warning")
	assert_eq(hits, 1, "and hurt the hero standing on it")
	assert_lt(w.actors.hp[0], hp, "(its damage, after the Blade's armour)")


func test_a_save_while_sealed_resumes_exactly() -> void:
	var w := LockLab.world()
	if w == null:
		return
	var r := LockLab.room(w)
	LockLab.enter(w, r)
	LockLab.to_wave(w)
	for k in 20:
		w.step(InputFrame.new())
	var snap := WorldSnapshot.take(w)
	var base := LockLab.world()
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save while sealed fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	assert_eq(base.walls.size(), w.walls.size(), "the bars came back with the walls")
	for k in 60:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash(), "and it plays on the same")
	var h0 := w.state_hash()
	w.lockdown.pulled += 1
	assert_ne(w.state_hash(), h0, "the Lockdown's state is hashed")


func test_a_floor_saved_before_lk_has_none() -> void:
	var with := 0
	for s in range(1, 9):
		var r := SaveLab.run_state(s, 2)
		r.floor_rules = RunState.FLOOR_RULES_V090_DP
		var old := SaveLab.build_floor(r)
		assert_null(old.lockdown, "seed %d: none under floor rules 12" % s)
		assert_true(old.floor_layout.lockdown_rooms.is_empty())
		if SaveLab.floor_world(s, 2).lockdown != null:
			with += 1
	assert_gt(with, 0, "today's floors have them")


func test_the_encounter_lasts_about_20_to_40_s() -> void:
	var lines := PackedStringArray()
	for floor_index in range(1, 6):
		var w := LockLab.world(floor_index)
		if w == null:
			lines.append("LK_SIZING| floor=%d no Lockdown in 60 seeds" % floor_index)
			continue
		var r := LockLab.room(w)
		LockLab.enter(w, r)
		var bot := FightBot.new(floor_index)
		var s := w.lockdown
		var hp := 0
		var counted := PackedInt32Array()
		while s.sealed() and w.tick - s.sealed_tick < s.table.cap_ticks + 5:
			w.step(bot.frame(w))
			for id in s.members:
				if not counted.has(id):
					var i := w.actors.index_of(id)
					if i >= 0:
						counted.append(id)
						hp += w.actors.max_hp[i]
		var secs := float(s.clear_tick - s.sealed_tick) / 60.0
		var forced := s.forced.size() > 0
		lines.append(
			(
				"LK_SIZING| floor=%d seed_room=%d enemies=%d total_hp=%d seconds=%.1f forced=%s"
				% [floor_index, r, counted.size(), hp, secs, forced]
			)
		)
	for l in lines:
		gut.p(l)
	assert_eq(lines.size(), 5)
