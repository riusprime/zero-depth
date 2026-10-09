extends GutTest
## The owner's crystal plaques in use (v0.6.1 R1) and the build picker's art (R2b): the plaque is a nine-slice whose
## corners keep the crystals' shape and whose middle stretches; its colour comes from the card frames' one family
## table; every text drawn on a plaque or a build card fits in English and Spanish (the layout is the 1920 x 1080
## base, stretched as a whole to 1280 x 720 by the project's canvas_items stretch mode, so one check covers both).

const CARD_DIRS := ["res://data/items", "res://data/stat_cards", "res://data/abilities"]
const EVENTS: Array[StringName] = [
	&"ambush_cache",
	&"blood_price",
	&"cleansing_font",
	&"echo_mirror",
	&"overclock_vent",
	&"scrap_heap",
	&"unstable_core",
	&"wandering_drone",
]
## Text below this size (px at 1080p) counts as too small to read at 1280 x 720.
const MIN_TEXT := 11

var _locale := ""


func before_all() -> void:
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


func _defs(dirs: Array) -> Array[Resource]:
	var out: Array[Resource] = []
	for dir: String in dirs:
		for path in ContentScanner.scan(dir):
			out.append(load(path))
	return out


func _sentence(r: Resource) -> String:
	var s := tr(r.desc_key)
	var n := s.count("%s") + s.count("%d")
	if n > 0:
		var args := []
		for i in n:
			args.append("40" if s.contains("%s") else 40)
		s = s % args
	return s


func test_the_nine_slice_keeps_the_crystals_and_stretches_the_middle() -> void:
	var box := Plaques.box(&"blue", 100.0)
	var s := 100.0 / Plaques.SIZE.y
	assert_almost_eq(box.scale_factor, s, 0.0001)
	var rect := Rect2(10, 20, 900, 100)
	var p := box.pieces(rect)
	assert_eq(p.size(), 9)
	var m := box.slice_margins()
	assert_almost_eq(m.x, Plaques.SLICE_LEFT * s, 0.01, "left margin over the left cluster")
	assert_almost_eq(m.z, Plaques.SLICE_RIGHT * s, 0.01, "right margin over the right cluster")
	for k in [0, 2, 6, 8]:  # the corners: drawn at the plaque's own scale, both axes
		var dst: Rect2 = p[k][0]
		var src: Rect2 = p[k][1]
		assert_almost_eq(dst.size.x / src.size.x, s, 0.001, "corner %d keeps its width" % k)
		assert_almost_eq(dst.size.y / src.size.y, s, 0.001, "corner %d keeps its height" % k)
	for k in [3, 5]:  # the clusters' middle rows: the same scale across
		assert_almost_eq((p[k][0] as Rect2).size.x / (p[k][1] as Rect2).size.x, s, 0.001)
	var mid: Rect2 = p[4][0]
	assert_almost_eq(mid.size.x, rect.size.x - m.x - m.z, 0.01, "the middle takes the rest")
	assert_gt(mid.size.x / (p[4][1] as Rect2).size.x, s * 2.0, "the middle stretches")
	assert_eq((p[8][0] as Rect2).end, rect.end, "the pieces fill the rect")
	assert_eq(box.texture.resource_path, Plaques.path(&"blue"))
	assert_gt(box.content_margin_left, 0.0)
	assert_lt(box.content_margin_left, m.x, "text starts inside the dark panel, before the stretch")


