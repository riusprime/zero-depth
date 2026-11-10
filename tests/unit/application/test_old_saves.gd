extends GutTest
## Floors built under older floor rules and world snapshots without newer fields: what the sim still rebuilds and
## restores. A run payload of an older version is refused before any of this (test_refused_saves).


## v0.7.5 BF1 (owner N18): today's boss rooms are 4 x 4; a floor saved before (floor rules 1 or 2) is rebuilt with the
## boss's room of then, so its snapshot still fits; the next floor is today's.
func test_a_save_from_before_the_big_boss_rooms_keeps_its_room() -> void:
	for rules in [RunState.FLOOR_RULES_V070, RunState.FLOOR_RULES_V075_MG]:
		var run := SaveLab.run_state(41, 1)
		run.floor_rules = rules
		assert_true(run.legacy_boss_room())
		var w := SaveLab.build_floor(run)
		var cells := w.floor_layout.room_cells[w.floor_layout.boss_room].size
		assert_ne(cells, Vector2i(4, 4), "rules %d: the room of then" % rules)
		var now := SaveLab.run_state(41, 1)
		assert_false(now.legacy_boss_room())
		var fresh := SaveLab.build_floor(now)
		assert_eq(fresh.floor_layout.room_cells[fresh.floor_layout.boss_room].size, Vector2i(4, 4))
		run.finish_floor(w)
		assert_false(run.legacy_boss_room(), "the next floor: the big room")


## v0.8.0 RT (owner O12): today's floors carry the designed rooms (floor rules 4); a floor saved before RT (rules 1-3)
## is rebuilt with its rule-built rooms, so its snapshot still fits it and not today's floor; the next floor is today's.
func test_a_save_from_before_the_designed_rooms_keeps_its_rooms() -> void:
	var old := SaveLab.run_state(41, 1)
	old.floor_rules = RunState.FLOOR_RULES_V075_BF1
	assert_false(old.designed_rooms(), "rules 3: before RT")
	var w := SaveLab.build_floor(old)
	for room in w.floor_layout.room_count():
		assert_eq(w.floor_layout.layout_of(room), &"", "room %d: rule-built, as saved" % room)
	var saved := RunSaver.payload_of(w, old, 1, PackedByteArray())
	assert_eq(int(saved["run"]["floor_rules"]), RunState.FLOOR_RULES_V075_BF1)
	var repo := ContentRepository.load_all()
	var resumed := RunSaver.run_from(
		saved, ContentCompiler.compile_run(repo.get_def(&"run", SaveLab.RUN_ID))
	)
	assert_false(resumed.designed_rooms(), "the payload keeps its rules")
	assert_true(
		(RunSaver.floor_tables(resumed, repo)[&"map"] as FloorParams).room_layouts.is_empty()
	)
	var again := SaveLab.build_floor(resumed)
	assert_eq(WorldSnapshot.apply(again, saved["world"]), "", "the saved floor rebuilds the same")
	var now := SaveLab.run_state(41, 1)
	assert_true(now.designed_rooms())
	var fresh := SaveLab.build_floor(now)
	var designed := 0
	for room in fresh.floor_layout.room_count():
		if fresh.floor_layout.layout_of(room) != &"":
			designed += 1
	assert_gt(designed, 0, "today's floor 1 of run 41 has designed rooms")
	assert_ne(WorldSnapshot.apply(fresh, saved["world"]), "", "and is not the floor that was saved")
	old.finish_floor(w)
	assert_true(old.designed_rooms(), "the next floor: designed rooms")


