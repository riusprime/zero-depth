extends GutTest
## The shop through real input (v0.5.0 SH): start a run (God and Bomb Lobber from the dev panel, clicked with the
## mouse: the dev route, so the walk is safe and there is an ability to salvage), walk with the left stick to the
## floor's shop terminal (in a side room, on the minimap once seen), see the prompt, press E: the shop panel opens
## with four priced cards and the world waits. Buy a card with the keyboard (arrows, Enter): it applies as a picked
## card and its slot reads Sold. Move down to the salvage list and salvage Bomb Lobber with the pad (d-pad, A): 25
## shards per level back, the slot is free. B closes the shop and play resumes.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _pad(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


func test_walk_to_the_shop_buy_a_card_and_salvage_an_ability() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var layout := w.floor_layout
	assert_true(w.shop.present(), "the floor has a shop")
	assert_true(ShopPlacement.allowed(layout, w.shop.room), "in a side room")
	assert_not_null(main.view.shop_terminal, "the terminal is drawn")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	while w.ability_tables[main.driver.debug.ability_choice].id != &"bomb_lobber":
		await _click(e, main, "NextAbility")
	await _click(e, main, "GrantAbility")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	var bomb := Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER)
	assert_true(Abilities.owned(w, bomb), "Bomb Lobber in slot 2")
	assert_true(await e.walk_to(ShopPlacement.front(layout), 0.4), "walked to the terminal")
	await e.frames(2)
	assert_true(hud.minimap.state.is_discovered(w.shop.room), "its room is on the minimap")
	assert_eq(hud.shop.prompt_text(), tr("SHOP_PROMPT"), "the prompt by the terminal")
	assert_true(main.view.shop_terminal.hot(), "the terminal lights up in reach")
	# TEST HELPER (labelled): grant the shards directly. Earning them by input is test_e2e_rewards'
	# test_kills_earn_shards; this test is about spending them.
	w.shards = 400
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.shop.panel
	assert_true(w.shop.open, "E opened the shop")
	assert_true(panel.visible and panel.is_open(), "the panel shows")
	assert_eq(panel.title_text(), tr("SHOP_TITLE"))
	assert_eq(w.shop.offer.size(), 4, "four cards")
	var run := w.run_ticks
	await e.frames(20)
	assert_eq(w.run_ticks, run, "the world waits while shopping")
	# Buy the first card that can apply and that you can afford: arrows to it, Enter.
	var k := -1
	for i in w.shop.offer.size():
		if (
			k < 0
			and Shop.can_apply(w, w.shop.offer[i])
			and Shop.price(w, w.shop.offer[i]) <= w.shards
		):
			k = i
	assert_gte(k, 0, "a card to buy")
	var code := w.shop.offer[k]
	var cost := Shop.price(w, code)
	assert_eq(panel.card_price_text(k), str(cost), "the price under the card")
	for i in k:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.focus_index(), k)
	var seq := w.last_event_seq()
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(w.shards, 400 - cost, "paid its price")
	assert_eq(w.shop.offer[k], ShopState.SOLD, "sold out")
	assert_eq(panel.card_price_text(k), tr("SHOP_SOLD"), "the slot reads Sold")
	var picked := false
	for ev in w.events_since(seq):
		picked = picked or (ev.kind == SimEvent.Kind.PICKUP and ev.amount == code)
	assert_true(picked, "it applied as a picked card")
	gut.p("bought %s for %d" % [Offers.info(w, code)["id"], cost])
	# Salvage Bomb Lobber with the pad: down to the salvage list, along to it, A.
	await _pad(e, JOY_BUTTON_DPAD_DOWN)
	await _pad(e, JOY_BUTTON_DPAD_DOWN)
	var list := Shop.sell_list(w)
	var n := -1
	for i in list.size():
		if list[i][0] == Shop.SELL_ABILITY and w.ability_owned[list[i][1]] == bomb:
			n = i
	assert_gte(n, 0, "Bomb Lobber is in the salvage list")
	var target := panel.index_of_value(InputFrame.PICK_SHOP_SELL + n)
	assert_eq(int(panel.entry(panel.focus_index())["row"]), 2, "the focus is in the salvage list")
	while panel.focus_index() != target:
		await _pad(
			e, JOY_BUTTON_DPAD_RIGHT if panel.focus_index() < target else JOY_BUTTON_DPAD_LEFT
		)
	var before := w.shards
	var slots := w.ability_owned.size()
	var refund := list[n][3]
	assert_eq(refund, 10 * Abilities.level_of(w, bomb), "10 shards per level")
	await _pad(e, JOY_BUTTON_A)
	await e.frames(2)
	assert_false(Abilities.owned(w, bomb), "Bomb Lobber salvaged")
	assert_eq(w.shards, before + refund, "its refund paid")
	assert_eq(w.ability_owned.size(), slots - 1, "its slot is free")
	await _pad(e, JOY_BUTTON_B)
	await e.frames(2)
	assert_false(w.shop.open, "B closed the shop")
	assert_false(panel.visible)
	await e.frames(10)
	assert_gt(w.run_ticks, run, "play resumes")
