extends GutTest
## The economy through real input (v0.3.0 E): shooting enemies earns shards (gems fly to you and the HUD counter
## shows them); a chest you can't afford shows its price in red and stays shut; with enough shards, E opens it
## and the keyboard (3, Enter) buys the 3rd card.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"shoot"]:
		Input.action_release(a)


func test_kills_earn_shards() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.shard_text(), "0", "the counter starts at 0")
	var gems_seen := false
	var shooting := false
	for k in 3600:
		var target := _nearest_enemy(w)
		if target >= 0:
			# Aim the right stick at the nearest enemy (sim → screen, stick y down) and hold the right trigger.
			var d := (w.actors.pos(target) - w.player_pos()).normalized()
			var c := InputLatch.C45
			var screen := Vector2((d.x + d.y) * c, (d.y - d.x) * c)
			e.joy_axis(JOY_AXIS_RIGHT_X, screen.x)
			e.joy_axis(JOY_AXIS_RIGHT_Y, -screen.y)
			if not shooting:
				e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				shooting = true
		await e.frames(1)
		gems_seen = gems_seen or main.view.shards.count() > 0
		if (w.shards > 0 and gems_seen) or w.player_dead():
			break
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_Y, 0.0)
	assert_false(w.player_dead(), "survived")
	assert_gt(w.kills, 0, "shot something dead")
	assert_gt(w.shards, 0, "kills paid shards")
	assert_true(gems_seen, "shard gems flew from the kill")
	await e.frames(1)
	assert_eq(hud.shard_text(), str(w.shards), "the HUD counter shows them")
	gut.p("kills %d, shards %d after %d ticks" % [w.kills, w.shards, w.tick])


func test_a_chest_is_shut_until_you_can_pay_then_the_keyboard_buys_a_card() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var target_i := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	var chest_id := w.rewards.ids[target_i]
	var price := w.rewards.price[target_i]
	var reached: bool = await e.walk_to(
		w.rewards.pos(target_i), w.reward_table.interact_radius_m * 0.6
	)
	assert_true(reached, "walked up to the chest")
	assert_lt(w.shards, price, "not enough shards yet")
	await e.frames(2)
	assert_eq(hud.prompt_text(), tr("REWARD_TOO_POOR") % [w.shards, price])
	assert_true(hud.prompt_poor(), "the prompt is red")
	var label := main.view.rewards.price_label(chest_id)
	assert_true(label.visible, "the price floats above the chest")
	assert_eq(label.text, str(price))
	assert_eq(label.modulate, RewardViews.PRICE_POOR, "in red")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.choosing, -1, "E didn't open it")
	assert_false(hud.pick_panel().is_open())
	assert_eq(w.reward_denied_id, chest_id, "the refusal reached the sim")
	# TEST HELPER (labelled): grant the shards directly. Earning them by input is test_kills_earn_shards; this test
	# is about paying, and fighting for 80+ shards would make it slow and flaky.
	w.shards = price + 7
	await e.frames(2)
	assert_eq(label.modulate, RewardViews.PRICE_OK, "the price turns white once you can pay")
	assert_eq(hud.prompt_text(), tr("REWARD_OPEN_CHEST") % price)
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, chest_id, "E opened the chest")
	assert_true(panel.is_open())
	assert_eq(panel.title_text(), tr("PICK_TITLE_CHEST") % price, "the title shows the price")
	var offer := w.rewards.offer_of(w.rewards.index_of(chest_id))
	await e.tap(KEY_3)
	assert_eq(panel.focus_index(), 2, "3 focused the 3rd card")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(w.items_owned, PackedInt32Array([offer[2]]), "bought the 3rd card's item")
	assert_eq(w.shards, 7, "paid the price")
	assert_eq(w.rewards.index_of(chest_id), -1, "the chest is consumed")
	assert_eq(hud.shard_text(), "7")


func test_esc_leaves_the_choice_for_later() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var target_i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	var altar_id := w.rewards.ids[target_i]
	assert_true(await e.walk_to(w.rewards.pos(target_i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(hud.pick_panel().is_open())
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_false(hud.pick_panel().is_open(), "Esc closed the pick")
	assert_null(main.get_node_or_null("UI/PauseMenu"), "and didn't open the pause menu")
	assert_false(main.driver.paused)
	assert_eq(w.choosing, -1)
	assert_ne(w.rewards.index_of(altar_id), -1, "the altar is still there")
	assert_eq(w.items_owned.size(), 0)


func _nearest_enemy(w: World) -> int:
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		if (
			best < 0
			or (
				w.actors.pos(i).distance_to(w.player_pos())
				< w.actors.pos(best).distance_to(w.player_pos())
			)
		):
			best = i
	return best
