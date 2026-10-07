extends GutTest
## The compact item card, its icons and the pedestal preview (PLAN v0.2.0 L13).

const NEW_IDS := [
	&"vampiric_core",
	&"static_chain",
	&"momentum",
	&"frost_core",
	&"thorn_mantle",
	&"executioner",
	&"swift_feet",
	&"phase_strike",
]


func test_there_are_sixteen_icons_and_every_one_draws_a_symbol() -> void:
	assert_eq(ItemIcons.IDS.size(), 16)
	var gem := str(ItemIcons.gem())
	var seen := {}
	for id in ItemIcons.IDS:
		var shapes := ItemIcons.shapes(id)
		assert_gt(shapes.size(), 0, "%s has shapes" % id)
		assert_ne(str(shapes), gem, "%s has its own symbol, not the gem" % id)
		seen[str(shapes)] = id
		for s: Dictionary in shapes:
			match s["t"]:
				"line", "loop":
					assert_gt((s["pts"] as PackedVector2Array).size(), 1, "%s line" % id)
				"poly":
					assert_gt((s["pts"] as PackedVector2Array).size(), 2, "%s polygon" % id)
				"circle":
					assert_gt(s["r"], 0.0, "%s circle" % id)
				_:
					fail_test("%s: unknown shape %s" % [id, s["t"]])
	assert_eq(seen.size(), 16, "every symbol is different")
	for id in NEW_IDS:
		assert_true(ItemIcons.has_icon(id), "%s: an icon before the item exists" % id)


func test_an_unknown_id_gets_the_gem() -> void:
	assert_false(ItemIcons.has_icon(&"no_such_item"))
	assert_eq(str(ItemIcons.shapes(&"no_such_item")), str(ItemIcons.gem()))
	assert_eq(ItemLooks.color_of_id(&"no_such_item"), ItemLooks.FALLBACK)


func test_every_icon_draws_on_a_control() -> void:
	var views: Array[ItemIconView] = []
	for id in ItemIcons.IDS + [&"no_such_item"]:
		var v := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		v.size = Vector2(48, 48)
		add_child_autofree(v)
		views.append(v)
	await wait_process_frames(2)
	for v in views:
		assert_eq(v.drawn, ItemIcons.shapes(v.item_id).size(), "%s drew every shape" % v.item_id)


func test_every_item_id_has_a_colour_and_the_kind_lookup_still_works() -> void:
	for id in ItemIcons.IDS:
		assert_true(ItemLooks.ID_COLORS.has(id), String(id))
	assert_eq(ItemLooks.color_of_id(&"ember_edge"), ItemLooks.color(WorldReader.ITEM_EMBER_EDGE))
	var tables := ContentCompiler.compile_items(ContentRepository.load_all())
	for t in tables:
		if not ItemLooks.COLORS.has(t.kind):
			continue  # an item newer than the kind table: only the id table knows it
		assert_eq(
			ItemLooks.color_of_id(t.id), ItemLooks.color(t.kind), "%s: id and kind agree" % t.id
		)


func test_card_shows_name_sentence_and_icon_then_hides() -> void:
	var card := ItemCard.new()
	add_child_autofree(card)
	assert_false(card.visible)
	card.show_item(&"frost_core", "Frost Core", "Hits slow enemies.", Color.CYAN, "Picked up")
	assert_true(card.is_showing())
	assert_true(card.visible)
	assert_eq(card.title_text(), "Frost Core")
	assert_eq(card.desc_text(), "Hits slow enemies.")
	assert_eq(card.caption_text(), "Picked up")
	assert_eq(card.icon_id(), &"frost_core")
	assert_eq(card.icon.color, Color.CYAN)
	await wait_process_frames(3)
	assert_lt(card.size.x, 420.0, "a small card")
	assert_lt(card.size.y, 130.0, "a small card")
	card.hide_card()
	assert_false(card.is_showing())
	assert_eq(card.title_text(), "")
	for i in 20:
		card._process(1.0 / 30.0)
	assert_false(card.visible, "faded out")


func test_preview_picks_the_nearest_pedestal_within_reach() -> void:
	var w := CombatLab.world()
	var tables := ContentCompiler.compile_items(ContentRepository.load_all())
	w.set_item_tables(tables)
	var r := WorldReader.new(w)
	var p := r.player_pos()
	w.add_pickup(0, p + Vector2(Hud.PREVIEW_M + 1.0, 0))
	assert_eq(Hud.preview_pickup(r), -1, "too far to preview")
	w.add_pickup(1, p + Vector2(0, 1.8))
	w.add_pickup(2, p + Vector2(-1.2, 0))
	assert_eq(Hud.preview_pickup(r), 2, "the nearest one within reach")
	assert_eq(r.pickup_item(Hud.preview_pickup(r)), 2)
	assert_gt(Hud.PREVIEW_M, r.pickup_radius_m(), "you see it before you take it")
