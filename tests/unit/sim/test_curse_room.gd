extends GutTest
## v0.8.0 N17 (owner O75: "they need to appear once max per floor and 40% of floors not all the time"): the curse room.
## Over many generated floors (the floor pipeline's layout steps, with today's map, arena and shop rules): about
## curse_room_floor_chance_permille of floors have one, never in the start hall, the boss room or its host, the portal
## room, the Overrun room, the shop's room, an arena or the shrine's room; on real floors at most one curse altar, the
## only pedestal holding a curse event, and the common rooms never draw one. Saved and hashed; a floor saved before
## N17 keeps its event rooms as they were.

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


func test_about_forty_percent_of_floors_get_one_in_an_allowed_room() -> void:
	assert_eq(_rules.curse_room_floor_chance_permille, 400, "the data's starting value")
	var with := 0
	var bad := 0
	for s in SEEDS:
		var seed_value := 1 + s * 7919
		var layout := _layout(seed_value)
		var shut := PackedInt32Array()
		var shrine := Gamble.site(layout, _gamble, false, _tables[&"map"])
		if not shrine.is_empty():
			shut.append(layout.room_of(shrine[0]))
		var r := Events.curse_site(layout, seed_value, _rules, shut)
		if r < 0:
			continue
		with += 1
		var ok := r != layout.start_room and r != layout.boss_room and r != layout.boss_host_room
		ok = ok and r != layout.portal_room and r != layout.overrun_room and r != layout.shop_room
		ok = ok and not layout.arena_rooms.has(r) and not shut.has(r)
		ok = ok and Events.spot(layout, r, _rules).size() == 1
		if s < 100:  # a pure function: the same room on a rebuilt layout
			ok = ok and r == Events.curse_site(_layout(seed_value), seed_value, _rules, shut)
		if not ok:
			bad += 1
			gut.p("seed %d: curse room %d" % [seed_value, r])
	var permille := with * 1000 / SEEDS
	gut.p("curse rooms: %d of %d floors (%d per mille)" % [with, SEEDS, permille])
	assert_eq(bad, 0, "every curse room is an allowed combat room, the same on a rebuild")
	assert_between(permille, 370, 430, "about 40 % of floors")


func test_the_chance_is_data() -> void:
	var never := EventRules.new()
	never.curse_room_floor_chance_permille = 0
	var always := EventRules.new()
	always.curse_room_floor_chance_permille = 1000
	var got := 0
	for s in 100:
		var seed_value := 5 + s * 104729
		var layout := _layout(seed_value)
		assert_eq(Events.curse_site(layout, seed_value, never, PackedInt32Array()), -1)
		got += 1 if Events.curse_site(layout, seed_value, always, PackedInt32Array()) >= 0 else 0
	gut.p("chance 1000: %d of 100 floors have an allowed room" % got)
	assert_gt(got, 95, "at 1000 nearly every floor has one (a floor may lack an allowed room)")


func test_real_floors_have_at_most_one_altar_and_only_it_holds_a_curse_event() -> void:
	var with := 0
	for s in 12:
		var w := EventLab.world(100 + s * 31, 1 + s % 3)
		var curse_events := 0
		for k in w.ev.size():
			var t := Events.table(w, k)
			if t.curse_room:
				curse_events += 1
				assert_eq(k, w.ev.curse_k, "seed %d: a curse event only on the altar" % s)
		assert_lte(curse_events, 1, "never more than one per floor")
		if w.ev.curse_k >= 0:
			with += 1
			var room := w.ev.room[w.ev.curse_k]
			assert_eq(w.floor_layout.room_of(w.ev.pos(w.ev.curse_k)), room, "inside its room")
			for k in w.ev.size():
				if k != w.ev.curse_k:
					assert_ne(w.ev.room[k], room, "the curse room holds only its altar")
			if Gamble.present(w):
				assert_ne(w.floor_layout.room_of(w.gamble_pos), room, "not the shrine's room")
			assert_true(Events.is_curse_altar(w, w.ev.curse_k))
	gut.p("real floors with a curse room: %d of 12" % with)
	assert_gt(with, 0, "some real floors have one")
	assert_lt(with, 12, "not every floor")


func test_the_altar_opens_its_panel_and_takes_a_curse() -> void:
	var w := _floor_with_altar()
	if w == null:
		return
	var k := w.ev.curse_k
	Stats.add_card(w, Stats.Stat.DAMAGE, 0)  # test setup: a raised stat (Echo Mirror echoes one)
	EventLab.open(w, k)
	assert_eq(w.ev.open, k, "interact by the altar opens its panel")
	var t := Events.table(w, k)
	var cursed := -1
	for c in t.choice_count():
		if t.curse[c] != Events.CURSE_NONE:
			cursed = c
	assert_gte(cursed, 0, "its event offers a curse")
	assert_eq(Events.block(w, k, cursed), Events.OK, "and it can be taken")
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


func test_an_old_saves_floor_keeps_its_event_rooms_and_has_no_altar() -> void:
	var seed_value := _altar_seed()
	if seed_value < 0:
		return
	var run := SaveLab.run_state(seed_value, 1)
	run.floor_rules = RunState.FLOOR_RULES_V080_N14  # saved before N17
	assert_true(FloorScenario.legacy_curse_room_of(run))
	assert_false(FloorScenario.legacy_curse_room_of(SaveLab.run_state(seed_value, 1)), "today's")
	assert_false(FloorScenario.legacy_curse_room_of(null), "a floor without a run")
	var w := SaveLab.build_floor(run)
	assert_eq(w.ev.curse_k, -1, "an older floor has no curse room")
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
	# Restored into today's base (an altar there): the save's own pedestals win and none is the altar.
	var today := World.from_snapshot(snap, SaveLab.floor_world(seed_value, 1))
	if today != null:
		assert_eq(today.ev.curse_k, -1, "an older save never gains an altar")
		assert_eq(today.ev.size(), w.ev.size())


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
