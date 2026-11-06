extends GutTest
## The card pool (v0.5.0 CP; ROADMAP v0.5.0: "a 40–50 card candidate pool"): each build's pool of distinct cards
## (abilities, stat-card kinds, mods; step AB's three abilities, in the data since the AB merge) holds 40–50 cards, and
## every card in it is offered by some altar or chest from a reachable state (no dead cards). The frequency table
## is printed here and by scripts/checks/card_pool.gd.

const SEEDS := 300

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func test_each_builds_pool_holds_40_to_50_distinct_cards() -> void:
	for build in CardPoolSurvey.BUILDS:
		var p := CardPoolSurvey.pool(_repo, build)
		var n := p[0].size() + p[1].size()
		gut.p(
			(
				"%s pool: %d in the data + %d planned (%s) = %d"
				% [build, p[0].size(), p[1].size(), p[1], n]
			)
		)
		assert_between(
			n,
			CardPoolSurvey.POOL_MIN,
			CardPoolSurvey.POOL_MAX,
			"%s: %d-%d cards" % [build, CardPoolSurvey.POOL_MIN, CardPoolSurvey.POOL_MAX]
		)


func test_every_card_in_the_pool_is_offered_from_some_reachable_state() -> void:
	for build in CardPoolSurvey.BUILDS:
		var counts := CardPoolSurvey.survey(_repo, build, SEEDS)
		var keys: PackedStringArray = CardPoolSurvey.pool(_repo, build)[0]
		for line in CardPoolSurvey.table(build, counts, keys):
			gut.p(line)
		for k in keys:
			var c: Array = counts.get(k, [0, 0])
			if k == "ability:pulse_gun":  # v0.9.5 CLV: the Pulse Gun is never offered
				assert_eq(c[0] + c[1], 0, "%s: the Pulse Gun is never offered" % build)
				continue
			assert_gt(c[0] + c[1], 0, "%s: %s is offered somewhere" % [build, k])
		var legend := {}  # v0.8.0 RR: a Legendary card is the boss's tier, offered here only rarely
		for t in CardPoolSurvey.world(_repo, 1, build, []).item_tables:
			if t.rarity == ItemTable.LEGENDARY:
				legend["mod:%s" % t.id] = true
		for k: String in counts:
			if k != "_rolls" and not legend.has(k):
				assert_has(keys, k, "%s: %s is in the pool" % [build, k])


func test_rule_cards_and_ability_mods_show_up_often_enough_to_matter() -> void:
	var counts := CardPoolSurvey.survey(_repo, &"blade", SEEDS)
	for id in ["glass_cannon", "onrush", "overkill", "hoarder", "fast_hands"]:
		var c: Array = counts.get("stat:" + id, [0, 0])
		assert_gt(c[0] + c[1], SEEDS / 4, "%s: offered in more than one roll in 16" % id)
	# v0.6.5 WN5b: the ability mods retired with their abilities (WAND.md; data/wand/migration.tres): never offered.
	for id in ["cluster_payload", "overclocked_drone", "razor_orbit", "afterimage"]:
		assert_false(counts.has("mod:" + id), "%s: retired, never offered" % id)
	for id in [
		"bomb_lobber", "drone_buddy", "orbit_blades", "arc_field", "frost_nova", "flame_trail"
	]:
		assert_false(counts.has("ability:" + id), "%s: retired, never offered" % id)