func test_a_plaque_draws_in_a_panel_at_its_natural_size() -> void:
	var panel := PanelContainer.new()
	var box := Plaques.box(&"red", 120.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = box.natural_size()
	add_child_autofree(panel)
	await wait_process_frames(2)
	assert_almost_eq(panel.size.x, Plaques.SIZE.x * 120.0 / Plaques.SIZE.y, 0.5)
	assert_almost_eq(panel.size.y, 120.0, 0.5)
	box.set_focused(false)
	assert_eq(box.tint(), Plaques.IDLE, "unfocused: dimmer")
	box.set_focused(true)
	assert_eq(box.tint(), Color.WHITE)


func test_plaque_colours_come_from_the_card_frames_table() -> void:
	for fam: StringName in CardFrames.FRAME:
		assert_eq(Plaques.of_family(fam), CardFrames.frame_of(fam), "one table: %s" % fam)
		var id := Plaques.of_family(fam)
		assert_eq(Plaques.nearest(Plaques.tint(id)), id, "%s is nearest itself" % id)
	for use: StringName in Plaques.USE_FAMILY:
		assert_true(CardFrames.FRAME.has(Plaques.USE_FAMILY[use]), "%s: a known family" % use)
	for stat: StringName in GambleIcons.COLORS:
		assert_true(Plaques.GAMBLE_FAMILY.has(stat), "%s has a family" % stat)
	assert_eq(Plaques.of_card(&"wildfire"), &"orange", "a card's plaque is its frame's colour")
	assert_eq(Plaques.of_card(&"crit_chance", -1, 2), &"gold", "epic")
	assert_eq(Plaques.of_card(&"wildfire", -1, 0, true), &"violet", "cursed")
	assert_eq(Plaques.of_use(&"shop_heal"), &"green")
	assert_eq(Plaques.of_gamble(&"heat_capacity"), &"orange")


func test_item_and_combo_plaques_fit_in_english_and_spanish() -> void:
	var card := ItemCard.new()
	add_child_autofree(card)
	var combo := ComboCard.new()
	add_child_autofree(combo)
	var too_long: Array[String] = []
	var grown: Array[String] = []
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for r in _defs(CARD_DIRS):
			card.show_item(r.id, tr(r.name_key), _sentence(r), Color.WHITE, tr("HUD_PICKED_UP"))
			if not card.text_fits():
				too_long.append("%s %s" % [lang, r.id])
			if card.plaque_height() > ItemCard.HEIGHT:  # grown
				grown.append("%s %s %d" % [lang, r.id, card.plaque_height()])
			assert_gte(card.desc_size, MIN_TEXT, "%s %s: sentence size" % [lang, r.id])
		for r in _defs(["res://data/combos"]):
			var a: StringName = r.item_a if r.item_a != &"" else r.ability_a
			var b: StringName = r.item_b if r.item_b != &"" else r.ability_b
			combo.show_combo(r.id, a, b, tr(r.name_key), tr(r.desc_key), tr("UI_COMBO_UNLOCKED"))
			assert_true(combo.text_fits(), "%s combo %s fits its plaque" % [lang, r.id])
	TranslationServer.set_locale(_locale)
	gut.p("item plaques grown for a long sentence (height px): %s" % [grown])
	assert_eq(too_long, [] as Array[String], "every card's name and sentence fit the item plaque")


func test_gamble_lines_fit_in_english_and_spanish() -> void:
	var ci := Control.new()
	add_child_autofree(ci)
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for stat: StringName in GambleIcons.KEYS:
			var line := GambleIcons.line(ci, stat, 160)
			assert_true(GambleCard.line_fits(line), "%s %s: '%s' fits" % [lang, stat, line])
			assert_gte(GambleCard.fit_line(line), 16, "%s %s: readable" % [lang, stat])
	TranslationServer.set_locale(_locale)


func test_shop_plaques_fit_in_english_and_spanish() -> void:
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		var sell := ShopTile.new("Sell", ShopPanel.SELL_W)
		add_child_autofree(sell)
		for r in _defs(CARD_DIRS):
			for detail in [tr("UI_CARD_MOD"), tr("SHOP_SELL_STAT") % [tr("RARITY_LEGENDARY"), 3]]:
				sell.show_tile(tr(r.name_key), detail, 120, true, false, true)
				assert_true(sell.text_fits(), "%s %s / %s fits" % [lang, r.id, detail])
				assert_gte(sell.title_size, MIN_TEXT, "%s %s: title size" % [lang, r.id])
		var heal := ShopTile.new("Heal", 360.0)
		add_child_autofree(heal)
		for d in ["", tr("SHOP_HEAL_USED"), tr("SHOP_HEAL_FULL")]:
			heal.show_tile(tr("SHOP_HEAL") % 120, d, 120, true)
			assert_true(heal.text_fits(), "%s heal '%s'" % [lang, d])
		var reroll := ShopTile.new("Reroll", 360.0)
		add_child_autofree(reroll)
		for d in ["", tr("SHOP_REROLL_NONE")]:
			reroll.show_tile(tr("SHOP_REROLL"), d, 120, true)
			assert_true(reroll.text_fits(), "%s reroll '%s'" % [lang, d])
		var cleanse := ShopTile.new("Cleanse", 360.0)
		add_child_autofree(cleanse)
		for r in _defs(["res://data/curses"]):
			cleanse.show_tile(tr("SHOP_CLEANSE"), tr(r.name_key), 120, true)
			assert_true(cleanse.text_fits(), "%s cleanse %s" % [lang, r.id])
	TranslationServer.set_locale(_locale)


func test_event_plaques_fit_and_the_panel_fits_the_screen() -> void:
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for id in EVENTS:
			var w := EventLab.world(4242, 1, &"blade", [&"withering"])
			Stats.add_card(w, Stats.Stat.DAMAGE, 0)
			EventLab.set_event(w, id)
			EventLab.open(w)
			var reader := WorldReader.new(w)
			var panel := EventPanel.new()
			add_child_autofree(panel)
			panel.sync(reader)
			for c in panel.card_count():
				assert_true(panel.card_fits(c), "%s %s %d fits its plaque" % [lang, id, c])
				assert_lte(
					panel.card_steps(c),
					EventPanel.SIZES["Reward"] - MIN_TEXT,
					"%s %s %d: readable (%d steps)" % [lang, id, c, panel.card_steps(c)]
				)
			var n := panel.card_count()
			var h := n * EventPanel.CARD_H + (n - 1) * 10.0 + 200.0
			assert_lt(h, 1080.0, "%s %s: the panel fits 1080 px" % [lang, id])
	TranslationServer.set_locale(_locale)


func test_the_banner_plaque_grows_with_its_line() -> void:
	var hud := PhaseHud.new()
	add_child_autofree(hud)
	hud.announce.text = "Nuevo: Francotirador de élite"
	hud.banner.visible = true
	await wait_process_frames(2)
	assert_gt(hud.banner.size.x, hud.announce.size.x, "the plaque around the line")
	assert_lt(hud.banner.size.x, 1920.0)
	assert_true(hud.banner.get_theme_stylebox("panel") is PlaqueBox)


func test_build_cards_and_title_fit_in_english_and_spanish() -> void:
	var builds := _defs(["res://data/builds"])
	assert_eq(builds.size(), 2)
	var bold := HudStyle.font(true)
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for b in builds:
			assert_true(
				BuildCard.fits(tr(b.name_key), tr(b.desc_key)),
				"%s %s fits its frame" % [lang, b.id]
			)
		var title := tr("UI_CHOOSE_BUILD")
		var w := (
			bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, BuildPicker.TITLE_FONT).x
		)
		var box := BuildArt.TITLE_BOX.size * BuildArt.TITLE_SCALE
		assert_lt(w, box.x, "%s: the title fits the plaque's panel" % lang)
		assert_lt(bold.get_height(BuildPicker.TITLE_FONT), box.y)
	TranslationServer.set_locale(_locale)


