extends GutTest
## The gamble shrine through real input (v0.3.0 L19; v0.8.0 N14, owner O72: rarer, 3 wins, 30 % to fail). Run seed 2
## (E2e.boot's fixed seed) draws a shrine on floor 1, in a combat room next to the start hall (never the start hall).
## God from the dev panel (clicked with the mouse: the dev route, so the walk is safe), then walking up to the shrine
## with the stick shows its price above it and the prompt (red with no shards, and E then pays nothing; v0.8.0 N18,
## owner O76: no odds line under it); with shards, E on the keyboard pays 25 and wins a stat (the card spins and lands
## on it); X on the pad pays 38 and fails (the shrine fizzles, "It failed", no stat, the price still rises to 57);
## after the 3rd win the shrine is spent: dimmed, "Spent" above it, the prompt says so, and E pays nothing.

## Run seed 2's floor-1 shrine: uses 1 and 2 fail, 0, 3 and 4 win (Gamble.fails on its floor seed).
const SEED := 2


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)
	TranslationServer.set_locale("en")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _pad_x(e: E2e) -> void:
	e.joy_button(JOY_BUTTON_X, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_X, false)
	await e.frames(2)


func _total(w: World) -> int:
	var total := 0
	for s in GambleTable.STAT_COUNT:
		total += Gamble.stacks(w, s)
	return total


func test_find_the_shrine_win_fail_and_spend_it_with_keyboard_and_pad() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var layout := w.floor_layout
	assert_ne(w.gamble_id, -1, "this floor has a shrine")
	var room := layout.room_of(w.gamble_pos)
	assert_ne(room, layout.start_room, "not in the start hall")
	assert_ne(room, layout.boss_room, "nor the boss room")
	assert_false(layout.arena_rooms.has(room), "nor an arena")
	var fails := []
	for k in 5:
		fails.append(Gamble.fails(w, k))
	assert_eq(fails, [false, true, true, false, false], "the seed's rolls this test walks through")
	var shrine := main.view.gamble_shrine
	assert_not_null(shrine, "the shrine is drawn")
	assert_eq(shrine.root.position, SimPlane.to_3d(w.gamble_pos), "at the sim's shrine position")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var front := Gamble.front(w.gamble_pos, layout.door_approaches(room, 1.0)[0])
	assert_true(await e.walk_to(front, 0.35), "walked up to the shrine")
	await e.frames(2)
	assert_eq(w.shards, 0, "no shards yet")
	assert_true(shrine.price_label.visible, "the price floats above it")
	assert_eq(shrine.price_label.text, "25")
	assert_eq(shrine.price_label.modulate, GambleShrineView.PRICE_POOR, "red: can't afford it")
	assert_eq(hud.gamble.prompt_text(), tr("REWARD_TOO_POOR") % [0, 25])
	assert_null(hud.gamble.find_child("GambleOdds", true, false), "v0.8.0 N18: no odds line")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.gamble_uses, 0, "E paid nothing")
	assert_gt(w.gamble_denied_tick, -1, "the refusal reached the sim")
	assert_true(shrine.shaking(), "the shrine shakes")
	# TEST HELPER (labelled): grant the shards directly. Earning them by input is test_e2e_rewards'
	# test_kills_earn_shards; this test is about spending them, and fighting for 300+ shards would be slow and flaky.
	w.shards = 1000
	await e.frames(2)
	assert_eq(shrine.price_label.modulate, GambleShrineView.PRICE_OK, "white once you can pay")
	assert_eq(hud.gamble.prompt_text(), tr("UI_GAMBLE_USE") % 25)
	# Use 1: the keyboard pays 25 and wins.
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.shards, 975, "the keyboard paid 25")
	assert_eq([w.gamble_uses, w.gamble_wins], [1, 1])
	var first := w.gamble_last_stat
	assert_eq(Gamble.stacks(w, first), 1, "and won a stat")
	assert_true(hud.gamble.card.showing(), "the result card shows")
	assert_true(shrine.spinning(), "the core spins with it")
	await e.frames(int(GambleCard.SPIN_S * 60.0) + 6)
	assert_eq(shrine.price_label.text, "38", "the next use costs more")
	# Use 2: the pad's X pays 38 and fails.
	await _pad_x(e)
	assert_eq(w.shards, 937, "the pad's X paid 38")
	assert_eq([w.gamble_uses, w.gamble_wins], [2, 1], "a try, no win")
	assert_eq(_total(w), 1, "no stat")
	assert_gt(w.gamble_fail_tick, -1, "the failure reached the sim")
	assert_true(shrine.fizzling(), "the shrine cracks and fizzles")
	assert_eq(hud.gamble.fail_text(), tr("UI_GAMBLE_FAILED"))
	assert_eq(hud.gamble.fail_text(), "It failed")
	assert_eq(shrine.price_label.text, "57", "the price still rises after a miss")
	# Use 3 fails, uses 4 and 5 win: the third win spends the shrine.
	for k in 3:
		await e.tap(KEY_E)
		await e.frames(int(GambleCard.SPIN_S * 60.0) + 6)
	assert_eq([w.gamble_uses, w.gamble_wins], [5, 3], "five tries, three wins")
	assert_eq(w.shards, 1000 - 25 - 38 - 57 - 86 - 129, "every try was paid")
	assert_eq(_total(w), 3, "three stats")
	assert_true(Gamble.spent(w), "spent")
	assert_true(shrine.dimmed(), "drawn dim")
	assert_eq(shrine.price_label.text, tr("UI_GAMBLE_SPENT_TAG"), "'Spent' above it")
	assert_eq(shrine.price_label.modulate, GambleShrineView.PRICE_SPENT)
	assert_eq(hud.gamble.prompt_text(), tr("UI_GAMBLE_BLOCKED"), "the prompt says so")
	assert_eq(hud.gamble.prompt_text(), "Spent")
	var shards := w.shards
	var denied := w.gamble_denied_tick
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.shards, shards, "a spent shrine takes nothing")
	assert_eq(w.gamble_uses, 5)
	assert_gt(w.gamble_denied_tick, denied, "and refuses")
	TranslationServer.set_locale("es")
	await e.frames(2)
	assert_eq(shrine.price_label.text, "Agotado", "Spanish")
	assert_eq(hud.gamble.prompt_text(), "Agotado")
	TranslationServer.set_locale("en")
	await e.frames(2)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	var pause := main.get_node_or_null("UI/PauseMenu")
	assert_not_null(pause, "paused")
	var panel: GambleStatsPanel = pause.get_node_or_null("GambleStats")
	assert_not_null(panel, "the pause menu lists the shrine's stats")
	assert_gt(panel.row_count(), 0)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
