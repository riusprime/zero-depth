extends GutTest
## v0.8.0 AV (owner O7): the Gatekeeper's shock lanes reach the real game as cracked ground, then stone spikes.
## Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks pick the
## Gatekeeper and summon it (God keeps the player standing), backtick closes it. When the boss lays its shock lanes,
## TelegraphViews draws them as cracked ground, and on their strike StoneSpikeViews raises spikes along them, which
## sink back into the pool. v0.8.0 BS1: some stay standing as pillars (walls) for their time, then sink too.


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_the_gatekeepers_shock_lanes_crack_the_ground_and_strike_as_spikes() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"gatekeeper")].name_key)
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
	var reader := main.driver.reader
	var bid := reader.actor_id(reader.boss_index())
	var cracked := false
	var struck := false
	var standing := 0
	var pillars := 0
	for k in 7200:
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		if TelegraphViews.is_cracked(reader.telegraph(i)):
			cracked = true
		if main.view.spikes.strike_count() > 0:
			struck = true
		standing = maxi(standing, main.view.spikes.spike_count())
		if struck and main.view.spikes.strike_count() == 0:
			pillars = maxi(pillars, main.view.spikes.pillar_count())
			if main.view.spikes.spike_count() == 0:
				break
	assert_true(cracked, "the shock lanes were drawn as cracked ground")
	assert_true(struck, "they struck")
	assert_gt(standing, 10, "as a row of stone spikes")
	# v0.8.0 BS1 (owner O5, S1): some stay as pillars, walls in the sim, then sink too.
	assert_gt(pillars, 0, "stone pillars stayed after the strike")
	assert_eq(main.view.spikes.spike_count(), 0, "which sank back")
	assert_eq(main.view.spikes.pooled(), 0, "into the pool")
	assert_eq(w.bosses.pillar_x.size(), 0, "and the sim's pillars are gone with them")
