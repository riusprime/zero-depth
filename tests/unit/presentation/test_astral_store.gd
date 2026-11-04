extends GutTest
## v0.10.5 W3-O16 (owner 2026-11-04: "Yes, go on"; the shop's layout A, W3_O9_SHOP_G2.md, in the Astral style,
## W3_O13_UI_STYLE_G2.md): the shop is one Astral store window (a heading with its sigil, the buys left as pips, the
## wallet with Astral's shard, a price tag under each card, the heal and the reroll as wide Astral plates with the price
## big at their right, the hint between hairlines); the pick's title is an Astral heading over a rule; focus lights a
## plate by key as by mouse; everything fits 1920 x 1080 in English and Spanish. The behaviour is test_shop_views'.

const BASE := Vector2(1920, 1080)
const LANGS: Array[String] = ["en", "es"]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	TranslationServer.set_locale("en")


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
	w.shards = 300
	w.actors.hp[0] = w.actors.max_hp[0] / 2
	w.input_buffer[3] = 1
	Shop.interact(w)
	return w


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


func test_the_shop_is_one_astral_store_window() -> void:
	var w := _world()
	var p := ShopPanel.new()
	add_child_autofree(p)
	p.sync(WorldReader.new(w))
	await wait_physics_frames(2)
	assert_not_null(p.find_child("ShopWindow", true, false), "one store window")
	var heading := p.find_child("Heading", true, false) as AstralChrome.Heading
	assert_not_null(heading, "an Astral heading")
	if heading != null:
		assert_true(heading.title.uppercase, "letter-spaced capitals")
		assert_eq(heading.title.text, tr("SHOP_TITLE"))
	assert_eq(p.title_text(), tr("SHOP_TITLE"))
	assert_eq((p.find_child("ShopWallet", true, false) as Label).text, "300", "the wallet")
	var pips := p.find_child("Pips", true, false) as AstralChrome.Pips
	assert_not_null(pips, "the buys left as pips")
	if pips != null:
		assert_eq(pips.total, w.shop_table.max_buys, "one pip per buy")
		assert_eq(pips.left, int(Shop.read(w)["buys_left"]), "filled while left")
	for k in w.shop.offer.size():
		var tag := p.card_slot(k).get_parent().find_child("PriceTag", false, false)
		assert_not_null(tag, "card %d: its price tag hangs under it" % k)
		if tag != null:
			assert_true((tag.get_child(0) as ShardIcon).astral, "card %d: Astral's shard" % k)
	assert_eq(p.heal_tile.icon_kind, &"heal")
	assert_eq(p.reroll_tile.icon_kind, &"reroll")
	assert_true(p.heal_tile.title.uppercase, "the plate's title in capitals")
	assert_eq(
		p.heal_tile.price.get_theme_font_size(&"font_size"), ShopTile.PRICE_SIZE, "the price big"
	)
	assert_gt(ShopTile.PRICE_SIZE, ShopPanel.PRICE_SIZE, "bigger than a card's price tag")


func test_a_plate_lights_by_key_and_by_mouse() -> void:
	var w := _world()
	var p := ShopPanel.new()
	add_child_autofree(p)
	p.sync(WorldReader.new(w))
	await wait_physics_frames(1)
	assert_false(p.heal_tile.focused, "a card has the focus first")
	p._input(_key(KEY_DOWN))
	assert_eq(p.focused_value(), InputFrame.PICK_SHOP_HEAL, "down: the heal")
	assert_true(p.heal_tile.focused, "the heal plate lit")
	assert_false(p.reroll_tile.focused)
	p._input(_key(KEY_RIGHT))
	assert_true(p.reroll_tile.focused, "right: the reroll plate lit")
	assert_false(p.heal_tile.focused)
	p.heal_tile.hovered.emit()
	assert_true(p.heal_tile.focused, "the mouse over the heal lights it")
	assert_true(bool(p.entry(p.index_of_value(InputFrame.PICK_SHOP_HEAL))["enabled"]), "half HP")


func test_the_store_and_its_plates_fit_in_both_languages() -> void:
	var w := _world()
	for lang in LANGS:
		TranslationServer.set_locale(lang)
		var p := ShopPanel.new()
		add_child_autofree(p)
		p.sync(WorldReader.new(w))
		await wait_physics_frames(2)
		var win := p.find_child("ShopWindow", true, false) as Control
		assert_lte(win.size.x, BASE.x - 32.0, "%s: the window is %s wide" % [lang, win.size.x])
		assert_lte(win.size.y, BASE.y - 32.0, "%s: and %s tall" % [lang, win.size.y])
		for t: ShopTile in [p.heal_tile, p.reroll_tile]:
			assert_true(t.text_fits(), "%s: %s's text fits its plate" % [lang, t.name])
		gut.p("%s: shop window %s" % [lang, win.size])


func test_the_heading_splits_a_title_and_keeps_it_whole() -> void:
	for lang in LANGS:
		TranslationServer.set_locale(lang)
		var h := AstralChrome.Heading.new(32)
		add_child_autofree(h)
		var text := tr("PICK_TITLE_ALTAR")
		h.set_text(text)
		assert_eq(h.full_text(), text, "%s: the whole title" % lang)
		assert_eq(h.title.text + " · " + h.sub.text, text, "%s: split at the dot" % lang)
		assert_true(h.sub.visible)
		h.set_text(tr("SHOP_TITLE"))
		assert_false(h.sub.visible, "%s: no dot, no subtitle" % lang)


func test_the_pick_wears_the_astral_heading_rule_and_hint() -> void:
	var p := PickPanel.new()
	add_child_autofree(p)
	assert_not_null(p.find_child("Heading", true, false), "the Astral heading")
	assert_not_null(p.find_child("Rule", true, false), "the rule under it")
	assert_not_null(p.find_child("Hint", true, false), "the hint between hairlines")
	assert_null(p.find_child("TitleGroove", true, false), "no Ember groove")
