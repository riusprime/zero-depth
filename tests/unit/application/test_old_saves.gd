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
	var repo := ContentRepository.load_all()
	var run := RunSaver.run_from(
		p, ContentCompiler.compile_run(repo.get_def(&"run", SaveLab.RUN_ID))
	)
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
		[&"gun_spread", &"gun_homing", &"gun_mine", &"storm_core", &"gun_rapid_fire"],
		"Splinter Shot → G4, Seeker → G8, Bomb Lobber + Cluster Payload → G12, Storm Core stays (S2)"
	)
	assert_eq(_levels(w), [1, 1, 3, 1, 1])
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
	var run := RunSaver.run_from(p, table)
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
