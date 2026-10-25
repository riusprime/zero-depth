extends GutTest
## v0.9.0 AS (owner Q2 "Keep it, add limits", Q5 "Marked, old one burns", Q14 "Short line + slot tag"; PLAN C39, C40,
## C67, C87) through the real game (main.tscn, input by Input.parse_input_event only): a Gun run holding Twin walks
## to an altar and opens it with E; the altar's Halo card reads "Pattern" and "Replaces Twin" under it; Enter takes it:
## Halo takes Twin's slot, Twin leaves the build and its chip burns on the card's slot line while the pick flies to the
## HUD. A Secondary with room says only its tag. v0.9.0 AS2: a third Secondary opens the Swap to choose which goes.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func test_a_second_pattern_at_an_altar_replaces_the_first_which_burns() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(w.slot_table, "the run has the slot rules (data/wand/attack_slots.tres)")
	var twin := _item(w, &"gun_twin")
	var halo := _item(w, &"halo_shot")
	var pierce := _item(w, &"gun_pierce")
	# TEST HELPER (labelled): the run already holds Twin (taking it at an altar is test_e2e_reward_cards' job), and the
	# altar's offer is forced so its first card is Halo (the roll is test_loot_rewards' job).
	assert_true(BuildSlots.take(w, twin))
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	var id := w.rewards.ids[i]
	w.rewards.set_offer(i, PackedInt32Array([halo, pierce, _item(w, &"ember_core")]))
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, id, "E opened the altar")
	assert_true(panel.is_open())
	for k in 240:  # the deal plays out by itself
		if panel.deal.done():
			break
		await e.frames(1)
	var card := panel.slot(0)
	assert_eq(card.slot_text(), tr("UI_SLOT_PATTERN"), "Halo wears its slot tag")
	assert_eq(
		card.replaces_text(),
		tr("UI_SLOT_REPLACES") % tr("ITEM_GUN_TWIN"),
		"and says it replaces Twin"
	)
	assert_eq(panel.slot(1).slot_text(), tr("UI_SLOT_SECONDARY"), "Pierce: Secondary")
	assert_eq(panel.slot(1).replaces_text(), "", "with room: it replaces nothing")
	assert_eq(panel.slot(2).slot_text(), tr("UI_SLOT_ELEMENT"))
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_eq(w.choosing, -1, "Enter took Halo")
	assert_true(w.items_owned.has(halo), "Halo is held")
	assert_false(w.items_owned.has(twin), "Twin left the build")
	assert_eq(Array(w.mod_slots), [halo], "in Twin's slot")
	assert_true(panel.outro_playing())
	await e.frames(10)
	assert_true(card.replaced_burning(), "Twin's chip burns")
	assert_true(panel.slot(1).card.fx.burning(), "the cards not picked burn as before")
	await e.frames(60)
	assert_false(panel.outro_playing())
	assert_false(card.replaced_burning(), "and the card is whole for the next choice")
	assert_eq(
		int(main.driver.reader.wand()["cards"][0]["slot"]),
		WorldReader.SLOT_PATTERN,
		"the wand reads its tag"
	)


## v0.9.0 AS2 (owner "Let me choose"; G2 AS = B): with two Secondaries held, the altar's third reads "Choose one to
## replace" on its ribbon; Enter opens the Swap panel limited to the two; Esc keeps the card un-taken (back to the
## cards); taken again, → and Enter choose Homing: it leaves and Ricochet takes its slot.
func test_a_third_secondary_opens_the_swap_to_choose_which_goes() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var pierce := _item(w, &"gun_pierce")
	var homing := _item(w, &"gun_homing")
	var ric := _item(w, &"gun_ricochet")
	# TEST HELPER (labelled): the run already holds Pierce and Homing, and the altar's first card is Ricochet.
	assert_true(BuildSlots.take(w, pierce))
	assert_true(BuildSlots.take(w, homing))
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	var id := w.rewards.ids[i]
	w.rewards.set_offer(i, PackedInt32Array([ric, _item(w, &"ember_core"), _item(w, &"gun_twin")]))
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_eq(w.choosing, id, "E opened the altar")
	for k in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	assert_eq(panel.slot(0).slot_text(), tr("UI_SLOT_SECONDARY"))
	assert_eq(
		panel.slot(0).replaces_text(), tr("UI_SLOT_CHOOSE"), "the ribbon: choose one to replace"
	)
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_true(BuildSlots.swapping(w), "the Swap opens")
	assert_true(hud.swap.visible)
	assert_eq(
		hud.swap.choices(), [0, 1] as Array[int], "it shows the two Secondaries to choose from"
	)
	await e.tap(KEY_ESCAPE)
	await e.frames(3)
	assert_false(BuildSlots.swapping(w), "Esc skips")
	assert_eq(w.choosing, id, "back to the cards")
	assert_false(w.items_owned.has(ric), "the card stays un-taken")
	assert_eq(Array(w.mod_slots), [pierce, homing])
	await e.frames(10)
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_true(hud.swap.visible, "the Swap again")
	await e.tap(KEY_RIGHT)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_false(BuildSlots.swapping(w))
	assert_eq(w.choosing, -1, "taken: the altar closes")
	assert_true(w.items_owned.has(ric), "Ricochet is held")
	assert_false(w.items_owned.has(homing), "Homing, the one chosen, left the build")
	assert_eq(Array(w.mod_slots), [pierce, ric], "in Homing's slot")
