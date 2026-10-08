extends GutTest
## The expected-build bot (v0.4.0 TU; tests/support/run_bot.gd) on the real floor 1 for its first 150 s, as the
## tuning sims run it (TuningRun). CI-safe bands, far inside what the sims measured (evidence/TUNING.md), so a change
## that breaks the curve's promise fails here: the calm minute doesn't kill, the first card (the altar by the start)
## comes inside it, the build has grown by the end of the window, and the crowd stays under the curve's cap.

const WINDOW_TICKS := 150 * 60


func test_card_scores_put_abilities_first() -> void:
	var w := RunLab.new(ContentRepository.load_all(), 4711, &"blade").floor_world()
	var fresh := -1
	for idx in w.ability_tables.size():
		if Abilities.can_take(w, idx) and not Abilities.owned(w, idx):
			fresh = idx
			break
	assert_gte(fresh, 0)
	var start := w.ability_owned[0]
	var dmg := -1
	for s in w.stat_tables.size():
		if w.stat_tables[s] != null and w.stat_tables[s].id == &"damage":
			dmg = s
	var new_ability := RunBot.score_card(w, Offers.ability_code(fresh))
	var level_up := RunBot.score_card(w, Offers.ability_code(start))
	var epic := RunBot.score_card(w, Offers.stat_code(dmg, 2))
	var common := RunBot.score_card(w, Offers.stat_code(dmg, 0))
	assert_gt(new_ability, level_up, "a new ability beats a level-up")
	assert_gt(level_up, common, "a level-up beats a common stat card")
	assert_gt(epic, common, "rarity counts")


func test_floor_1_opens_calm_and_lets_the_build_grow() -> void:
	for build in [&"blade", &"gun"]:
		var lab := RunLab.new(ContentRepository.load_all(), 7301, build)
		var w := lab.floor_world()
		var bot := RunBot.new(7301 * 977)
		bot.start_floor(w)
		var peak_calm := 0
		var cards_calm := -1
		for t in WINDOW_TICKS:
			w.step(bot.frame(w))
			if w.run_ticks < 3600:
				peak_calm = maxi(peak_calm, WaveDirector.enemies_alive(w))
			elif cards_calm < 0:
				cards_calm = bot.cards_taken
			if w.player_dead():
				break
		assert_gte(w.run_ticks, 3600, "%s: alive through the calm minute" % build)
		assert_lte(peak_calm, w.spawner.cap_now(1, 0), "%s: the calm cap holds" % build)
		assert_gte(cards_calm, 1, "%s: a card in the calm minute (the altar by the start)" % build)
		assert_gte(bot.cards_taken, 2, "%s: two cards by 150 s" % build)
