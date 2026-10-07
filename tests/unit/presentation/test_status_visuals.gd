extends GutTest
## v0.3.0 G presentation: status effects on enemies (embers, shock pips, drips, frost crystals, the frozen shell),
## guard-charge orbs, payoff effects, the combo card and the HUD's combo badges. Materials are kept, never switched
## to another shader (the v0.2.0 DAMAGE_LAG rule).


func _views(w: World) -> Array:
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := StatusVisuals.new(actors)
	add_child_autofree(fx)
	actors.sync(reader)
	fx.sync(reader)
	return [reader, actors, fx]


func _world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	var repo := ContentRepository.load_all()
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	for k in w.item_tables.size():
		w.add_item(k)
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	w.add_dummy(Vector2(-2, 0), 0.35, 500)
	return w


func _keys(node: Node) -> Dictionary:
	var stat := node.get_node_or_null("Statuses")
	return DamageFlashKeys.of(stat) if stat != null else {}


func test_each_status_shows_its_pieces_and_they_go_when_it_ends() -> void:
	var w := _world()
	var s := _views(w)
	var actors: ActorViews = s[1]
	var fx: StatusVisuals = s[2]
	var id := w.actors.ids[1]
	assert_eq(fx.view_count(), 0, "no status, nothing built")
	var a := w.actors
	a.burn_stacks[1] = 5
	a.shock_stacks[1] = 3
	a.bleed_stacks[1] = 7
	a.frost_stacks[1] = 2
	w.guard_charges = 2
	fx.sync(s[0])
	assert_eq(fx.shown(id, &"embers"), StatusVisuals.EMBERS, "a full burn: every ember")
	assert_eq(fx.shown(id, &"pips_lit"), 3, "one lit pip per shock stack")
	assert_eq(fx.shown(id, &"drips"), 3)
	assert_eq(fx.shown(id, &"crystals"), 2, "one crystal per frost stack")
	assert_eq(fx.shown(id, &"shell"), 0)
	assert_eq(fx.shown(w.actors.ids[0], &"orbs"), 2, "guard charges circle the player")
	var keys := _keys(actors.actor_node(id))
	assert_gt(keys.size(), 10)
	a.frost_stacks[1] = 0
	a.frozen_t[1] = 30
	fx.sync(s[0])
	assert_eq(fx.shown(id, &"shell"), 1, "frozen: the ice shell")
	assert_eq(fx.shown(id, &"crystals"), StatusVisuals.CRYSTALS)
	assert_eq(_keys(actors.actor_node(id)), keys, "no material changed its shader")
	for m in [&"burn_stacks", &"shock_stacks", &"bleed_stacks", &"frozen_t"]:
		var arr: PackedInt32Array = a.get(m)
		arr[1] = 0
		a.set(m, arr)
	w.guard_charges = 0
	fx.sync(s[0])
	assert_eq(fx.view_count(), 0, "statuses over: the pieces go")


func test_payoffs_draw_once_each() -> void:
	var w := _world()
	var s := _views(w)
	var fx: StatusVisuals = s[2]
	w.discharge_tick = 5
	w.discharge_from = Vector2(1, 0)
	w.discharge_to = PackedVector2Array([Vector2(3, 1), Vector2(2, -2)])
	w.shatter_tick = 5
	fx.sync(s[0])
	assert_eq(
		fx.fx_count(), 4 * 2 + 1 + 1, "two lightning lines, the discharge ring, the shatter ring"
	)
	fx.sync(s[0])
	assert_eq(fx.fx_count(), 10, "the same payoff doesn't draw twice")
	for k in StatusVisuals.FX_FRAMES:
		fx._process(1.0 / 60.0)
	assert_eq(fx.fx_count(), 0, "they fade")


func test_combo_card_shows_both_icons_in_a_special_frame() -> void:
	var card := ComboCard.new()
	add_child_autofree(card)
	card.show_combo(
		&"plasma_arc", &"ember_edge", &"static_chain", "Plasma Arc", "Arcs fire.", "Combo"
	)
	assert_true(card.is_showing())
	assert_eq(card.title_text(), "Plasma Arc")
	assert_eq(card.caption_text(), "Combo")
	assert_eq(card.pair_ids(), [&"ember_edge", &"static_chain"])
	assert_false(card.icon.visible, "the pair replaces the single icon")
	assert_eq(card._box.border_color, Color(ItemLooks.combo_color(&"plasma_arc"), 0.9))
	assert_gt(card._box.border_width_top, 0, "framed on every side")
	assert_true(CardStyle.is_plain(card._box), "v0.3.5 F16: square, no shadow, no side bar")
	assert_eq(card._box.border_width_left, card._box.border_width_top, "an even outline")
	await wait_process_frames(2)
	assert_eq(
		card.pair.drawn,
		ItemIcons.shapes(&"ember_edge").size() + ItemIcons.shapes(&"static_chain").size()
	)


func test_hud_shows_the_combo_card_and_a_badge_when_a_combo_unlocks() -> void:
	var repo := ContentRepository.load_all()
	var player := PlayerTable.starting_values()
	var w := FloorScenario.build(
		4,
		player,
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo)
	)
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_eq(hud.combo_badge_count(), 0)
	assert_false(hud.combo_card().is_showing())
	for id: StringName in [&"thorn_mantle", &"phase_strike"]:
		for k in w.item_tables.size():
			if w.item_tables[k].id == id:
				w.add_item(k)
	hud.sync(reader)
	await wait_process_frames(1)
	assert_true(hud.combo_card().is_showing())
	assert_eq(hud.combo_card().title_text(), tr("ITEM_COMBO_SPIKED_PHASE"))
	assert_eq(hud.combo_card().desc_text(), tr("ITEM_COMBO_SPIKED_PHASE_DESC"))
	assert_eq(hud.combo_card().pair_ids(), [&"thorn_mantle", &"phase_strike"])
	assert_eq(hud.combo_badge_count(), 1)
	assert_eq(hud.item_icon_count(), 2)
	hud._combo_left = 0.0
	hud.sync(reader)
	assert_false(hud.combo_card().is_showing(), "it goes after its time")
	assert_eq(hud.combo_badge_count(), 1, "the badge stays")