func test_the_build_picker_wears_the_owners_art_and_no_glitch() -> void:
	var picker := BuildPicker.new(_defs(["res://data/builds"]), &"blade")
	add_child_autofree(picker)
	picker.settle()
	assert_not_null(
		picker.find_child("MenuBackdrop", true, false), "the Cold-glass backdrop behind"
	)
	assert_eq(picker.theme, MenuStyle.theme(), "the menus' theme")
	assert_eq(BuildArt.frame(0).resource_path, BuildArt.path("frame_blade"))
	assert_eq(BuildArt.frame(1).resource_path, BuildArt.path("frame_gun"))
	assert_eq(BuildArt.emblem(1).resource_path, BuildArt.path("emblem_gun"))
	assert_eq(picker.title_label().text, "UI_CHOOSE_BUILD")
	assert_eq(picker.cards[0].custom_minimum_size, BuildCard.SIZE)
	var frame := Rect2(Vector2.ZERO, BuildArt.FRAME_SIZE)
	assert_true(frame.encloses(BuildArt.EMBLEM_BOX) and frame.encloses(BuildArt.TEXT_BOX))
	var h := BuildCard.SIZE.y + BuildArt.TITLE_SIZE.y * BuildArt.TITLE_SCALE + 200.0
	assert_lt(h, 1080.0, "title, cards, hint and Back fit 1080 px")
