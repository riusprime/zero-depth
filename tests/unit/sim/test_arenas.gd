extends GutTest
## v0.5.5 AR (PLAN D2, X1 "open floor, sealed arenas", X1b): where the arenas go (a property over many floor seeds:
## about a third of the combat rooms, never the start, boss, shop, event or shrine rooms, always skippable), the
## rewards they hold (placed there first, locked until the clear, S1's two-altar cap kept), in play the seal (barriers,
## the horde paused, no blink out), the waves inside at the floor's sizes, the clear; saves at the arena's entry; and
## the boss's legendary altar (a pick of 3 from the legendary tier only). No bots: mechanics only (owner P1).

const SEEDS := 300
const STEPS_AFTER := 600


func _arena_floor(run_seed: int, floor_index: int = 1) -> World:
	return SaveLab.floor_world(run_seed, floor_index)


## A floor (SaveLab, as Main builds it) with at least one regular arena, from `from` on.
func _floor_with_arena(from: int, floor_index: int = 1) -> World:
	for s in range(from, from + 40):
		var w := _arena_floor(s, floor_index)
		if not w.floor_layout.arena_rooms.is_empty():
			return w
	return null


## Stands the player in arena `room` at its first spawn point and steps once (the seal's tick).
func _enter(w: World, room: int) -> void:
	while w.boss_flow != null and w.boss_flow.holds_world():  # floors 2-3 open with the arrival
		w.step(InputFrame.new())
	w.actors.set_pos(0, w.floor_layout.spawn_points[room][0])
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())


func _kill_inside(w: World) -> void:
	if not w.arenas.sealed():
		return
	var rect := w.floor_layout.rooms[w.arenas.room].grow(Arenas.ROOM_MARGIN_M)
	for i in range(1, w.actors.size()):
		var at := w.actors.pos(i)
		if w.actors.dead[i] == 0 and w.actors.invuln[i] == 0 and rect.has_point(at):
			Damage.hit(w, i, 1000000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)


# --- Generation ---------------------------------------------------------------------------------------------------
func test_about_a_third_of_the_combat_rooms_are_skippable_arenas() -> void:
	var share := ContentCompiler.compile_arena(
		ContentRepository.load_all().get_def(&"arena", &"arena")
	)
	assert_eq(share.share_permille, 330, "the data's starting share")
	var none := 0
	var total := 0
	var combat := 0
	for s in range(1, SEEDS + 1):
		var f := FloorGenerator.generate(s)
		BossRoomBuilder.attach(f)
		OverrunRooms.mark(f)
		var rooms := ArenaRooms.mark(f, share.share_permille)
		var cands := ArenaRooms.candidates(f)
		combat += cands.size()
		total += rooms.size()
		if rooms.is_empty():
			none += 1
		var target := maxi(1, (cands.size() * share.share_permille + 500) / 1000)
		assert_lte(rooms.size(), target, "seed %d: never more than the share" % s)
		var shop := Routes.shop_room_of(f)
		for r in rooms:
			assert_false(
				(
					r
					in [
						f.start_room,
						f.boss_room,
						f.boss_host_room,
						f.portal_room,
						f.overrun_room,
						shop
					]
				),
				"seed %d: room %d is a combat room" % [s, r]
			)
			assert_gte(
				f.spawn_points[r].size(), ArenaRooms.MIN_SPOTS, "seed %d: spots to spawn in" % s
			)
		var shut := rooms.duplicate()
		if f.overrun_room >= 0:
			shut.append(f.overrun_room)
		assert_true(ArenaRooms.all_reachable(f, shut), "seed %d: every other room without one" % s)
		assert_false(
			OverrunRooms.shortest_path(f, f.start_room, f.boss_host_room, -1).is_empty(),
			"seed %d: the boss is reachable" % s
		)
	gut.p(
		(
			"arenas over %d seeds: %d in %d combat rooms, %d floors without"
			% [SEEDS, total, combat, none]
		)
	)
	assert_lt(none, SEEDS / 10, "nearly every floor has one")
	assert_gt(total * 1000 / combat, 200, "about a third (fewer where it would cut the floor)")


func test_the_pick_is_deterministic_and_leaves_the_layout_alone() -> void:
	for s in [5, 77, 901]:
		var a := FloorGenerator.generate(s)
		BossRoomBuilder.attach(a)
		OverrunRooms.mark(a)
		var walls := a.walls.size()
		var rooms := ArenaRooms.mark(a, 330)
		var b := FloorGenerator.generate(s)
		BossRoomBuilder.attach(b)
		OverrunRooms.mark(b)
		assert_eq(ArenaRooms.mark(b, 330), rooms, "seed %d: same rooms" % s)
		assert_eq(a.walls.size(), walls, "no wall added")
		assert_eq(ArenaRooms.mark(b, 0), PackedInt32Array(), "a zero share: none")