## v0.8.0 RT2 (G2 RT): today's floors carry layouts for every room size (floor rules 5); a floor saved under RT1 (rules
## 4) is rebuilt with RT1's three layouts only, so its snapshot still fits it and not today's floor; the next floor is
## today's.
func test_a_save_from_the_first_designed_rooms_keeps_its_rooms() -> void:
	var repo := ContentRepository.load_all()
	var old := SaveLab.run_state(41, 1)
	old.floor_rules = RunState.FLOOR_RULES_V080_RT1
	assert_true(old.designed_rooms(), "rules 4: designed rooms")
	assert_true(old.rt1_rooms(), "rules 4: RT1's three")
	var tables: Dictionary = (RunSaver.floor_tables(old, repo)[&"map"] as FloorParams).room_layouts
	var ids := []
	for key: Vector2i in tables:
		for t: RoomLayoutTable in tables[key]:
			ids.append(String(t.id))
	ids.sort()
	assert_eq(ids, ["room_2x2_1", "room_3x2_1", "room_3x3_1"], "only RT1's layouts")
	var w := SaveLab.build_floor(old)
	var designed := 0
	for room in w.floor_layout.room_count():
		var id := w.floor_layout.layout_of(room)
		designed += 1 if id != &"" else 0
		assert_true(id == &"" or id in RunSaver.RT1_LAYOUTS, "room %d: %s, as saved" % [room, id])
	assert_gt(designed, 0, "the RT1 floor of run 41 has designed rooms")
	var saved := RunSaver.payload_of(w, old, 1, PackedByteArray())
	assert_eq(int(saved["run"]["floor_rules"]), RunState.FLOOR_RULES_V080_RT1)
	var resumed := RunSaver.run_from(
		saved, ContentCompiler.compile_run(repo.get_def(&"run", SaveLab.RUN_ID))
	)
	assert_true(resumed.rt1_rooms(), "the payload keeps its rules")
	var again := SaveLab.build_floor(resumed)
	assert_eq(WorldSnapshot.apply(again, saved["world"]), "", "the saved floor rebuilds the same")
	var now := SaveLab.run_state(41, 1)
	assert_false(now.rt1_rooms())
	var fresh := SaveLab.build_floor(now)
	var new_sizes := 0
	for room in fresh.floor_layout.room_count():
		var id := fresh.floor_layout.layout_of(room)
		new_sizes += 1 if id != &"" and not id in RunSaver.RT1_LAYOUTS else 0
	assert_gt(new_sizes, 0, "today's floor 1 of run 41 has the other layouts")
	assert_ne(WorldSnapshot.apply(fresh, saved["world"]), "", "and is not the floor that was saved")
	old.finish_floor(w)
	assert_false(old.rt1_rooms(), "the next floor: today's rules")
	assert_eq(old.floor_rules, RunState.FLOOR_RULES)


## v0.8.0 SR (owner O13): today's floors put the shop in its biome's shop room (floor rules 5); a floor saved before SR
## (rules 1-4) is rebuilt with the terminal it had, in the room as it was, so its snapshot still fits it and not
## today's floor; the shop's room is the same either way (ShopPlacement's rule is unchanged); the next floor is
## today's.
func test_a_save_from_before_the_shop_rooms_keeps_its_terminal() -> void:
	var old := SaveLab.run_state(41, 1)
	old.floor_rules = RunState.FLOOR_RULES_V080_RT1
	assert_true(old.designed_rooms(), "rules 4: the designed rooms")
	assert_false(RunSaver.shop_rooms(old), "rules 4: before SR")
	var w := SaveLab.build_floor(old)
	assert_true(w.shop.present(), "floor 1 has its shop")
	assert_false(WorldReader.new(w).shop_stall(), "the terminal, as saved")
	var saved := RunSaver.payload_of(w, old, 1, PackedByteArray())
	assert_eq(int(saved["run"]["floor_rules"]), RunState.FLOOR_RULES_V080_RT1)
	var repo := ContentRepository.load_all()
	var resumed := RunSaver.run_from(
		saved, ContentCompiler.compile_run(repo.get_def(&"run", SaveLab.RUN_ID))
	)
	assert_false(RunSaver.shop_rooms(resumed), "the payload keeps its rules")
	assert_true((RunSaver.floor_tables(resumed, repo)[&"shop"] as ShopTable).rooms.is_empty())
	var again := SaveLab.build_floor(resumed)
	assert_eq(WorldSnapshot.apply(again, saved["world"]), "", "the saved floor rebuilds the same")
	var now := SaveLab.run_state(41, 1)
	assert_true(RunSaver.shop_rooms(now))
	var fresh := SaveLab.build_floor(now)
	assert_true(WorldReader.new(fresh).shop_stall(), "today's floor: the stall")
	assert_eq(fresh.floor_layout.shop_room, w.floor_layout.shop_room, "in the same room")
	assert_ne(WorldSnapshot.apply(fresh, saved["world"]), "", "and is not the floor that was saved")
	old.finish_floor(w)
	assert_true(RunSaver.shop_rooms(old), "the next floor: shop rooms")


