extends GutTest
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards": "Old saves load: each held card maps to its new
## card, in pick order. A card without a match is refunded as shards"): two run saves recorded with v0.6.1's own code
## (main 950add4, payload 3; tests/fixtures/saves/, recorded by the script quoted in
## docs/roadmap/v0.7.0/evidence/WAND_MIGRATION.md) load the way Main.continue_run loads them (the run from the payload,
## the floor rebuilt with its carry, the world snapshot written over it, then WandMigration) and hold the new cards.

const DIR := "res://tests/fixtures/saves/"


## [payload, the resumed world before the migration's second pass, its shards then].
func _resume(file: String) -> Array:
	var r := RunSaveStore.decode(FileAccess.get_file_as_bytes(DIR + file))
	assert_eq(r[1], "", "%s decodes" % file)
	var p: Dictionary = (r[0] as Dictionary).get("payload", {})
	assert_eq(int(p["version"]), 3, "a v0.6.1 payload")
	assert_true(RunSaver.is_usable(p), "this game still reads it")
	var run := SaveLab.run_from(p)  # v0.9.0 FV: no run_id, so the 3-floor shape
	assert_eq(run.table.id, RunSaver.LEGACY_RUN_ID)
	var w := SaveLab.build_floor(run)
	assert_eq(WorldSnapshot.apply(w, p["world"]), "", "the v0.6.1 snapshot fits the floor")
	return [p, w, w.shards]


func _ids(w: World) -> Array:
	var out := []
	for c in w.mod_slots:
		out.append(Offers.info(w, c)["id"])
	return out


func _levels(w: World) -> Array:
	var out := []
	for s in w.mod_slots.size():
		out.append(BuildSlots.level_at(w, s))
	return out


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _no_retired(w: World) -> void:
	for idx in w.items_owned:
		assert_false(w.item_tables[idx].retired, "%s still held" % w.item_tables[idx].id)
	for idx in w.ability_owned:
		assert_false(w.ability_tables[idx].retired, "%s still held" % w.ability_tables[idx].id)


## Blade, floor 1: Long Edge, Orbit Blades (level 2), Ember Core, Twin Cast, Drone Buddy, Echo Storm, in that order.
func test_a_v0_6_1_blade_save_maps_each_card_in_pick_order() -> void:
	var got := _resume("v061_blade_floor1.save")
	var w: World = got[1]
	var held := []
	for c in w.mod_slots:
		held.append(Offers.info(w, c)["id"])
	assert_eq(
		held,
		[&"long_edge", &"orbit_blades", &"ember_core", &"twin_cast", &"drone_buddy", &"echo_storm"],
		"the recorded wand, before the migration"
	)
	var drone := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.DRONE_BUDDY))
	var expect := WandMigration.refund_of(w, drone)
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[&"wide_arc", &"blade_orbit", &"ember_core", &"double_slash", &"echo_slash"],
		"Long Edge → B1, Orbit Blades → B15, Ember Core stays (S1), Twin Cast → B5, Echo Storm → B2"
	)
	assert_eq(
		_levels(w), [1, 2, 1, 1, 5], "the ability's level carries; the legendary version is level 5"
	)
	assert_eq(refund, expect, "the Drone (no row) is refunded at the salvage price")
	assert_gt(refund, 0)
	assert_eq(w.shards, int(got[2]) + refund, "into the shards")
	_no_retired(w)
	var h := w.state_hash()
	assert_eq(WandMigration.run(w), 0, "idempotent")
	assert_eq(w.state_hash(), h)
	for t in 120:
		w.step(AttackScenario.frame(t))
	assert_false(w.player_dead(), "the run plays on")


## Gun, floor 2 (carried from floor 1): Splinter Shot, Seeker, Bomb Lobber (level 2), Cluster Payload, Storm Core,
## Rapid Coil. Bomb Lobber and its Cluster Payload both become Mine: the levels add (2 + 1).
func test_a_v0_6_1_gun_save_from_its_carry_maps_and_levels_up_duplicates() -> void:
	var got := _resume("v061_gun_floor2.save")
	var p: Dictionary = got[0]
	var w: World = got[1]
	assert_eq(int(p["run"]["floor_index"]), 2)
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[&"gun_twin", &"gun_homing", &"gun_mine", &"storm_core", &"gun_rapid_fire"],
		(
			"Splinter Shot → G4 (v0.9.0 TW: Spread is Twin now), Seeker → G8, Bomb Lobber + Cluster Payload"
			+ " → G12, Storm Core stays (S2)"
		)
	)
	assert_eq(
		_levels(w),
		[1, 1, 1, 1, 1],
		"v0.9.5 CLV: Mine no longer levels (its two merged copies read Lv 1)"
	)
	assert_eq(refund, 0, "every card has a match (Storm Core is WN5a's S2)")
	assert_eq(w.shards, int(got[2]) + refund)
	_no_retired(w)
	for t in 120:
		w.step(AttackScenario.frame(t))
	assert_false(w.player_dead(), "the run plays on")


## The payload version is unchanged: the migration reads the content (data/wand/migration.tres), not the version.
func test_the_payload_version_stays_and_older_ones_still_load() -> void:
	assert_eq(RunSaver.PAYLOAD_VERSION, 4)
	for v in [2, 3, 4]:
		assert_true(RunSaver.PAYLOAD_VERSIONS_READ.has(v), "payload %d still loads" % v)


