extends GutTest
## v0.11.0 O3 (owner L5, Q9 a) and O2 in the real game, by input events only (Input.parse_input_event): a Gun run from
## the menu; backtick opens the dev panel and clicks pick the Gatekeeper, summon it and turn God on (the panel stays
## open through the fight, as test_e2e_stone_spikes). TEST HELPER (labelled, as test_e2e_nemesis poses a boss's HP):
## the boss's HP is set just under its phase 2 threshold; the rest is the real loop. As phase 2 begins the quake
## pillars rise (walls in the sim, drawn by StoneSpikeViews with their pulse rings), and the boss hint (HUD
## ObjectiveHints) points at each standing pillar.

const PILLAR := ObjectiveMarkers.GATEKEEPER_PILLAR


func test_the_gatekeepers_quake_pillars_rise_in_phase_2_and_the_hint_points_at_them() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await e.click_dev("God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"gatekeeper")].name_key)
	for k in 16:
		if choice.text == name:
			break
		await e.click_dev("NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name, "the panel names the Gatekeeper")
	await e.click_dev("SpawnBoss")
	await e.frames(30)
	var reader := main.driver.reader
	var bid := reader.actor_id(reader.boss_index())
	var i := w.actors.index_of(bid)
	assert_gte(i, 0, "the Gatekeeper is up")
	if i < 0:
		return
	assert_eq(reader.boss_quake_pillars().size(), 0, "no quake pillar in phase 1")
	# TEST HELPER (labelled): the HP just under phase 2's 66 % threshold.
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	var hints := main.get_node("UI/Hud/ObjectiveHints") as ObjectiveHints
	var spikes := main.view.spikes
	var risen := false
	var ringed := false
	var pointed := false
	for k in 600:
		await e.frames(1)
		var pillars := reader.boss_quake_pillars()
		if pillars.is_empty():
			continue
		risen = risen or spikes.quake_count() > 0
		ringed = ringed or spikes.ring_bands() > 0
		var marks := 0
		for m: Dictionary in hints.shown():
			if m["reason"] == PILLAR:
				marks += 1
		var on_pillars := 0
		for o: Dictionary in reader.objectives():
			for p: Dictionary in pillars:
				if o["reason"] == PILLAR and (o["pos"] as Vector2).distance_to(p["center"]) < 0.01:
					on_pillars += 1
		pointed = pointed or (marks == pillars.size() and on_pillars == pillars.size())
		if risen and ringed and pointed:
			break
	var n := reader.boss_quake_pillars().size()
	gut.p("O3 e2e: %d quake pillars standing in phase 2" % n)
	assert_gt(n, 0, "the quake pillars rose as phase 2 began")
	assert_true(risen, "they are drawn")
	assert_true(ringed, "with their pulse rings")
	assert_true(pointed, "the boss hint points at every standing pillar")
	assert_true(hints.visible, "the hint shows on the HUD")
	await e.tap(KEY_QUOTELEFT)
