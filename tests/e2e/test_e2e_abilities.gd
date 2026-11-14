extends GutTest
## The build system through real input (v0.4.0 BS, owner F8, F9, F11): start a run (slot 1 = the Blade's Combo
## Sword), walk (left stick only) to the nearest altar, open it with E: its first card is a new ability; take an
## ability with the keyboard (arrows, Enter); the HUD gains its slot. v0.10.5 O1: the six auto abilities are deleted,
## so the altar's ability card is Blink or Aegis. Then the dev panel grants Blink, and Shift blinks.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_pick_an_ability_card_at_an_altar_and_see_it_fire() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var reader := main.driver.reader
	assert_eq(reader.abilities().size(), 1, "slot 1 holds the weapon")
	assert_eq(reader.abilities()[0]["id"], &"combo_sword", "the Blade's Combo Sword")
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")  # the walk and the wait are about the ability, not survival (panel stays open)
	var altar := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	var altar_id := w.rewards.ids[altar]
	assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	var offer := w.rewards.offer_of(w.rewards.index_of(altar_id))
	assert_eq(Offers.type_of(offer[0]), Offers.ABILITY, "the first card is an ability")
	assert_eq(panel.slot(0).rarity_color(), PickSlot.ABILITY, "drawn as an ability card")
	assert_eq(
		panel.slot(0).card.title_text(), tr(w.ability_tables[Offers.ability_of(offer[0])].name_key)
	)
	# Take an auto ability: the first card if it is one, else the first auto ability among the cards; if the
	# altar offers none (a utility first card and two others), the first card and its button.
	var pick := 0
	for k in offer.size():
		if (
			Offers.type_of(offer[k]) == Offers.ABILITY
			and w.ability_tables[Offers.ability_of(offer[k])].auto
		):
			pick = k
			break
	for k in pick:
		await e.tap(KEY_RIGHT)
	assert_eq(panel.focus_index(), pick)
	await e.tap(KEY_ENTER)
	await e.frames(3)
	var idx := Offers.ability_of(offer[pick])
	var t := w.ability_tables[idx]
	assert_true(Abilities.owned(w, idx), "the ability is held")
	assert_eq(reader.abilities().size(), 2)
	assert_true(hud.ability_squares.visible, "the HUD shows its ability squares (v0.9.5 HU)")
	gut.p("took %s" % t.id)
	for c in offer:  # v0.6.5 WN5b: the six auto abilities are retired (WAND.md): never offered
		assert_false(
			Offers.type_of(c) == Offers.ABILITY and w.ability_tables[Offers.ability_of(c)].retired,
			"no retired ability card"
		)
	# v0.10.5 O1: the auto abilities are deleted; the only abilities left are the utilities (their use: test_e2e_utility)
	assert_true(t.is_utility(), "%s is Blink or Aegis" % t.id)


func test_blink_card_then_shift_blinks() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	while w.ability_tables[main.driver.debug.ability_choice].id != &"blink":
		await e.click_dev("NextAbility")  # (the dev panel's forced loadout)
	assert_eq(w.ability_tables[main.driver.debug.ability_choice].id, &"blink")
	await e.click_dev("GrantAbility")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(hud.ability_squares.shown().has(&"blink"), "Blink has its square")
	assert_ne(hud.ability_squares.slot_of(&"blink")["glyph"], "", "with its key")
	var start := w.player_pos()
	e.key(KEY_W, true)
	await e.frames(3)
	e.key(KEY_SHIFT, true)
	e.key(KEY_SHIFT, false)
	await e.frames(3)
	e.key(KEY_W, false)
	assert_gt(w.player_pos().distance_to(start), 2.5, "Shift blinked")
	assert_eq(w.ab.blink_charges, 0, "spending its charge")
	await e.frames(2)
	assert_true(
		hud.ability_squares.slot_of(&"blink")["cooling"], "the square's cooldown cover runs"
	)
