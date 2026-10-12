extends GutTest
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards": "Old saves load: each held card maps to its new
## card, in pick order. A card without a match is refunded as shards"): two run saves recorded with v0.6.1's own code
## (main 950add4, payload 3; tests/fixtures/saves/, recorded by the script quoted in
## docs/roadmap/v0.6.5/evidence/WAND_MIGRATION.md) load the way Main.continue_run loads them (the run from the payload,
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
	var ember := _item(w, &"ember_core")
	var drone := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.DRONE_BUDDY))
	var expect := WandMigration.refund_of(w, ember) + WandMigration.refund_of(w, drone)
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[&"wide_arc", &"blade_orbit", &"double_slash", &"echo_slash"],
		"Long Edge → Wide Arc, Orbit Blades → B15, Twin Cast → Double Slash, Echo Storm → Wave, in pick order"
	)
	assert_eq(
		_levels(w), [1, 2, 1, 5], "the ability's level carries; the legendary version is level 5"
	)
	assert_eq(
		refund, expect, "Ember Core (S1, pending) and the Drone are refunded at the salvage price"
	)
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
	var storm := _item(w, &"storm_core")
	var expect := WandMigration.refund_of(w, storm)
	var refund := WandMigration.run(w)
	assert_eq(
		_ids(w),
		[&"gun_spread", &"gun_homing", &"gun_mine", &"gun_rapid_fire"],
		"Splinter Shot → Spread, Seeker → Homing, Bomb Lobber + Cluster Payload → Mine, Rapid Coil → Rapid Fire"
	)
	assert_eq(_levels(w), [1, 1, 3, 1])
	assert_eq(refund, expect, "Storm Core (S2, pending) at floor 2's salvage price")
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
