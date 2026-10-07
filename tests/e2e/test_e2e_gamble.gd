extends GutTest
## The gamble shrine through real input (v0.3.0 L19): the shrine stands in the start hall; walking up to it with
## the stick shows its price above it and the prompt (red with no shards, and E then pays nothing); with shards, E
## on the keyboard pays 25 and grants a stat (the card spins and lands on it, the stats panel lists it, the price
## steps up to 38), and X on the pad pays 38 for another.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_walk_to_the_shrine_and_gamble_with_keyboard_and_pad() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_ne(w.gamble_id, -1, "the floor has a shrine")
	assert_eq(w.floor_layout.room_of(w.gamble_pos), w.floor_layout.start_room, "in the start hall")
	var shrine := main.view.gamble_shrine
	assert_not_null(shrine, "the shrine is drawn")
	assert_true(await e.walk_to(_front(w), 0.35), "walked to the shrine")
	await e.frames(2)
	assert_eq(w.shards, 0, "no shards yet")
	assert_true(shrine.price_label.visible, "the price floats above it")
	assert_eq(shrine.price_label.text, "25")
	assert_eq(shrine.price_label.modulate, GambleShrineView.PRICE_POOR, "red: can't afford it")
	assert_eq(hud.gamble.prompt_text(), tr("REWARD_TOO_POOR") % [0, 25])
	assert_true(hud.gamble.prompt_poor())
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.gamble_uses, 0, "E paid nothing")
	assert_gt(w.gamble_denied_tick, -1, "the refusal reached the sim")
	assert_true(shrine.shaking(), "the shrine shakes")
	# TEST HELPER (labelled): grant the shards directly. Earning them by input is test_e2e_rewards'
	# test_kills_earn_shards; this test is about spending them, and fighting for 60+ shards would be slow and flaky.
	w.shards = 100
	await e.frames(2)
	assert_eq(shrine.price_label.modulate, GambleShrineView.PRICE_OK, "white once you can pay")
	assert_eq(hud.gamble.prompt_text(), tr("UI_GAMBLE_USE") % 25)
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.shards, 75, "the keyboard paid 25")
	assert_eq(w.gamble_uses, 1)
	var first := w.gamble_last_stat
	assert_eq(Gamble.stacks(w, first), 1, "and won a stat")
	var card := hud.gamble.card
	assert_true(card.showing(), "the result card shows")
	assert_true(card.spinning(), "spinning first")
	assert_true(shrine.spinning(), "the core spins with it")
	await e.frames(int(GambleCard.SPIN_S * 60.0) + 6)
	var id := GambleTable.STAT_IDS[first]
	assert_eq(card.shown_stat(), id, "it lands on the stat won")
	assert_eq(card.line_text(), GambleIcons.line(card, id, w.gamble_table.amount[first]))
	assert_eq(shrine.price_label.text, "38", "the next use costs more")
	assert_true(hud.gamble.stats.visible, "the stats panel shows at the shrine")
	assert_eq(hud.gamble.stats.row_count(), 1)
	assert_eq(hud.gamble.prompt_text(), tr("UI_GAMBLE_USE") % 38)
	e.joy_button(JOY_BUTTON_X, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_X, false)
	await e.frames(2)
	assert_eq(w.shards, 37, "the pad's X paid 38")
	assert_eq(w.gamble_uses, 2)
	var total := 0
	for s in GambleTable.STAT_COUNT:
		total += Gamble.stacks(w, s)
	assert_eq(total, 2, "two stats won")
	gut.p("won %s then %s" % [id, GambleTable.STAT_IDS[w.gamble_last_stat]])
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	var pause := main.get_node_or_null("UI/PauseMenu")
	assert_not_null(pause, "paused")
	var panel: GambleStatsPanel = pause.get_node_or_null("GambleStats")
	assert_not_null(panel, "the pause menu lists the shrine's stats")
	assert_gt(panel.row_count(), 0)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)


## A spot just in front of the shrine (toward the start point): the shrine itself is solid.
func _front(w: World) -> Vector2:
	var to_start := w.floor_layout.start_pos - w.gamble_pos
	return w.gamble_pos + to_start.normalized() * 1.2
