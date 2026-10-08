extends GutTest
## The shop's views (v0.5.0 SH): the terminal glows and pulses without changing a shader; the panel shows the stock
## in the cards' CardStyle (FACET) with prices and the shard icon, dims what you can't afford or use, lists the
## salvage, moves its focus by keyboard and pad and sends actions as picks; the minimap draws the shop and lists it
## in the legend.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(11, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
	w.shop.id = w.take_root()
	w.shop.pos = Vector2(1.0, 0)
	return w


func _open(w: World) -> void:
	w.input_buffer[3] = 1
	Shop.interact(w)


func test_the_terminal_glows_and_pulses_without_changing_a_shader() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var view := ShopTerminalView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.setup(reader.shop_pos(), 1024)
	view.sync(reader)
	var before := DamageFlashKeys.of(view)
	assert_gt(before.size(), 10, "the terminal has its pieces")
	for m in view.materials():
		assert_true(m.emission_enabled, "emission on from creation")
	assert_true(view.hot(), "in reach: lit")
	w.shards = 500
	_open(w)
	w.actors.hp[0] = 10
	Shop.heal(w)
	view.sync(reader)
	assert_true(view.pulsing(), "a purchase pulses")
	Shop.heal(w)
	view.sync(reader)
	assert_true(view.shaking(), "a refusal shakes")
	for k in 40:
		view._process(1.0 / 60.0)
	assert_false(view.pulsing())
	assert_false(view.shaking())
	assert_eq(DamageFlashKeys.of(view), before, "no shader changed")


func test_the_panel_shows_the_stock_in_card_style_with_prices() -> void:
	var w := _world()
	w.shards = 40
	_open(w)
	var r := WorldReader.new(w)
	var p := ShopPanel.new()
	add_child_autofree(p)
	p.sync(r)
	assert_true(p.visible and p.is_open())
	assert_eq(p.title_text(), tr("SHOP_TITLE"))
	assert_eq(CardStyle.current, CardStyle.Look.FACET, "the shipped look")
	for k in w.shop.offer.size():
		var box := p.card_slot(k).panel_box()
		assert_true(CardStyle.is_plain(box), "card %d: the cards' plain panel" % k)
		assert_eq(box.corner_radius_top_left, CardStyle.CUT, "FACET's cut corner")
		var price := Shop.price(w, w.shop.offer[k])
		assert_eq(p.card_price_text(k), str(price))
		assert_eq(bool(p.entry(k)["enabled"]), price <= 40, "dimmed when unaffordable")
	for t: ShopTile in [p.heal_tile, p.reroll_tile]:
		assert_true(CardStyle.is_plain(t.panel_box()))
	assert_false(
		bool(p.entry(p.index_of_value(InputFrame.PICK_SHOP_HEAL))["enabled"]), "full HP: no heal"
	)
	assert_true(bool(p.entry(p.index_of_value(InputFrame.PICK_SHOP_REROLL))["enabled"]), "20 of 40")
	assert_eq(p.salvage_count(), 0, "nothing to salvage yet")
	w.shards = 10
	p.sync(r)
	assert_false(
		bool(p.entry(p.index_of_value(InputFrame.PICK_SHOP_REROLL))["enabled"]), "now too poor"
	)
	assert_eq(p.reroll_tile.price.get_theme_color(&"font_color"), ShopTile.POOR, "its price in red")


func test_the_panel_navigates_and_sends_actions() -> void:
	var w := _world()
	w.shards = 1000
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
	Stats.add_card(w, Stats.Stat.AREA, 0)
	_open(w)
	var r := WorldReader.new(w)
	var got := []
	var p := ShopPanel.new()
	add_child_autofree(p)
	p.picked.connect(func(v: int) -> void: got.append(v))
	p.sync(r)
	assert_eq(p.salvage_count(), 2, "the stat card and Bomb Lobber (never the weapon)")
	assert_eq(p.salvage_tile(1).price.text, "+25")
	assert_eq(p.focus_index(), 0)
	for k in 6:
		p._input(_key(KEY_RIGHT))
	assert_eq(p.focus_index(), 6, "right runs along every entry")
	p._input(_key(KEY_3))
	assert_eq(p.focus_index(), 2, "3 jumps to the third card")
	p._input(_key(KEY_SPACE))
	assert_eq(got, [], "Space (dash) never confirms")
	p._input(_key(KEY_ENTER))
	assert_eq(got, [3], "Enter buys the third card")
	p._input(_pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(
		p.focused_value(), InputFrame.PICK_SHOP_REROLL, "down: the services row, nearest place"
	)
	p._input(_pad(JOY_BUTTON_DPAD_LEFT))
	assert_eq(p.focused_value(), InputFrame.PICK_SHOP_HEAL)
	p._input(_pad(JOY_BUTTON_A))
	assert_eq(got, [3], "a disabled entry sends nothing (full HP)")
	p._input(_pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(p.focused_value(), InputFrame.PICK_SHOP_SELL, "down again: the salvage list")
	p._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	p._input(_pad(JOY_BUTTON_A))
	assert_eq(got, [3, InputFrame.PICK_SHOP_SELL + 1], "A salvages the focused entry")
	p._input(_pad(JOY_BUTTON_DPAD_UP))
	p._input(_pad(JOY_BUTTON_DPAD_UP))
	assert_eq(int(p.entry(p.focus_index())["row"]), 0, "up twice: back to the cards")
	p.salvage_tile(0).clicked.emit()
	assert_eq(got[-1], InputFrame.PICK_SHOP_SELL, "a click acts")
	p._input(_pad(JOY_BUTTON_B))
	assert_eq(got[-1], InputFrame.PICK_CANCEL, "B leaves")
	p._input(_key(KEY_ESCAPE))
	assert_eq(got[-1], InputFrame.PICK_CANCEL, "so does Esc")


func test_the_panel_follows_the_sim_and_closes() -> void:
	var w := _world()
	w.shards = 1000
	_open(w)
	var r := WorldReader.new(w)
	var p := ShopPanel.new()
	add_child_autofree(p)
	p.sync(r)
	Shop.buy(w, 1)
	p.sync(r)
	assert_eq(p.card_price_text(1), tr("SHOP_SOLD"), "a bought card reads Sold")
	assert_false(bool(p.entry(1)["enabled"]))
	Shop.close(w)
	p.sync(r)
	assert_false(p.visible, "closed with the shop")


func test_every_shop_string_has_en_and_es() -> void:
	var keys := [
		"SHOP_PROMPT",
		"SHOP_TITLE",
		"SHOP_SOLD",
		"SHOP_CANT_USE",
		"SHOP_HEAL",
		"SHOP_HEAL_USED",
		"SHOP_HEAL_FULL",
		"SHOP_REROLL",
		"SHOP_SALVAGE",
		"SHOP_SALVAGE_NONE",
		"SHOP_SELL_STAT",
		"SHOP_SELL_ABILITY",
		"SHOP_HINT",
		"MAP_LEGEND_SHOP"
	]
	for lang in ["en", "es"]:
		var t := TranslationServer.get_translation_object(lang)
		for k: String in keys:
			var s := String(t.get_message(StringName(k)))
			assert_false(s.is_empty() or s == k, "%s has %s" % [k, lang])


func test_the_minimap_lists_the_shop() -> void:
	var found := false
	for row: Array in MinimapView.LEGEND:
		found = found or row[0] == &"shop"
	assert_true(found, "the legend has the shop")


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


func _pad(b: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev
