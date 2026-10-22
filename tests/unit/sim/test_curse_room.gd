extends GutTest
## v0.8.0 N17 (owner O75: "they need to appear once max per floor and 40% of floors not all the time") and N19 (owner
## O80: "The curse room should be a fixed unique small room in every biome like the store"): the curse room. Over many
## generated floors (the floor pipeline's layout steps, with today's map, arena and shop rules): about
## curse_room_floor_chance_permille of normal floors have one and every Deep floor does, never in the start hall, the
## boss room or its host, the portal room, the Overrun room, the shop's room, an arena or the shrine's room, small rooms
## first. On real floors it is a room of its own (CurseRoom.furnish): at most one altar, centred and solid, crystals,
## no interior pieces and no enemy spawns inside, the room whole; the only pedestal holding a curse event (Whispering
## Deep included), Echo Mirror only once a stat is raised. Saved and hashed; a floor saved before N17 keeps its event
## rooms as they were, one saved under N17 its N17 curse room.

const SEEDS := 1000

var _rules: EventRules
var _gamble: GambleTable
var _tables: Dictionary


func before_all() -> void:
	var repo := EventLab.repo()
	_rules = EventCompiler.compile_rules(repo.get_def(&"event_rules", &"floor"))
	_gamble = ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))
	_tables = RunSaver.floor_tables(null, repo)


## The layout as FloorScenario.build and add_shop shape it before the events (the boss room, the Overrun room, the
## arenas, the shop's room).
func _layout(seed_value: int) -> FloorLayout:
	var map: FloorParams = _tables[&"map"]
	var layout := FloorGenerator.generate(seed_value, map)
	BossRoomBuilder.attach(layout, BossArenaSpec.new())
	OverrunRooms.mark(layout)
	var arenas: ArenaTable = _tables[&"arena"]
	ArenaRooms.mark(layout, arenas.share_permille)
	ShopPlacement.pick(layout)
	return layout


func _shut(layout: FloorLayout) -> PackedInt32Array:
	var shut := PackedInt32Array()
	var shrine := Gamble.site(layout, _gamble, false, _tables[&"map"])
	if not shrine.is_empty():
		shut.append(layout.room_of(shrine[0]))
	return shut


func _allowed(layout: FloorLayout, r: int, shut: PackedInt32Array) -> bool:
	var ok := r != layout.start_room and r != layout.boss_room and r != layout.boss_host_room
	ok = ok and r != layout.portal_room and r != layout.overrun_room and r != layout.shop_room
	return ok and not layout.arena_rooms.has(r) and not shut.has(r)


func test_about_forty_percent_of_normal_floors_get_one_in_an_allowed_small_room() -> void:
	assert_eq(_rules.curse_room_floor_chance_permille, 400, "the data's starting value")
	var with := 0
	var small := 0
	var could_be_small := 0
	var bad := 0
	for s in SEEDS:
		var seed_value := 1 + s * 7919
		var layout := _layout(seed_value)
		var shut := _shut(layout)
		var r := Events.curse_site(layout, seed_value, _rules, shut)
		if r < 0:
			continue
		with += 1
		var ok := _allowed(layout, r, shut) and Events.curse_spot(layout, r, _rules).size() == 1
		if s < 100:  # a pure function: the same room on a rebuilt layout
			ok = ok and r == Events.curse_site(_layout(seed_value), seed_value, _rules, shut)
		var any_small := false
		for c in Events.curse_rooms(layout):
			if _allowed(layout, c, shut) and layout.rooms[c].get_area() <= Events.SMALL_ROOM_M2:
				any_small = any_small or not Events.curse_spot(layout, c, _rules).is_empty()
		if any_small:
			could_be_small += 1
			if layout.rooms[r].get_area() <= Events.SMALL_ROOM_M2:
				small += 1
			else:
				ok = false  # a small room was there: it comes first
		if not ok:
			bad += 1
			gut.p("seed %d: curse room %d" % [seed_value, r])
	var permille := with * 1000 / SEEDS
	gut.p("curse rooms: %d of %d floors (%d per mille)" % [with, SEEDS, permille])
	gut.p("in a small room: %d (of %d floors with a small room allowed)" % [small, could_be_small])
	assert_eq(
		bad, 0, "every curse room is an allowed room, small when one can be, the same on a rebuild"
	)
	assert_between(permille, 370, 430, "about 40 % of floors")


func test_every_deep_floor_gets_one() -> void:
	assert_eq(_rules.curse_room_deep_chance_permille, 1000, "the data's value (S5)")
	var with := 0
	var n := 300
	for s in n:
		var seed_value := 3 + s * 6007
		var layout := _layout(seed_value)
		var shut := _shut(layout)
		var r := Events.curse_site(layout, seed_value, _rules, shut, true)
		if r >= 0:
			with += 1
			assert_true(_allowed(layout, r, shut), "seed %d: an allowed room" % seed_value)
	gut.p("Deep floors with a curse room: %d of %d" % [with, n])
	assert_eq(with, n, "every Deep floor")


func test_rooms_holding_a_reward_come_after_the_others() -> void:
	var moved := 0
	for s in 200:
		var seed_value := 11 + s * 7919
		var layout := _layout(seed_value)
		var shut := _shut(layout)
		var r := Events.curse_site(layout, seed_value, _rules, shut)
		if r < 0:
			continue
		var held := PackedInt32Array([r])
		var again := Events.curse_site(layout, seed_value, _rules, shut, false, held)
		assert_gte(again, 0, "still a curse room")
		if again != r:
			moved += 1
	gut.p("a reward in the first choice moved the curse room on %d floors" % moved)
	assert_gt(moved, 0, "a room holding a reward is passed over")


func test_the_chance_is_data() -> void:
	var never := EventRules.new()
	never.curse_room_floor_chance_permille = 0
	never.curse_room_deep_chance_permille = 0
	var always := EventRules.new()
	always.curse_room_floor_chance_permille = 1000
	var got := 0
	for s in 100:
		var seed_value := 5 + s * 104729
		var layout := _layout(seed_value)
		assert_eq(Events.curse_site(layout, seed_value, never, PackedInt32Array()), -1)
		assert_eq(Events.curse_site(layout, seed_value, never, PackedInt32Array(), true), -1)
		got += 1 if Events.curse_site(layout, seed_value, always, PackedInt32Array()) >= 0 else 0
	gut.p("chance 1000: %d of 100 floors have an allowed room" % got)
	assert_eq(got, 100, "at 1000 every floor has one")