## v0.9.5 AQ: a floor saved under floor rules 1-17 is rebuilt with its 1-2 event rooms (no cap, repeats allowed) and
## records no events_seen; a run save from before AQ has no events_seen in its carry and loads with none.
func test_a_floor_saved_before_aq_keeps_its_event_rooms() -> void:
	var run := SaveLab.run_state(41, 2)
	run.floor_rules = RunState.FLOOR_RULES_V090_CF2
	assert_false(FloorScenario.rare_events_of(run))
	var w := SaveLab.build_floor(run)
	assert_eq(w.ev.rules.events_max_per_run, 0, "no cap on the old floor")
	assert_between(w.ev.size(), 1, 3, "its 1-2 event rooms (and the curse room)")
	assert_eq(w.events_seen.size(), 0, "records nothing")
	run.floor_rules = RunState.FLOOR_RULES
	assert_true(FloorScenario.rare_events_of(run))
	assert_eq(SaveLab.build_floor(run).ev.rules.events_max_per_run, 2, "today's floor: capped")
	var p := RunSaver.payload_of(w, run, 1, PackedByteArray())
	(p["run"]["carry"] as Dictionary).erase(&"events_seen")
	assert_false(SaveLab.run_from(p).carry.has(&"events_seen"), "an old carry has no list")
	assert_eq(SaveLab.build_floor(SaveLab.run_from(p)).events_seen.size() <= 1, true)


## v0.9.5 TS (owner Q7): a floor saved under floor rules 1-20 keeps both switches in the host room, its 15 s timer
## and no lever; a save of it lacks the lever's fields and still fits. Today's floor (rules 21) spreads the switches,
## runs 20 s and has a lever.
func test_a_floor_saved_before_ts_keeps_its_timed_door() -> void:
	var run := SaveLab.run_state(2, 1)
	run.floor_rules = RunState.FLOOR_RULES_V095_DR
	var old := SaveLab.build_floor(run)
	assert_not_null(old.timed, "this floor has a timed door")
	if old.timed == null:
		return
	var f := old.floor_layout
	assert_eq(old.timed.timer_ticks, 900, "15 s")
	assert_eq(old.timed.lever, -1, "no lever")
	assert_true(f.timed_switch_rooms.is_empty(), "both switches in the host")
	for q in f.timed_switches:
		assert_eq(f.room_of(q), f.timed_host)
	var now_run := SaveLab.run_state(2, 1)
	assert_eq(now_run.floor_rules, RunState.FLOOR_RULES, "a new floor is on today's rules")
	assert_eq(RunState.FLOOR_RULES, RunState.FLOOR_RULES_V0105_O14)
	var now := SaveLab.build_floor(now_run)
	assert_eq(now.timed.timer_ticks, 1200, "20 s")
	assert_gte(now.timed.lever, 0, "and a lever")
	assert_eq(now.floor_layout.timed_switch_rooms.size(), 2)
	# a mid-timer save of the old floor, without the new fields, resumes exactly
	for k in 2:
		old.actors.set_pos(0, f.timed_switches[k] + Vector2(0.3, 0.0))
		old.vel = Vector2.ZERO
		old.step(InputFrame.new())
		old.step(InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT))
	assert_eq(old.timed.state, TimedDoor.State.OPEN)
	for k in 60:
		old.step(InputFrame.new())
	var snap := WorldSnapshot.take(old)
	for field in [&"lever", &"lever_ticks", &"open_ticks"]:
		(snap["world"][&"timed"] as Dictionary).erase(field)
	var base := SaveLab.build_floor(run)
	assert_eq(WorldSnapshot.apply(base, snap), "", "an old snapshot fits")
	assert_eq(base.timed.open_ticks, 900, "its door keeps its 15 s")
	assert_eq(base.state_hash(), old.state_hash(), "same state")