func test_event_rooms_and_the_shop_stay_out_of_arenas() -> void:
	for s in range(1, 25):
		var w := _arena_floor(s)
		var f := w.floor_layout
		for e in w.ev.room.size():
			assert_false(
				f.arena_rooms.has(w.ev.room[e]), "seed %d: an event room is not an arena" % s
			)
		assert_false(f.arena_rooms.has(f.shop_room), "seed %d: nor the shop" % s)
		assert_false(
			f.arena_rooms.has(f.start_room), "seed %d: nor the start hall (the shrine)" % s
		)


func test_rewards_fill_the_arenas_first_and_keep_two_altars() -> void:
	var with_reward := 0
	for s in range(1, 41):
		var w := _arena_floor(s)
		var f := w.floor_layout
		var altars := 0
		var arena_spots := 0
		for i in f.item_spots.size():
			if f.arena_rooms.has(f.item_rooms[i]):
				arena_spots += 1
		var in_arena := 0
		for i in w.rewards.size():
			altars += 1 if w.rewards.kind[i] == RewardStore.Kind.ALTAR else 0
			if f.arena_rooms.has(f.room_of(w.rewards.pos(i))):
				in_arena += 1
				assert_true(Arenas.locked(w, i), "seed %d: an arena's reward is locked" % s)
		assert_lte(altars, 2, "seed %d: S1's cap holds" % s)
		assert_eq(
			in_arena, mini(arena_spots, w.rewards.size()), "seed %d: arena spots fill first" % s
		)
		with_reward += 1 if in_arena > 0 else 0
	assert_gt(with_reward, 30, "nearly every floor's arenas hold rewards")


# --- In play ------------------------------------------------------------------------------------------------------
func test_entering_seals_the_doors_and_the_horde_pauses() -> void:
	var w := _floor_with_arena(1)
	assert_not_null(w)
	var f := w.floor_layout
	var room := f.arena_rooms[0]
	for n in 30:
		w.step(InputFrame.new())
	assert_false(w.arenas.touched(), "not hashed before an arena seals")
	var walls := w.walls.size()
	_enter(w, room)
	assert_eq(w.arenas.room, room, "sealed on the first tick inside")
	var doors := ArenaRooms.doors_of(f, room)
	assert_eq(w.arenas.barriers.size(), doors.size(), "a barrier in each doorway")
	assert_eq(w.walls.size(), walls + doors.size(), "they stand in the walls")
	assert_between(w.arenas.waves, 2, 3, "2-3 waves, drawn per room")
	var cd := w.spawn_cd
	var ticks := w.run_ticks
	for n in 20:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
	assert_eq(w.spawn_cd, cd, "the open floor's spawning waits")
	assert_eq(w.run_ticks, ticks + 20, "the floor clock runs on")
	var inside := f.rooms[room].get_center()
	var outside := f.rooms[f.start_room].get_center()
	assert_false(w.blink_may_land(inside, outside), "no blink out of a sealed arena")
	assert_true(w.blink_may_land(inside, inside + Vector2(0.5, 0)), "a blink inside it is fine")
	# Walking (and dashing) into a doorway: the barrier holds you in the room.
	var d := doors[0]
	var axis := Kin.dir(f.door_angles[d])  # from door_rooms.x toward .y
	if f.door_rooms[d].y == room:
		axis = -axis
	w.actors.set_pos(0, f.door_centers[d] - axis * (f.door_depths[d] * 0.5 + 1.0))
	var push := InputFrame.new()
	push.move = Vector2i(roundi(axis.x * SimTick.MOVE_MAX), roundi(axis.y * SimTick.MOVE_MAX))
	for n in 60:
		w.actors.invuln[0] = 5
		push.pressed = InputFrame.DASH if n % 20 == 0 else 0
		w.step(push)
	assert_eq(f.room_of(w.player_pos()), room, "the barrier holds the doorway")