func test_real_floors_have_at_most_one_altar_in_a_room_of_its_own() -> void:
	var with := 0
	var centred := 0
	var crystals := 0
	for s in 12:
		var w := EventLab.world(100 + s * 31, 1 + s % 3)
		var curse_events := 0
		for k in w.ev.size():
			if Events.table(w, k).curse_room:
				curse_events += 1
				assert_eq(k, w.ev.curse_k, "seed %d: a curse event only on the altar" % s)
		assert_lte(curse_events, 1, "never more than one per floor")
		var f := w.floor_layout
		if w.ev.curse_k < 0:
			assert_eq(f.curse_room, -1, "no curse room without its altar")
			continue
		with += 1
		var k := w.ev.curse_k
		var room := w.ev.room[k]
		var rect := f.rooms[room]
		assert_eq(f.curse_room, room, "the layout names it")
		assert_eq(f.layout_of(room), CurseRoom.LAYOUT_ID, "its own fixed layout")
		assert_eq(f.room_of(w.ev.pos(k)), room, "the altar inside its room")
		if w.ev.pos(k) == rect.get_center():
			centred += 1
		for k2 in w.ev.size():
			if k2 != k:
				assert_ne(w.ev.room[k2], room, "the curse room holds only its altar")
		if Gamble.present(w):
			assert_ne(f.room_of(w.gamble_pos), room, "not the shrine's room")
		for i in range(f.slab_first, f.walls.size()):
			assert_false(rect.grow(0.01).encloses(f.walls[i].bounds()), "no interior piece left")
		for prop: Array in f.layout_props:
			assert_false(rect.has_point(prop[1]), "no designed piece left")
		assert_true(f.spawn_points[room].is_empty(), "no spawn point in the layout")
		for q in w.spawn_points:
			assert_ne(f.room_of(q), room, "no enemy spawns inside")
		assert_gte(f.curse_solids.size(), 1, "the altar's footprint")
		assert_eq(f.curse_solids[0].center, w.ev.pos(k), "under the altar")
		for o in f.curse_solids:
			assert_true(w.walls.has(o), "every curse solid is a wall of the world")
		crystals += f.curse_solids.size() - 1
		var must := f.door_approaches(room, 1.0)
		must.append(CurseRoom.front(f, room, w.ev.pos(k)))
		var solid: Array[Obb] = f.room_walls(room)
		solid.append_array(f.curse_solids)
		assert_true(
			FloorReach.whole(rect, solid, FloorParams.defaults().nav_clearance, must),
			"the room stays whole, every doorway and the walk-up reachable"
		)
		assert_true(Events.is_curse_altar(w, k))
	gut.p(
		(
			"real floors with a curse room: %d of 12, altar centred %d, crystals %d"
			% [with, centred, crystals]
		)
	)
	assert_gt(with, 0, "some real floors have one")
	assert_lt(with, 12, "not every floor")
	assert_gt(crystals, with * 3, "crystals round the walls")


## v0.8.0 N19 fix: on run seed 630's floor 1 the small-rooms-first order first chose the furnished shop room
## (curse_rooms leaves out Routes.shop_room_of's guess, made again once the stall stands, and it guessed another room);
## curse_site now leaves out layout.shop_room itself.
func test_never_the_furnished_shop_room() -> void:
	var w := SaveLab.build_floor(SaveLab.run_state(630, 1))
	var f := w.floor_layout
	assert_gte(f.shop_room, 0, "this floor has its shop")
	assert_gte(w.ev.curse_k, 0, "and a curse room")
	assert_ne(w.ev.room[w.ev.curse_k], f.shop_room, "not in the shop's room")
	var run := SaveLab.run_state(630, 1)
	run.floor_rules = RunState.FLOOR_RULES_V080_N17
	var old := SaveLab.build_floor(run)
	gut.p(
		(
			"N17's rules: curse room %d, shop room %d (kept as saved)"
			% [
				old.ev.room[old.ev.curse_k] if old.ev.curse_k >= 0 else -1,
				old.floor_layout.shop_room
			]
		)
	)


func test_whispering_deep_is_offered_only_at_the_altar() -> void:
	var seen := 0
	for s in 6:
		var w := SaveLab.build_floor(SaveLab.run_state(70 + s, 2, &"blade", Routes.Route.DEEP))
		assert_gte(w.ev.curse_k, 0, "seed %d: a Deep floor has a curse room" % (70 + s))
		for k in w.ev.size():
			if Events.table(w, k).id == &"whispering_deep":
				assert_eq(k, w.ev.curse_k, "Whispering Deep stands on the altar")
				seen += 1
		var normal := SaveLab.build_floor(SaveLab.run_state(70 + s, 2))
		for k in normal.ev.size():
			assert_ne(Events.table(normal, k).id, &"whispering_deep", "never on a normal floor")
	assert_eq(seen, 6, "on every Deep floor (S5)")


func test_echo_mirror_is_not_offered_until_a_stat_is_raised() -> void:
	var w := _floor_with_altar()
	if w == null:
		return
	var echo := EventLab.event_index(w, &"echo_mirror")
	assert_gte(echo, 0)
	assert_eq(w.ev.events[echo].requires, Events.Need.STAT_RAISED, "the data's rule")
	assert_lt(Events.strongest_stat(w), 0, "a fresh run: no stat raised")
	assert_false(Events.needs_met(w, Events.Need.STAT_RAISED), "so it can't be drawn")
	assert_true(
		Events.needs_met(w, Events.Need.STAT_RAISED, Events.CURSE_RULES_N17),
		"a floor built under N17 drew it on stat cards alone"
	)
	var got := 0
	for i in 200:
		w.ev.rng = RngStream.derive(i, "loot:event")  # test setup: many draws
		assert_ne(Events.draw_event(w, PackedInt32Array(), Events.POOL_CURSE), echo)
	Stats.add_card(w, Stats.Stat.DAMAGE, 0)  # test setup: a raised stat
	assert_true(Events.needs_met(w, Events.Need.STAT_RAISED), "now it can")
	for i in 200:
		w.ev.rng = RngStream.derive(i, "loot:event")
		if Events.draw_event(w, PackedInt32Array(), Events.POOL_CURSE) == echo:
			got += 1
	gut.p("Echo Mirror drawn %d of 200 times once a stat is raised" % got)
	assert_gt(got, 0, "then it can appear")


func test_the_altar_opens_its_panel_and_takes_a_curse() -> void:
	var w := _floor_with_altar()
	if w == null:
		return
	var k := w.ev.curse_k
	EventLab.open(w, k)
	assert_eq(w.ev.open, k, "interact by the altar opens its panel")
	var t := Events.table(w, k)
	var cursed := -1
	for c in t.choice_count():
		if t.curse[c] != Events.CURSE_NONE:
			cursed = c
	assert_gte(cursed, 0, "its event offers a curse")
	assert_eq(
		Events.block(w, k, cursed), Events.OK, "and it can be taken (a fresh run: no greyed choice)"
	)
	EventLab.pick(w, cursed + 1)
	assert_eq(w.ev.open, -1, "taken")
	assert_eq(w.curses_owned.size(), 1, "the curse is held")
	assert_eq(w.ev.state[k], Events.State.DONE, "the altar is spent")


func test_saved_and_hashed() -> void:
	var w := _floor_with_altar()
	if w == null:
		return
	var h := w.state_hash()
	var k := w.ev.curse_k
	w.ev.curse_k = -1
	assert_ne(w.state_hash(), h, "the altar is hashed")
	w.ev.curse_k = k
	assert_eq(w.state_hash(), h)
	var snap := w.to_snapshot()
	var data: Dictionary = (snap["world"] as Dictionary)[&"ev"]
	assert_eq(int(data[&"curse_k"]), k, "in the snapshot")
	var back := World.from_snapshot(snap, EventLab.world(_altar_seed()))
	assert_not_null(back)
	if back != null:
		assert_eq(back.state_hash(), h, "restored into a rebuilt floor")
		assert_eq(back.walls.size(), w.walls.size(), "the same room, its altar and crystals")


