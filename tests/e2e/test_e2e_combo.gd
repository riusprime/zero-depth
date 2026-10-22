extends GutTest
## A named combo through real input (v0.3.0 G, L8; v0.3.0 E moved items onto altars and chests): on the first
## floor, walk (left stick only) to every altar and chest, open it with pad X and leave it with B, which keeps an
## altar's three cards for later. v0.8.0 N7 (owner O61): a chest deals its one card and any answer, B too, takes it.
## Then go back to the altars whose cards complete a combo pair and take those cards (d-pad, A).
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
	assert_eq(w.combo_tables.size(), 16, "the game loads the combos (8 item, 8 ability: v0.4.0 AB)")
	# TEST HELPER (labelled): grant shards so the chests can be opened too. Earning shards by input is
	# test_e2e_rewards.gd; this test is about the combo.
	w.shards = 10000
	# TEST HELPER (labelled): v0.4.0 BS made the items rarer mods among ability and stat cards, so a floor rarely
	# offers a whole combo pair now; this test is about the combo, so the floor's cards are drawn almost all as mods
	# (stat cards only once the mods run out; an altar's first card stays its new ability). The mix itself is
	# tests/unit/sim/test_offers.gd.
	w.reward_table.altar_card_weights = PackedInt32Array([0, 1, 1000])
	w.reward_table.chest_card_weights = PackedInt32Array([0, 1, 1000])
	var offers := {}
	# TEST HELPER (labelled): v0.5.5 AR locks the rewards in sealed arenas until their waves are cleared (that is
	# tests/e2e/test_e2e_arenas.gd); this test is about the cards, so the floor's arenas start cleared.
	w.arenas.cleared = w.floor_layout.arena_rooms.duplicate()
	if Overrun.enabled(w):
		w.arenas.cleared.append(w.floor_layout.overrun_room)
	# TEST HELPER (labelled): with the arenas' rewards placed first (v0.5.5 AR) this floor's few mod cards no longer
	# happen to hold a pair; the items that belong to no combo are held already, so the cards draw from combo items.
	var paired := PackedInt32Array()
	for t in w.combo_tables:
		paired.append_array([t.item_a, t.item_b])
	var held := PackedInt32Array()
	for k in w.item_tables.size():
		if not paired.has(k):
			held.append(k)
	w.set_items_owned(held)
	# v0.6.5 WN3–WN5a: a held wand card below level 5 is still offered (its level-up); held at level 5 it leaves too.
	for k in held:
		CardLevels.set_level(w, k, CardLevels.MAX_LEVEL)
	var left := Array(w.rewards.ids)
	var taken := PackedInt32Array()  # v0.8.0 N7: the cards the chests dealt (B took them)
	while not left.is_empty() and not w.player_dead():
		var id: int = _nearest(w, left)
		left.erase(id)
		assert_true(await _open(e, id), "opened reward %d" % id)
		var offer := w.rewards.offer_of(w.rewards.index_of(id))
		await _press(e, JOY_BUTTON_B)
		if w.rewards.index_of(id) < 0:
			taken.append_array(offer)  # a chest's card: B took it
		else:
			offers[id] = offer  # an altar's cards, or a chest's card that needs the swap (B left it)
		assert_eq(w.choosing, -1, "B left it for later (or took the chest's card)")
	var plan := _pair(w, offers, taken)
	assert_false(plan.is_empty(), "the floor's cards hold a combo pair")
	if plan.is_empty():
		return
	var steps := []
	for at in [1, 3]:
		if int(plan[at]) >= 0:
			steps.append([plan[at], plan[at + 1]])
	for step: Array in steps:
		assert_true(await _open(e, step[0]), "reopened reward %d" % step[0])
		assert_eq(w.rewards.offer_of(w.rewards.index_of(step[0])), offers[step[0]], "same cards")
		for k in step[1]:
			await _press(e, JOY_BUTTON_DPAD_RIGHT)
		await _press(e, JOY_BUTTON_A)
		if BuildSlots.swapping(w):  # v0.6.0 MX2: the held items fill the six slots: swap out one not of the pair
			await e.frames(2)
			var t: ComboTable = w.combo_tables[plan[0]]
			var slot := 0
			while w.mod_slots[slot] == t.item_a or w.mod_slots[slot] == t.item_b:
				slot += 1
			for n in slot:
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
## cards, or (v0.8.0 N7) one of them already taken from a chest (its reward -1), or [].
func _pair(w: World, offers: Dictionary, taken: PackedInt32Array) -> Array:
	for c in w.combo_tables.size():
		var t := w.combo_tables[c]
		if taken.has(t.item_a) and taken.has(t.item_b):
			return [c, -1, 0, -1, 0]
		var a := [-1, 0] if taken.has(t.item_a) else _find(offers, t.item_a)
		var b := [-1, 0] if taken.has(t.item_b) else _find(offers, t.item_b)
		if not a.is_empty() and not b.is_empty() and (a[0] != b[0] or a[0] == -1):
			return [c, a[0], a[1], b[0], b[1]]
	return []


func _find(offers: Dictionary, item: int) -> Array:
	for id: int in offers:
		var k: int = (offers[id] as PackedInt32Array).find(item)
		if k >= 0:
			return [id, k]
	return []