func test_waves_spawn_inside_one_after_another_then_the_doors_open() -> void:
	var w := _floor_with_arena(1)
	var f := w.floor_layout
	var room := f.arena_rooms[0]
	var walls := w.walls.size()
	var locked := PackedInt32Array()
	for i in w.rewards.size():
		if f.room_of(w.rewards.pos(i)) == room:
			locked.append(w.rewards.ids[i])
	_enter(w, room)
	var waves := w.arenas.waves
	var sizes := PackedInt32Array()
	var guard := 0
	var last := 0
	while w.arenas.sealed() and guard < 12000:
		guard += 1
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
		if w.arenas.wave != last:
			last = w.arenas.wave
			sizes.append(Arenas.alive_in_room(w))
			assert_eq(
				Arenas.alive_in_room(w),
				Arenas.wave_size(w),
				"wave %d spawned its size inside the room" % last
			)
			assert_gt(w.tick, 0)
		elif w.arenas.next_wave_tick < 0:
			_kill_inside(w)
	assert_false(w.arenas.sealed(), "the last wave's death clears it")
	assert_eq(sizes.size(), waves, "every wave came")
	for n in sizes:
		assert_eq(n, 3, "floor 1: waves of 3")
	assert_true(w.arenas.cleared.has(room))
	assert_eq(w.walls.size(), walls, "the doors open")
	for id in locked:
		assert_false(Arenas.locked(w, w.rewards.index_of(id)), "its reward unlocks")
	_enter(w, room)
	assert_false(w.arenas.sealed(), "a cleared arena stays open")


func test_a_locked_reward_cannot_be_opened_until_the_clear() -> void:
	for s in range(1, 41):
		var w := _arena_floor(s)
		var f := w.floor_layout
		var r := -1
		for i in w.rewards.size():
			if Arenas.locked(w, i) and f.arena_rooms.has(f.room_of(w.rewards.pos(i))):
				r = i
				break
		if r < 0:
			continue
		var room := f.room_of(w.rewards.pos(r))
		var id := w.rewards.ids[r]
		w.shards = 100000
		w.actors.set_pos(0, w.rewards.pos(r) + Vector2(0.6, 0))
		w.step(InputFrame.new())
		assert_true(w.arenas.sealed(), "standing there seals it")
		var f2 := InputFrame.new()
		f2.pressed = InputFrame.INTERACT
		w.actors.invuln[0] = 5
		w.step(f2)
		assert_eq(w.choosing, -1, "locked: the interact does nothing")
		var guard := 0
		while w.arenas.sealed() and guard < 12000:
			guard += 1
			w.actors.invuln[0] = 5
			_kill_inside(w)
			w.step(InputFrame.new())
		assert_true(w.arenas.cleared.has(room))
		w.actors.set_pos(0, w.rewards.pos(w.rewards.index_of(id)) + Vector2(0.6, 0))
		w.step(f2)
		assert_eq(w.choosing, id, "cleared: it opens")
		return
	fail_test("no floor with a locked reward in 40 seeds")


func test_wave_sizes_by_floor() -> void:
	var t := ContentCompiler.compile_arena(ContentRepository.load_all().get_def(&"arena", &"arena"))
	assert_eq(t.wave_sizes, PackedInt32Array([3, 5, 7]))
	assert_eq([t.waves_min, t.waves_max], [2, 3])
	for fl in [2, 3]:
		var w := _floor_with_arena(10, fl)
		assert_not_null(w)
		_enter(w, w.floor_layout.arena_rooms[0])
		assert_eq(Arenas.wave_size(w), [0, 3, 5, 7][fl], "floor %d" % fl)


func test_arena_play_replays_to_the_same_hash() -> void:
	var hashes := []
	for k in 2:
		var w := _floor_with_arena(3)
		_enter(w, w.floor_layout.arena_rooms[0])
		for n in 400:
			w.actors.invuln[0] = 5
			if n % 90 == 60:
				_kill_inside(w)
			w.step(InputFrame.new())
		assert_true(w.arenas.touched())
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


# --- Saves --------------------------------------------------------------------------------------------------------
func _round_trip(w: World, base: World, label: String) -> void:
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "%s: every object is classified" % label)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "%s: fits (%s)" % [label, WorldSnapshot.apply(base, snap)])
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "%s: restored hash equals" % label)
	assert_eq(restored.walls.size(), w.walls.size(), "%s: the barriers came back" % label)
	var b1 := FightBot.new(17)
	var b2 := FightBot.new(17)
	for i in STEPS_AFTER:
		w.step(SaveLab.frame(w, b1))
		restored.step(SaveLab.frame(restored, b2))
	assert_eq(
		restored.state_hash(), w.state_hash(), "%s: equal after %d ticks" % [label, STEPS_AFTER]
	)


func test_a_save_at_the_arena_entry_resumes_the_arena() -> void:
	for fl in [1, 2]:
		var w := _floor_with_arena(20, fl)
		var room := w.floor_layout.arena_rooms[0]
		w.actors.hp[0] = 100000
		w.actors.max_hp[0] = 100000
		_enter(w, room)
		assert_true(w.arenas.sealed(), "sealed at the entry")
		_round_trip(w, _floor_with_arena(20, fl), "floor %d arena entry" % fl)