## v0.10.5 W3-O11 (owner F21, "Share one, scaled"): floor 1's pool shares the Brood Mother with floor 2's. A run saved
## under the rules before O11 (`boss_draw`) meets every floor's boss it would have then: floor 1 from the Gatekeeper
## and the Warlord, each floor from its own pool on its `boss_<f>` stream, whatever was met. A floor-2 save of such a
## run where today's rules would differ resumes on its own boss (the snapshot fits, the same state); a new run's
## payload keeps today's rules.
func test_a_run_saved_before_o11_keeps_its_bosses() -> void:
	var repo := ContentRepository.load_all()
	var ids: Array = ContentCompiler.compile_bosses(repo).map(
		func(t: BossTable) -> StringName: return t.id
	)
	var pools := RunContentCompiler.compile_boss_pools(repo, SaveLab.floors())
	var brood := ids.find(&"brood_mother")
	assert_true(pools[0].has(brood) and pools[1].has(brood), "floors 1 and 2 share her")
	var then: Array[PackedInt32Array] = []
	for p in pools:
		then.append(p.duplicate())
	then[0] = PackedInt32Array([ids.find(&"gatekeeper"), ids.find(&"warlord")])
	var differs := -1
	for s in 300:
		var old := SaveLab.run_state(1 + s, 1, &"blade", 0, repo)
		old.boss_draw = RunState.BOSS_DRAW_LEGACY
		var now := SaveLab.run_state(1 + s, 1, &"blade", 0, repo)
		for f in range(1, 6):
			var b := FloorShape.boss(old, pools, f)
			assert_eq(
				b, old.pick_boss(then[f - 1], f), "seed %d floor %d: the boss of then" % [1 + s, f]
			)
		if differs < 0 and FloorShape.boss(now, pools, 2) != FloorShape.boss(old, pools, 2):
			differs = 1 + s
	assert_gt(differs, 0, "some run's floor 2 differs under today's rules")
	# A floor-2 save of that run, under the rules before O11.
	var run := SaveLab.run_state(differs, 2, &"blade", 0, repo)
	run.boss_draw = RunState.BOSS_DRAW_LEGACY
	var w := SaveLab.build_floor(run, &"", repo)
	CombatLab.idle(w, 30)
	var p := RunSaver.payload_of(w, run, 99, PackedByteArray([1]))
	assert_eq(int(p["run"]["boss_draw"]), RunState.BOSS_DRAW_LEGACY, "it saves its rules")
	var back := SaveLab.run_from(p)
	assert_eq(back.boss_draw, RunState.BOSS_DRAW_LEGACY, "and resumes with them")
	assert_eq(FloorShape.boss(back, pools, 2), FloorShape.boss(run, pools, 2))
	var w2 := SaveLab.build_floor(back, &"", repo)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "the old snapshot fits")
	assert_eq(w2.state_hash(), w.state_hash(), "Continue resumes the same state")
	# Today's run saves and resumes on today's rules.
	var fresh := SaveLab.run_state(differs, 1, &"blade", 0, repo)
	assert_eq(fresh.boss_draw, RunState.BOSS_DRAW)
	assert_eq(RunState.BOSS_DRAW, RunState.BOSS_DRAW_V0105_O11)
	var wf := SaveLab.build_floor(fresh, &"", repo)
	var q := RunSaver.payload_of(wf, fresh, 99, PackedByteArray([1]))
	assert_eq(SaveLab.run_from(q).boss_draw, RunState.BOSS_DRAW, "a new payload keeps today's draw")


## v0.10.5 W3-O9 (owner, 2026-11-04: "we are gonna be removing the lift curse and the sell"): a floor saved mid-shop
## right after a sale, an ability salvaged or a curse lift (ShopState.last_action SELL / SALVAGE_ABILITY / CLEANSE, a
## sold slot, the lift's record in EventState) loads: the snapshot fits, Continue resumes the same state, the shop is
## still open and offers only its 4 cards, the heal and the reroll; the old sell and lift picks are refused.
func test_a_floor_saved_mid_shop_after_a_sale_or_a_lift_loads() -> void:
	var repo := ContentRepository.load_all()
	var run := SaveLab.run_state(41, 1, &"blade", 0, repo)
	var w := SaveLab.build_floor(run, &"", repo)
	assert_true(w.shop.present(), "floor 1 has its shop")
	# TEST SETUP (labelled): the shop as a pre-W3-O9 build left it after a sale; the sim can no longer sell.
	Shop.restock(w)
	w.shop.open = true
	w.shop.offer[0] = ShopState.SOLD
	w.shop.bought = 1
	var retired := [
		ShopState.Action.SELL, ShopState.Action.SALVAGE_ABILITY, ShopState.Action.CLEANSE
	]
	for action: int in retired:
		w.shop.last_action = action
		w.shop.last_tick = w.tick
		w.shop.last_value = 12
		w.ev.cleanse_tick = w.tick
		w.ev.cleanse_last = 0
		var p := RunSaver.payload_of(w, run, 99, PackedByteArray([1]))
		var back := SaveLab.run_from(p)
		var w2 := SaveLab.build_floor(back, &"", repo)
		assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "action %d: the snapshot fits" % action)
		assert_eq(
			w2.state_hash(), w.state_hash(), "action %d: Continue resumes the same state" % action
		)
		assert_true(w2.shop.open, "still shopping")
		var s := WorldReader.new(w2).shop()
		assert_eq(int(s["last_action"]), action, "the old action still reads")
		assert_eq((s["stock"] as Array).size(), 4)
		assert_false(s.has("sell") or s.has("cleanse_curse"), "nothing to sell or lift")
		var shards := w2.shards
		for v in [22, 100]:
			var f := InputFrame.new()
			f.pick = v
			w2.step(f)
			assert_eq(w2.shop.denied_tick, w2.tick - 1, "pick %d refused" % v)
		assert_eq(w2.shards, shards, "nothing paid or refunded")


## v0.10.5 W3-O9: selling is gone, but an old save's unmatched card is still refunded at the old salvage numbers
## (WandMigration.refund_of): an item 40 % of its rarity's price under the floor step alone (a rare: 22 / 33 / 44 on
## floors 1-3), an ability 10 shards per level.
func test_the_migration_refunds_keep_the_old_salvage_numbers() -> void:
	var repo := ContentRepository.load_all()
	var w := SaveLab.build_floor(SaveLab.run_state(41, 1, &"blade", 0, repo), &"", repo)
	var rare := -1
	for i in w.item_tables.size():
		if rare < 0 and Shop.rarity(w, i) == 1 and not w.item_tables[i].retired:
			rare = i
	assert_gt(rare, -1)
	var got := []
	for f in [1, 2, 3]:
		w.floor_index = f
		got.append(WandMigration.refund_of(w, rare))
	assert_eq(got, [22, 33, 44])
	assert_eq([WandMigration.REFUND_PERMILLE, WandMigration.ABILITY_REFUND_PER_LEVEL], [400, 10])
