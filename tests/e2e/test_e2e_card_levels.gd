extends GutTest
## v0.7.5 SM (owner N8): a card's level on the pick cards and the HUD's wand pips, through main.tscn and real input
## only. A Gun run's altar (E) shows a levelled card it offers (a wand card, or an ability card when the altar has no
## wand card) as "Lv 1"; Esc closes it; the dev panel (real clicks; TEST HELPER, as test_e2e_gun_pool.gd) grants that
## card; E opens the same altar again and the card now reads "Lv 1 → 2", with its wand pip (when it sits in the wand)
## saying 1; taking it (its number key, Enter) raises it to level 2 and the pip to 2.

const ABILITY_BASE := 1000
const STAT_BASE := 2000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"interact"]:
		Input.action_release(a)
	TranslationServer.set_locale("en")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): the dev panel's NextMod (or NextAbility) until card `code` is chosen, then its Grant.
func _grant(e: E2e, main: Main, code: int) -> void:
	var ability := code >= ABILITY_BASE
	var guard := 0
	while guard < 200:
		var chosen := (
			main.driver.debug.ability_choice + ABILITY_BASE
			if ability
			else main.driver.debug.mod_choice
		)
		if chosen == code:
			break
		await _click(e, main, "NextAbility" if ability else "NextMod")
		guard += 1
	await _click(e, main, "GrantAbility" if ability else "GrantMod")
	await e.frames(3)


func _levelled(reader: WorldReader, code: int) -> bool:
	return (
		bool(reader.card_info(code).get("wand", false))
		or (code >= ABILITY_BASE and code < STAT_BASE)
	)


func _held_level(reader: WorldReader, code: int) -> int:
	if code >= ABILITY_BASE:
		return int(reader.card_info(code)["level"]) - 1
	return PickPanel.held_level(reader, code)


func test_a_held_card_shows_its_level_up_on_the_pick_and_its_pip() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	var hud: Hud = main.get_node("UI/Hud")
	var panel := hud.pick_panel()
	var r := -1
	var offer := PackedInt32Array()
	var k := -1
	var tried := {}
	# The altars nearest first, until one offers a levelled card: a wand card first, else an ability card.
	for attempt in 4:
		r = -1
		for i in w.rewards.size():
			if w.rewards.kind[i] != RewardStore.Kind.ALTAR or tried.has(i) or Arenas.locked(w, i):
				continue
			var d := w.rewards.pos(i).distance_to(w.player_pos())
			if r < 0 or d < w.rewards.pos(r).distance_to(w.player_pos()):
				r = i
		if r < 0:
			break
		tried[r] = true
		assert_true(await e.walk_to(w.rewards.pos(r), w.reward_table.interact_radius_m * 0.6))
		await e.tap(KEY_E)
		await e.frames(3)
		assert_true(panel.is_open(), "E opens the altar")
		offer = w.rewards.offer_of(r)
		for i in offer.size():
			if bool(reader.card_info(offer[i]).get("wand", false)):
				k = i
				break
		for i in offer.size():
			if k < 0 and _levelled(reader, offer[i]):
				k = i
		if k >= 0:
			break
		await e.tap(KEY_ESCAPE)
		await e.frames(3)
	assert_gte(k, 0, "an altar offers a levelled card")
	if k < 0:
		return
	var card := offer[k]
	gut.p(
		"altar %d offers %s; card %d (%s)" % [r, Array(offer), card, reader.card_info(card)["id"]]
	)
	assert_eq(_held_level(reader, card), 0, "not held yet")
	assert_eq(panel.slot(k).card.level_text(), tr("UI_WAND_LEVEL") % 1, "not held: Lv 1")
	var card_rect := Rect2(Vector2.ZERO, panel.slot(k).card.size)
	assert_true(
		card_rect.grow(1.0).encloses(panel.slot(k).card.level_rect()), "the badge sits on the card"
	)
	await e.tap(KEY_ESCAPE)
	await e.frames(3)
	assert_false(panel.is_open(), "Esc closes the pick")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, card)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_eq(_held_level(reader, card), 1, "the dev panel granted it at level 1")
	var slot := Array(w.mod_slots).find(card)
	if slot >= 0:
		assert_eq(hud.build_hud.pip_level_text(slot), "1", "its wand pip shows its level")
	await e.tap(KEY_E)
	await e.frames(3)
	assert_true(panel.is_open(), "the same altar again")
	assert_eq(Array(w.rewards.offer_of(r)), Array(offer), "with the same cards")
	assert_eq(
		panel.slot(k).card.level_text(),
		tr("UI_CARD_LEVEL_UP") % [1, 2],
		"held at 1: taking it gives level 2"
	)
	await e.tap(KEY_1 + k)
	await e.tap(KEY_ENTER)
	await e.frames(4)
	assert_false(panel.is_open(), "taken")
	assert_eq(_held_level(reader, card), 2, "it levelled to 2")
	await e.frames(2)
	slot = Array(w.mod_slots).find(card)
	if slot >= 0:
		assert_eq(hud.build_hud.pip_level_text(slot), "2", "and its pip says 2")
	TranslationServer.set_locale("es")
	await e.frames(2)
	assert_eq(tr("UI_CARD_LEVEL_UP") % [1, 2], "Nv 1 → 2", "Spanish")


