extends GutTest
## v0.8.0 AO (owner O37: "make the order of the attacks be more important"; docs/roadmap/v0.8.0/evidence/
## ATTACK_ORDER.md): a Gun run takes Ring and Swirl and their order changes the attack in play, through main.tscn and
## real input only. The dev panel (real clicks; TEST HELPER, as test_e2e_gun_pool.gd) grants them in that order:
## Ring · Swirl throws the ring off its own random way; holding Shoot lays it and AttackFormView strikes lightning to
## it. The Build page shows each card's slot, order mark and slot tag; moving Swirl from slot 2 to slot 1 (the
## keyboard: 2, Enter, ←, Enter) makes Swirl · Ring, one ring flying the aim and wobbling round its line, once the move
## reaches the sim. v0.8.0 N3 (owner O47): the ring is the shot itself and flies. v0.9.0 AS (owner Q3: "Ring + Swirl
## allowed; the old Ring · Spread · Swirl storm goes"): Ring is a Pattern, Swirl a Secondary riding on it; granting
## Halo (a Pattern too) replaces the Ring, so no wand holds the storm.


func after_each() -> void:
	Input.action_release(&"shoot")
	Input.action_release(&"pause")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## TEST HELPER (labelled): the dev panel's NextMod until card `id` is chosen, then GrantMod.
func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	var guard := 0
	while (
		(main.driver.debug.mod_choice < 0 or w.item_tables[main.driver.debug.mod_choice].id != id)
		and guard < 160
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


## Holds Shoot (the right mouse button) for `n` frames; returns the most rings alive at once, how far apart the live
## rings were at most, and how far from the hero a ring flew at most (v0.8.0 N3: the rings travel).
func _shoot(e: E2e, n: int) -> Array:
	var w := e.world()
	var most := 0
	var spread := 0.0
	var flew := 0.0
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in n:
		await e.frames(1)
		most = maxi(most, w.ab.ring_pos.size())
		var at := []
		for j in w.ab.ring_pos.size():
			at.append(ModifierAbilities.ring_centre(w, j, w.tick))
			flew = maxf(flew, (at[j] as Vector2).distance_to(w.player_pos()))
		for a: Vector2 in at:
			for b: Vector2 in at:
				spread = maxf(spread, a.distance_to(b))
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(2)
	return [most, spread, flew]


func test_ring_swirl_throws_the_ring_and_moving_swirl_first_flies_it_along_the_aim() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var reader: WorldReader = main.driver.reader
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	for id: StringName in [&"gun_ring", &"gun_swirl"]:
		await _grant(e, main, id)
	var ids := []
	for c in w.mod_slots:
		ids.append(w.item_tables[c].id)
	assert_eq(ids, [&"gun_ring", &"gun_swirl"], "picked in this order")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	var spec: Dictionary = reader.attack_spec(WorldReader.ATTACK_BOLT)
	assert_eq(int(spec["form"]), AttackSpec.Form.RING, "the shot is a ring")
	assert_eq([int(spec["count"]), int(spec["swirl"]), int(spec["swirl_group"])], [1, 1, 0])
	var forms: AttackFormView = (main.view as WorldViewRoot).attack_forms
	var arcs := forms.ring_arcs_drawn
	var thrown: Array = await _shoot(e, 40)
	assert_gte(int(thrown[0]), 1, "the rings are in play (%d at most)" % thrown[0])
	assert_gt(float(thrown[2]), 3.0, "they fly out (%.1f m)" % thrown[2])
	assert_gt(forms.ring_arcs_drawn, arcs, "lightning strikes to the thrown rings")
	# The Build page: each card's slot, order mark and slot tag; Swirl moves from slot 2 to slot 1.
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var page := main.get_node_or_null("UI/BuildPage") as BuildPage
	assert_not_null(page, "the Build page opens")
	if page == null:
		return
	var texts := _tile_texts(page.row)
	assert_true(texts.has("1 · %s" % tr("UI_WAND_ORDER_SHAPE")), "Ring: %s" % str(texts))
	assert_true(texts.has("2 · %s" % tr("UI_WAND_ORDER_MOTION")), "Swirl")
	assert_true(
		texts.has("%s · %s" % [tr("UI_WAND_LEVEL") % 1, tr("UI_SLOT_PATTERN")]), "Ring's slot tag"
	)
	assert_true(
		texts.has("%s · %s" % [tr("UI_WAND_LEVEL") % 1, tr("UI_SLOT_SECONDARY")]), "Swirl's"
	)
	assert_string_contains(page.note_text(), "%s 1/1" % tr("UI_SLOT_PATTERN"), "the slot counts")
	await e.tap(KEY_2)
	for key: Key in [KEY_ENTER, KEY_LEFT, KEY_ENTER]:  # slot 2 → 1
		await e.tap(key)
	await e.tap(KEY_ESCAPE)  # nothing held: back to the pause menu
	await e.frames(1)
	await e.tap(KEY_ESCAPE)  # resume
	await e.frames(12)
	assert_null(main.get_node_or_null("UI/PauseMenu"), "the run goes on")
	ids.clear()
	for c in w.mod_slots:
		ids.append(w.item_tables[c].id)
	assert_eq(ids, [&"gun_swirl", &"gun_ring"], "the move reached the sim")
	spec = reader.attack_spec(WorldReader.ATTACK_BOLT)
	assert_eq([int(spec["count"]), int(spec["swirl"]), int(spec["swirl_group"])], [1, 0, 1])
	await e.frames(40)  # the thrown rings end
	var start := w.tick
	var along: Array = await _shoot(e, 12)
	assert_gte(int(along[0]), 1, "a ring")
	assert_gt(float(along[2]), 1.5, "flying the aim")
	var by_start := {}
	for k in w.ab.ring_start.size():
		var t := w.ab.ring_start[k]
		if t >= start:
			by_start[t] = int(by_start.get(t, 0)) + 1
	for n: int in by_start.values():
		assert_eq(n, 1, "one ring a shot: %s" % str(by_start))
	# v0.9.0 AS: Halo is a Pattern too: taking it replaces the Ring, so the old storm can't be built.
	await e.tap(KEY_QUOTELEFT)
	await _grant(e, main, &"halo_shot")
	await e.tap(KEY_QUOTELEFT)
	ids.clear()
	for c in w.mod_slots:
		ids.append(w.item_tables[c].id)
	assert_eq(ids, [&"gun_swirl", &"halo_shot"], "Halo took the Ring's slot")
	spec = reader.attack_spec(WorldReader.ATTACK_BOLT)
	assert_eq(int(spec["form"]), AttackSpec.Form.BOLT, "no ring left")
	assert_false(w.player_dead())


## Every label text on the wand row's tiles.
func _tile_texts(row: WandRow) -> PackedStringArray:
	var out := PackedStringArray()
	for k in row.slot_count():
		for n in row.tile(k).find_children("*", "Label", true, false):
			out.append((n as Label).text)
	return out
