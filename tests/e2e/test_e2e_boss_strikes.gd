extends GutTest
## v0.8.0 AV part 2 (owner O7): the other bosses' ground attacks reach the real game styled and strike as 3D effects.
## Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks turn God on,
## pick each boss in turn and summon it, backtick closes the panel. Each boss's ground attack is drawn with its look
## (TelegraphViews.look_of) and strikes in BossStrikeViews with that boss's look; then KillBoss clears it for the next.

const BOSSES: Array[StringName] = [
	&"warlord", &"brood_mother", &"hive_lens", &"siege_engine", &"foundry"
]


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_each_bosss_ground_attacks_are_styled_and_strike_in_3d() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	for id in BOSSES:
		if not main.is_dev_panel_open():
			await e.tap(KEY_QUOTELEFT)
		# A kill can move the run on (a new world, the panel rebuilt): find them again for each boss.
		var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
		var w := e.world()
		var reader := main.driver.reader
		var table := w.boss_tables[BossLab.table_index(w, id)]
		var name := tr(table.name_key)
		for k in 8:
			if choice.text == name:
				break
			await _click(e, main, "NextBoss")
			await e.frames(1)
		assert_eq(choice.text, name)
		await _click(e, main, "SpawnBoss")
		await e.frames(2)
		await e.tap(KEY_QUOTELEFT)
		assert_false(main.is_dev_panel_open())
		var bid := reader.actor_id(reader.boss_index())
		var looks: Array = (BossStrikeLooks.BY_KIND[table.kind] as Dictionary).values()
		var styled := false
		var struck := false
		var drawn := 0
		var after := 0
		for k in 7200:
			await e.frames(1)
			var i := w.actors.index_of(bid)
			if i < 0:
				break
			var tg := reader.telegraph(i)
			if not tg.is_empty() and looks.has(TelegraphViews.look_of(reader, i, tg)):
				styled = true
			for st: Array in main.view.strikes.strikes():
				struck = struck or looks.has(st[0])
			if struck:
				drawn = maxi(drawn, main.view.strikes.drawn_total())
				after += 1
			if styled and struck and after > 12:
				break
		assert_true(styled, "%s: a ground attack drawn in its look" % id)
		assert_true(struck, "%s: it struck in 3D" % id)
		assert_gt(drawn, 0, "%s: the strike is drawn" % id)
		await e.tap(KEY_QUOTELEFT)
		await _click(e, main, "KillBoss")
		await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	for k in 240:  # every strike ends and gives its pieces back
		await e.frames(1)
		if main.view.strikes.strike_count() == 0:
			break
	assert_eq(main.view.strikes.strike_count(), 0, "the strikes end")