## The altars nearest first, until one offers a wand card; returns [reward, slot] or [-1, -1]. v0.8.0 N7 (owner
## O61): a chest deals its card on the open (no offer to look at), so only altars are tried.
## TEST HELPER (labelled): the altars' cards are drawn almost all as mods (an altar's first card stays its new
## ability), so the floor's two altars offer a wand card; the mix itself is tests/unit/sim/test_offers.gd.
func _find_wand_offer(e: E2e, w: World, reader: WorldReader, panel: PickPanel) -> Array:
	w.reward_table.altar_card_weights = PackedInt32Array([0, 1, 1000])
	var tried := {}
	for attempt in 8:
		var r := -1
		for i in w.rewards.size():
			var kind := w.rewards.kind[i]
			if kind != RewardStore.Kind.ALTAR or tried.has(i) or Arenas.locked(w, i):
				continue
			var d := w.rewards.pos(i).distance_to(w.player_pos())
			if r < 0 or d < w.rewards.pos(r).distance_to(w.player_pos()):
				r = i
		if r < 0:
			break
		tried[r] = true
		if not await e.walk_to(w.rewards.pos(r), w.reward_table.interact_radius_m * 0.6):
			continue
		await e.tap(KEY_E)
		await e.frames(3)
		if not panel.is_open():
			continue
		var offer := w.rewards.offer_of(r)
		for k in offer.size():
			if bool(reader.card_info(offer[k]).get("wand", false)):
				return [r, k]
		await e.tap(KEY_ESCAPE)
		await e.frames(3)
	return [-1, -1]


func test_a_held_wand_card_shows_lv_n_to_n_plus_1_and_its_pip() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	var hud: Hud = main.get_node("UI/Hud")
	var panel := hud.pick_panel()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")  # TEST HELPER: the walk between rewards must not end the run
	await e.tap(KEY_QUOTELEFT)
	# TEST HELPER (labelled, v0.9.5 CLV): every wand card has its default five levels here, so any altar offers a
	# levelled one; the badge format of 1-level and 3-level cards is test_card_level_views.gd's job.
	for t in w.item_tables:
		t.level_max = 0
	var found := await _find_wand_offer(e, w, reader, panel)
	var r: int = found[0]
	var k: int = found[1]
	assert_gte(r, 0, "an altar offers a wand card")
	if r < 0:
		return
	var card := w.rewards.offer_of(r)[k]
	gut.p(
		(
			"reward %d offers %s; wand card %s"
			% [r, Array(w.rewards.offer_of(r)), reader.card_info(card)["id"]]
		)
	)
	assert_eq(panel.slot(k).card.level_text(), tr("UI_WAND_LEVEL") % 1, "not held: Lv 1")
	var tier_before := panel.slot(k).card.tier_text()
	await e.tap(KEY_ESCAPE)
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, card)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var slot := Array(w.mod_slots).find(card)
	assert_gte(slot, 0, "the card is in the wand")
	assert_eq(hud.build_hud.pip_level_text(slot), "1", "its wand pip shows level 1")
	# back to the altar (the floor's enemies may have pushed the hero off while the dev panel was used)
	await e.walk_to(w.rewards.pos(r), w.reward_table.interact_radius_m * 0.6)
	await e.tap(KEY_E)
	await e.frames(3)
	assert_true(panel.is_open(), "the same reward again")
	assert_eq(panel.slot(k).card.level_text(), tr("UI_CARD_LEVEL_UP") % [1, 2], "Lv 1 → 2")
	assert_eq(panel.slot(k).card.tier_text(), tier_before, "the rarity line is unchanged")
	await e.tap(KEY_1 + k)
	await e.tap(KEY_ENTER)
	await e.frames(4)
	assert_eq(PickPanel.held_level(reader, card), 2, "taking it levelled the card")
	await e.frames(2)
	assert_eq(hud.build_hud.pip_level_text(Array(w.mod_slots).find(card)), "2", "its pip says 2")
