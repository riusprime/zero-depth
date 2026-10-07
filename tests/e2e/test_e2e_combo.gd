extends GutTest
## A named combo through real input (v0.3.0 G, L8; v0.3.0 E moved items onto altars and chests): on the first
## floor, walk (left stick only) to every altar and chest, open it with pad X and leave it with B, which keeps its
## three cards for later. Then go back to the two whose cards hold a combo pair and take those cards (d-pad, A).
## Taking the second item unlocks the combo: the combo card names it and the HUD gains its badge.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_pick_a_combo_pair_from_altars_and_chests() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(w.combo_tables.size(), 8, "the game loads the combos")
	# TEST HELPER (labelled): grant shards so the chests can be opened too. Earning shards by input is
	# test_e2e_rewards.gd; this test is about the combo.
	w.shards = 10000
	var offers := {}
	var left := Array(w.rewards.ids)
	while not left.is_empty() and not w.player_dead():
		var id: int = _nearest(w, left)
		left.erase(id)
		assert_true(await _open(e, id), "opened reward %d" % id)
		offers[id] = w.rewards.offer_of(w.rewards.index_of(id))
		await _press(e, JOY_BUTTON_B)
		assert_eq(w.choosing, -1, "B left it for later")
	var plan := _pair(w, offers)
	assert_false(plan.is_empty(), "the floor's cards hold a combo pair in two rewards")
	if plan.is_empty():
		return
	for step: Array in [[plan[1], plan[2]], [plan[3], plan[4]]]:
		assert_true(await _open(e, step[0]), "reopened reward %d" % step[0])
		assert_eq(w.rewards.offer_of(w.rewards.index_of(step[0])), offers[step[0]], "same cards")
		for k in step[1]:
			await _press(e, JOY_BUTTON_DPAD_RIGHT)
		await _press(e, JOY_BUTTON_A)
		assert_eq(w.choosing, -1, "took a card")
	assert_false(w.player_dead(), "survived the walks")
	var combo: int = plan[0]
	assert_true(w.combos_owned.has(combo), "owning both items unlocked the combo")
	await e.frames(2)
	var reader := main.driver.reader
	assert_true(hud.combo_card().is_showing(), "the combo card shows")
	assert_eq(hud.combo_card().title_text(), tr(reader.combo_name_key(combo)))
	assert_eq(hud.combo_card().desc_text(), tr(reader.combo_desc_key(combo)))
	assert_eq(hud.combo_card().pair_ids(), reader.combo_item_ids(combo), "with both items' icons")
	assert_eq(hud.combo_badge_count(), w.combos_owned.size(), "and a badge in the HUD")
	gut.p("combo %s from %d rewards" % [w.combo_tables[combo].id, offers.size()])


## Walks to reward `id` and opens it with pad X. True if the choice opened.
func _open(e: E2e, id: int) -> bool:
	var w := e.world()
	var at := w.rewards.pos(w.rewards.index_of(id))
	await e.walk_to(at, w.reward_table.interact_radius_m * 0.6)
	await _press(e, JOY_BUTTON_X)
	return w.choosing == id


func _press(e: E2e, b: JoyButton) -> void:
	e.joy_button(b, true)
	await e.frames(1)
	e.joy_button(b, false)
	await e.frames(2)


func _nearest(w: World, ids: Array) -> int:
	var best := -1
	var best_d := INF
	for id: int in ids:
		var d := w.rewards.pos(w.rewards.index_of(id)).distance_to(w.player_pos())
		if d < best_d:
			best = id
			best_d = d
	return best


## [combo, reward a, card a, reward b, card b] for the first combo whose two items sit in two different rewards'
## cards, or [].
func _pair(w: World, offers: Dictionary) -> Array:
	for c in w.combo_tables.size():
		var t := w.combo_tables[c]
		var a := _find(offers, t.item_a)
		var b := _find(offers, t.item_b)
		if not a.is_empty() and not b.is_empty() and a[0] != b[0]:
			return [c, a[0], a[1], b[0], b[1]]
	return []


func _find(offers: Dictionary, item: int) -> Array:
	for id: int in offers:
		var k: int = (offers[id] as PackedInt32Array).find(item)
		if k >= 0:
			return [id, k]
	return []