func test_an_old_saves_floor_keeps_its_event_rooms_and_has_no_altar() -> void:
	var seed_value := _altar_seed()
	if seed_value < 0:
		return
	var run := SaveLab.run_state(seed_value, 1)
	run.floor_rules = RunState.FLOOR_RULES_V080_N14  # saved before N17
	assert_true(FloorScenario.legacy_curse_room_of(run))
	assert_eq(FloorScenario.curse_room_rules_of(run), Events.CURSE_RULES_BEFORE_N17)
	assert_false(FloorScenario.legacy_curse_room_of(SaveLab.run_state(seed_value, 1)), "today's")
	assert_eq(
		FloorScenario.curse_room_rules_of(SaveLab.run_state(seed_value, 1)), Events.CURSE_RULES_N19
	)
	assert_eq(FloorScenario.curse_room_rules_of(null), Events.CURSE_RULES_N19, "no run")
	var w := SaveLab.build_floor(run)
	assert_eq(w.ev.curse_k, -1, "an older floor has no curse room")
	assert_eq(w.floor_layout.curse_room, -1)
	var snap := w.to_snapshot()
	var data: Dictionary = (snap["world"] as Dictionary)[&"ev"]
	assert_true(WorldSnapshot.ADDED_SINCE_V05[&"EventState"].has(&"curse_k"), "listed as new")
	data.erase(&"curse_k")  # as a snapshot written before N17
	var again := SaveLab.run_state(seed_value, 1)
	again.floor_rules = RunState.FLOOR_RULES_V080_N14
	var back := World.from_snapshot(snap, SaveLab.build_floor(again))
	assert_not_null(back, "an older save's floor fits")
	if back == null:
		return
	assert_eq(back.ev.curse_k, -1)
	assert_eq(back.ev.size(), w.ev.size(), "its pedestals as saved")
	for k in w.ev.size():
		assert_eq(back.ev.pos(k), w.ev.pos(k))
		assert_eq(back.ev.event[k], w.ev.event[k])
	assert_eq(back.state_hash(), w.state_hash(), "the same world")
	var today := World.from_snapshot(snap, SaveLab.floor_world(seed_value, 1))
	if today != null:
		assert_eq(today.ev.curse_k, -1, "an older save never gains an altar")
		assert_eq(today.ev.size(), w.ev.size())


## v0.8.0 N19: a floor saved under N17 (floor rules 7) is rebuilt with N17's curse room: the combat room it picked, its
## interior and spawns kept, no altar solid, the same pedestals and walls.
func test_a_floor_saved_under_n17_keeps_its_curse_room() -> void:
	var found := false
	for s in 80:
		var seed_value := 300 + s
		var run := SaveLab.run_state(seed_value, 1)
		run.floor_rules = RunState.FLOOR_RULES_V080_N17
		assert_eq(FloorScenario.curse_room_rules_of(run), Events.CURSE_RULES_N17)
		var old := SaveLab.build_floor(run)
		if old.ev.curse_k < 0:
			continue
		found = true
		var f := old.floor_layout
		assert_eq(f.curse_room, -1, "N17's room is not furnished")
		var room := old.ev.room[old.ev.curse_k]
		assert_eq(
			room,
			Events.curse_site_n17(f, old.seed_value, old.ev.rules, _shut_w(old)),
			"N17's own pick"
		)
		assert_eq(old.ev.pos(old.ev.curse_k), Events.spot(f, room, old.ev.rules)[0], "N17's spot")
		var snap := old.to_snapshot()
		var again := SaveLab.run_state(seed_value, 1)
		again.floor_rules = RunState.FLOOR_RULES_V080_N17
		var back := World.from_snapshot(snap, SaveLab.build_floor(again))
		assert_not_null(back, "it restores")
		if back != null:
			assert_eq(back.state_hash(), old.state_hash(), "the same world")
			assert_eq(back.walls.size(), old.walls.size(), "the same walls")
		break
	assert_true(found, "a run seed in 300..379 has an N17 curse room on floor 1")


func _shut_w(w: World) -> PackedInt32Array:
	var shut := PackedInt32Array()
	if Gamble.present(w):
		shut.append(w.floor_layout.room_of(w.gamble_pos))
	return shut


## Run seed with a curse room on floor 1 (today's rules), or -1.
func _altar_seed() -> int:
	for s in 60:
		var seed_value := 300 + s
		if EventLab.world(seed_value).ev.curse_k >= 0:
			return seed_value
	fail_test("no run seed in 300..359 has a curse room on floor 1")
	return -1


func _floor_with_altar() -> World:
	var s := _altar_seed()
	return EventLab.world(s) if s >= 0 else null