## v0.7.5 MG: a save made before v0.7.5 has no floor rules: its floor is rebuilt with v0.7.0's (10-12 rooms, a third
## of the combat rooms as arenas, a shop on every floor), so its snapshot fits (the two v0.6.1 saves above, floor 1
## and floor 2, the second one with a v0.7.0 shop on floor 2). A save made now records today's rules, and the next
## floor after an old one is always built with them.
func test_an_old_save_keeps_its_v070_floor_and_the_next_floor_is_new() -> void:
	var r := RunSaveStore.decode(FileAccess.get_file_as_bytes(DIR + "v061_gun_floor2.save"))
	var p: Dictionary = (r[0] as Dictionary).get("payload", {})
	assert_false((p["run"] as Dictionary).has("floor_rules"), "recorded before v0.7.5")
	var repo := ContentRepository.load_all()
	var table := ContentCompiler.compile_run(repo.get_def(&"run", SaveLab.RUN_ID))
	var run := SaveLab.run_from(p)  # v0.9.0 FV: in its 3-floor shape
	assert_true(run.v070_floor(), "rebuilt with v0.7.0's rules")
	var old := RunSaver.floor_tables(run, repo)
	assert_eq((old[&"map"] as FloorParams).rooms_max, 12)
	assert_eq((old[&"arena"] as ArenaTable).share_permille, 330)
	assert_true((old[&"shop"] as ShopTable).on_floor(2), "v0.7.0: a shop on every floor")
	var w := SaveLab.build_floor(run)
	assert_true(w.shop.present(), "the saved floor 2 keeps its shop")
	var now := RunSaver.payload_of(w, run, 1, PackedByteArray())
	assert_eq(
		int(now["run"]["floor_rules"]),
		RunState.FLOOR_RULES_V070,
		"re-saved on the old floor: still old"
	)
	run.finish_floor(w)
	assert_false(run.v070_floor(), "the next floor is built with today's rules")
	assert_eq(
		int(RunSaver.payload_of(w, run, 1, PackedByteArray())["run"]["floor_rules"]),
		RunState.FLOOR_RULES
	)
	var fresh := RunState.start(5, table, &"blade")
	assert_false(fresh.v070_floor(), "a new run: today's rules")
	var new := RunSaver.floor_tables(fresh, repo)
	assert_eq((new[&"map"] as FloorParams).rooms_max, 19)
	assert_false((new[&"shop"] as ShopTable).on_floor(2), "v0.7.5: no shop on floor 2")


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


## v0.9.0 FV (owner Q24; PD-03 changed: a run is 5 floors): a payload without `run_id` is a v0.8.0 run and resumes in
## its 3-floor shape (three_floors: 3 floors, v0.8.0's scaling, 15-19 rooms, the wand's 4 → 6 → 8), so its floor
## rebuilds as saved and the run ends on its floor 3 (the Ascension portal there). A save made now names five_floors.
func test_a_v080_run_resumes_and_ends_as_a_three_floor_run() -> void:
	var repo := ContentRepository.load_all()
	var old := RunState.start(
		41, ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.LEGACY_RUN_ID)), &"blade"
	)
	old.floor_index = 2
	old.routes.append(Routes.Route.NORMAL)
	var w := SaveLab.build_floor(old)
	var saved := RunSaver.payload_of(w, old, 1, PackedByteArray())
	(saved["run"] as Dictionary).erase("run_id")  # as v0.8.0 wrote it
	assert_eq(RunSaver.saved_run_id(saved), RunSaver.LEGACY_RUN_ID)
	var resumed := SaveLab.run_from(saved)
	assert_eq(resumed.table.floors, 3, "still a 3-floor run")
	assert_eq(resumed.floor_index, 2)
	var again := SaveLab.build_floor(resumed)
	assert_eq(WorldSnapshot.apply(again, saved["world"]), "", "the saved floor rebuilds the same")
	assert_between(again.floor_layout.room_count() - 1, 15, 19, "v0.8.0's floor size")
	assert_eq(Wand.slots(again), 6, "floor 2 of 3: six slots, as in v0.8.0")
	assert_false(again.boss_flow.ascension)
	resumed.finish_floor(again)
	assert_eq(resumed.floor_index, 3)
	var last := SaveLab.build_floor(resumed)
	assert_true(last.boss_flow.ascension, "floor 3 is its last: the Ascension portal")
	assert_eq(Wand.slots(last), 8)
	assert_false(last.floor_layout.has_deep_portal, "no Deep gate on its last floor")
	var now := SaveLab.run_state(41, 2)
	var fresh := SaveLab.build_floor(now)
	var p := RunSaver.payload_of(fresh, now, 1, PackedByteArray())
	assert_eq(String(p["run"]["run_id"]), "five_floors", "today's saves name their shape")
	var back := SaveLab.run_from(p)
	assert_eq(back.table.floors, 5)
	assert_eq(WorldSnapshot.apply(SaveLab.build_floor(back), p["world"]), "", "and resume in it")
	assert_eq(Wand.slots(fresh), 5, "floor 2 of 5: five slots")


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
	assert_eq(RunState.FLOOR_RULES, RunState.FLOOR_RULES_V095_BK)
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
