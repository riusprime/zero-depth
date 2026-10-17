extends GutTest
## v0.8.0 N7 + N8 (owner O61, O62; D48) through the real game (main.tscn, input by Input.parse_input_event only):
## 1. walk (keys) to an altar and open it with E: three cards arrive face down from the bottom and flip one by one;
##    Enter takes the focused card: it is applied, its icon flies to its HUD slot and the two others burn;
## 2. walk to a chest and open it with E: one card is dealt (no choice) and its flip runs; a press during the deal ends
##    the deal and takes the card; the icon flies to the HUD.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_an_altar_deals_three_cards_and_the_pick_flies_to_the_hud() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var reader: WorldReader = main.driver.reader
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	var id := w.rewards.ids[i]
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, id, "E opened the altar")
	assert_true(panel.is_open())
	var n := panel.card_count()
	assert_eq(n, 3, "three cards")
	assert_false(panel.deal.done(), "dealing")
	assert_false(panel.slot(0).card.fx.face.visible, "face down at first")
	assert_gt(panel.slot(0).card.fx.offset.y, 100.0, "coming up from below the screen")
	var order := []
	for k in 240:
		await e.frames(1)
		for s in n:
			if panel.slot(s).card.fx.face.visible and not order.has(s):
				order.append(s)
		if panel.deal.done():
			break
	assert_true(panel.deal.done(), "the deal ends by itself")
	var tiers := []
	for s in n:
		tiers.append(panel.slot(s).tier)
	assert_eq(order, Array(CardDeal.order(tiers)), "flipped one by one, Epic and Legendary last")
	var offer := w.rewards.offer_of(w.rewards.index_of(id))
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_eq(w.choosing, -1, "Enter took the focused card")
	assert_true(_took(w, offer[0]), "the card is applied")
	assert_true(panel.outro_playing(), "the outro plays")
	assert_eq(hud.flights.flying(), 1, "its icon flies")
	var fly := hud.flights.get_child(0) as CardFly
	assert_eq(fly.to, hud.flights.slot_rect_for(reader, offer[0]), "to the HUD slot it landed in")
	assert_eq(fly.id, reader.card_info(offer[0])["id"])
	await e.frames(12)
	assert_true(panel.slot(1).card.fx.burning(), "the cards not picked burn")
	assert_true(panel.slot(2).card.fx.burning())
	await e.frames(60)
	assert_false(panel.outro_playing(), "and are gone")
	assert_false(panel.visible)


func test_a_chest_deals_one_card_and_a_press_takes_it() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	assert_gte(i, 0, "a chest on the floor")
	var id := w.rewards.ids[i]
	var price := w.rewards.price[i]
	# TEST HELPER (labelled): grant the shards directly; earning them is test_e2e_rewards' job.
	w.shards = price + 3
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, id, "E opened the chest")
	var offer := w.rewards.offer_of(w.rewards.index_of(id))
	assert_eq(offer.size(), 1, "one card")
	assert_eq(w.shards, price + 3, "nothing paid while it shows")
	assert_eq(panel.card_count(), 1)
	assert_eq(panel.title_text(), tr("PICK_TITLE_CHEST_DEALT"))
	assert_false(panel.deal.done(), "its deal runs")
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_true(panel.deal.skipped(), "the press ended the deal")
	assert_eq(w.choosing, -1, "and took the card at once")
	assert_true(_took(w, offer[0]), "no choice: the chest's card")
	assert_eq(w.rewards.index_of(id), -1, "the chest is gone")
	assert_eq(w.shards, 3, "paid")
	assert_eq(hud.flights.flying(), 1, "its icon flies to the HUD")
	assert_false(panel.slot(0).card.fx.burning(), "nothing burns at a chest")


## Card `code` (Offers) was applied to the world (the run starts with the weapon only).
static func _took(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return w.items_owned.has(code)
		Offers.ABILITY:
			return Abilities.owned(w, Offers.ability_of(code))
	return Stats.value(w, Offers.stat_of(code)) != Stats.BASE[Offers.stat_of(code)]
