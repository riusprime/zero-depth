extends GutTest
## v0.6.0 MX1: the migration is exact. Every AttackScenario case (the Blade's four steps, the Gun's bolt and both
## Skills, with each migrated item alone, the v0.5 riders, and all of them together with heat, combos and abilities)
## gives the same outcome digest as the v0.5 attack code did: tests/golden/fixtures/modifier_equivalence.json was
## recorded on 6a83bae before any engine code (tests/golden/generate_modifier_equivalence.gd). The digest covers
## every event's outcome fields (kind, tick, ids, root, parent, depth, amounts, tags, effect, ancestry, position)
## and the attack state (actors, projectiles, the proc ledger, the streams, the swing / echo / chain counters).

const FIXTURE := "res://tests/golden/fixtures/modifier_equivalence.json"

var _want := {}


func before_all() -> void:
	_want = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_the_fixture_has_every_case() -> void:
	assert_eq(_want.size(), AttackScenario.CASES.size())
	for c: Array in AttackScenario.CASES:
		assert_true(_want.has(c[0]), c[0])


func test_every_case_matches_the_v0_5_outcome() -> void:
	for c: Array in AttackScenario.CASES:
		var r := AttackScenario.run(AttackScenario.world(c[1], c[2], c[3], c[4]))
		var want: Dictionary = _want.get(c[0], {})
		assert_eq(r["digest"], want.get("digest"), "%s: the outcome digest" % c[0])
		assert_eq(
			[r["hits"], r["damage"], r["kills"]],
			[int(want.get("hits", -1)), int(want.get("damage", -1)), int(want.get("kills", -1))],
			"%s: hits, damage, kills" % c[0]
		)


func test_the_cases_use_the_migrated_items() -> void:
	var w := AttackScenario.world(&"", [&"long_edge", &"static_chain"], false, [])
	assert_eq(
		Modifiers.book(w).modifier_ids,
		PackedStringArray(["long_edge", "static_chain"]),
		"in pick order"
	)