func test_a_save_mid_wave_and_after_the_clear_round_trips() -> void:
	var w := _floor_with_arena(30)
	var room := w.floor_layout.arena_rooms[0]
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	_enter(w, room)
	for n in 120:
		w.step(InputFrame.new())
	assert_gt(w.arenas.wave, 0, "a wave is in")
	_round_trip(w, _floor_with_arena(30), "mid wave")
	var c := _floor_with_arena(30)
	c.actors.hp[0] = 100000
	c.actors.max_hp[0] = 100000
	_enter(c, room)
	var guard := 0
	while c.arenas.sealed() and guard < 12000:
		guard += 1
		_kill_inside(c)
		c.step(InputFrame.new())
	assert_true(c.arenas.cleared.has(room))
	_round_trip(c, _floor_with_arena(30), "after the clear")


func test_the_overrun_entry_round_trips() -> void:
	var w := _arena_floor(41)
	var f := w.floor_layout
	assert_gte(f.overrun_room, 0)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	_enter(w, f.overrun_room)
	assert_true(w.overrun.inside)
	for n in 90:
		w.step(InputFrame.new())
	_round_trip(w, _arena_floor(41), "overrun")


# --- The boss's legendary altar (X1b) --------------------------------------------------------------------------------
func test_legendary_stat_cards_are_stronger_than_epic() -> void:
	var w := _arena_floor(3)
	assert_not_null(w.legendary_table)
	assert_false(w.legendary_table.stats.is_empty())
	assert_false(w.legendary_table.mods.is_empty())
	for s in w.legendary_table.stats:
		var t := w.stat_tables[s]
		assert_eq(t.amounts.size(), 4, "%s: four rarities" % t.id)
		assert_eq(
			t.amounts[Offers.LEGENDARY], (t.amounts[Offers.EPIC] * 1600 + 500) / 1000, "%s" % t.id
		)
		assert_gt(t.amounts[Offers.LEGENDARY], t.amounts[Offers.EPIC])
	var before := Stats.value(w, Stats.Stat.DAMAGE)
	Stats.add_card(w, Stats.Stat.DAMAGE, Offers.LEGENDARY)
	var t := w.stat_tables[Stats.Stat.DAMAGE]
	assert_eq(
		Stats.value(w, Stats.Stat.DAMAGE),
		(before * (1000 + t.amounts[Offers.LEGENDARY]) + 500) / 1000,
		"a legendary damage card adds its legendary amount"
	)


func test_killing_the_boss_leaves_a_legendary_altar_of_three() -> void:
	var w := _arena_floor(5)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	FightLab.enter_boss_room(w)
	var guard := 0
	while w.boss_id < 0 and guard < 600:
		w.step(InputFrame.new())
		guard += 1
	assert_gte(w.boss_id, 0, "the boss rose")
	assert_eq(w.legendary_id, -1, "no altar while it lives")
	var i := w.actors.index_of(w.boss_id)
	guard = 0
	while w.boss_flow.opened_tick < 0 and guard < 2000:
		guard += 1
		i = w.actors.index_of(w.boss_id)
		if i > 0:
			w.actors.invuln[i] = 0
			var at := w.actors.pos(i)
			Damage.hit(w, i, w.actors.hp[i] * 10, 0, 0, w.take_root(), 0, at, at)
		w.step(InputFrame.new())
	assert_gte(w.boss_flow.opened_tick, 0, "the boss died")
	var r := w.rewards.index_of(w.legendary_id)
	assert_gte(r, 0, "a legendary altar appeared")
	assert_eq(w.rewards.kind[r], RewardStore.Kind.LEGENDARY)
	assert_eq(w.rewards.price[r], 0, "free")
	assert_false(Arenas.locked(w, r))
	w.actors.set_pos(0, w.rewards.pos(r) + Vector2(0.6, 0))
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	assert_eq(w.choosing, w.legendary_id, "it opens")
	var offer := w.rewards.offer_of(r)
	assert_eq(offer.size(), 3, "a pick of 3")
	for code in offer:
		match Offers.type_of(code):
			Offers.STAT:
				assert_eq(Offers.rarity_of(code), Offers.LEGENDARY, "legendary stat cards only")
				assert_true(w.legendary_table.stats.has(Offers.stat_of(code)), "from its pool")
			Offers.MOD:
				assert_true(w.legendary_table.mods.has(code), "pool mods only")
			_:
				fail_test("no other card types")
	var pick := InputFrame.new()
	pick.pick = 1
	w.step(pick)
	assert_eq(w.choosing, -1)
	assert_eq(w.rewards.index_of(w.legendary_id), -1, "taken")
	for n in 5:
		w.step(InputFrame.new())
	assert_eq(w.rewards.index_of(w.legendary_id), -1, "one per boss")
