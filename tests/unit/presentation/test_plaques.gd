extends GutTest
## The plaques in use (v0.6.1 R1; v0.8.0 MU: carved Ember stone slabs, PlaqueBox, in place of the owner's crystal
## plaques) and the build picker (R2b; v0.8.0 MU: stone tablets): a plaque is a stone slab of any size with a glowing
## groove in its colour, its margins keep the text clear of it; its colour comes from the card colours' one family
## table; every text drawn on a plaque or a build card fits in English and Spanish (the layout is the 1920 x 1080
## base, stretched as a whole to 1280 x 720 by the project's canvas_items stretch mode, so one check covers both).

const CARD_DIRS := ["res://data/items", "res://data/stat_cards", "res://data/abilities"]
## v0.9.0 EL (owner Q25): the Ambush Cache is deleted.
const EVENTS: Array[StringName] = [
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


func test_a_plaque_is_a_carved_stone_slab_with_its_colours_groove() -> void:
	var box := Plaques.box(&"blue", 100.0)
	assert_true(box is StoneBox, "Ember stone, not a crystal texture")
	assert_eq(box.inlay, CardFrames.tint(&"blue"), "the groove in the plaque's colour")
	assert_gt(box.inlay_y, 0.0, "along its foot")
	var m := PlaqueBox.margins(100.0)
	assert_eq(box.content_margin_left, m.x)
	assert_eq(box.content_margin_bottom, m.w)
	assert_gt(box.content_margin_bottom, box.inlay_y, "the text stays above the groove")
	assert_eq(box.rim.a, 0.0, "no rim on a plain plaque")
	assert_eq(Plaques.box(&"gold", 100.0).rim, EmberStone.GOLD, "the gold plaque's rim inlay")
	var c := Plaques.content_size(100.0, 600.0, 4.0)
	assert_almost_eq(c.x, 600.0 - m.x - m.z - 8.0, 0.01)
	assert_almost_eq(c.y, 100.0 - m.y - m.w, 0.01)


func test_a_plaque_draws_in_a_panel_at_its_natural_size() -> void:
	var panel := PanelContainer.new()
	var box := Plaques.box(&"red", 120.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = box.natural_size()
	add_child_autofree(panel)
	await wait_process_frames(2)
	assert_almost_eq(panel.size.y, 120.0, 0.5)
	assert_gte(panel.size.x, 120.0 * 2.0 - 0.5)
	box.set_focused(false)
	assert_eq(box.tint(), Plaques.IDLE, "unfocused: dimmer")
	assert_eq(box.focus, 0.0)
	box.set_focused(true)
	assert_eq(box.tint(), 1.0)
	assert_eq(box.focus, 1.0, "focused: lit")


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
			if not r is ComboDefinition:  # v0.9.5 EE3: element_pairs.tres is the pairs' numbers (test_pair_banner)
				continue
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
		var box := Plaques.content_size(
			BuildPicker.TITLE_PLAQUE.y, BuildPicker.TITLE_PLAQUE.x, 10.0
		)
		assert_lt(w, box.x, "%s: the title fits its plaque" % lang)
		assert_lt(bold.get_height(BuildPicker.TITLE_FONT), box.y + 12.0)
	TranslationServer.set_locale(_locale)


## v0.6.1 SW2 (owner A5: "yes, choose weapon"): the picker's title.
func test_the_build_picker_title_is_choose_your_weapon() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr("UI_CHOOSE_BUILD"), "CHOOSE YOUR WEAPON")
	TranslationServer.set_locale("es")
	assert_eq(tr("UI_CHOOSE_BUILD"), "ELIGE TU ARMA")
	TranslationServer.set_locale(_locale)


func test_the_build_picker_is_carved_stone_with_no_crystal_art() -> void:
	var picker := BuildPicker.new(_defs(["res://data/builds"]), &"blade")
	add_child_autofree(picker)
	picker.settle()
	assert_not_null(picker.find_child("MenuBackdrop", true, false), "the ember backdrop behind")
	assert_eq(picker.theme, MenuStyle.theme(), "the menus' theme")
	assert_eq(picker.title_label().text, "UI_CHOOSE_BUILD")
	assert_true(picker.title_plaque().get_theme_stylebox("panel") is PlaqueBox, "a stone plaque")
	assert_eq(picker.find_children("*", "TextureRect", true, false).size(), 0, "no crystal art")
	assert_eq(picker.cards[0].custom_minimum_size, BuildCard.SIZE)
	for c in picker.cards:
		assert_true(c.panel_box() is StoneBox, "%s: a stone tablet" % c.name)
	var card := Rect2(Vector2.ZERO, BuildCard.SIZE)
	assert_true(card.encloses(BuildCard.emblem_rect()) and card.encloses(BuildCard.text_rect()))
	assert_lt(BuildCard.emblem_rect().end.y, BuildCard.text_rect().position.y, "symbol above text")
	var h := BuildCard.SIZE.y + BuildPicker.TITLE_PLAQUE.y + 200.0
	assert_lt(h, 1080.0, "title, cards, hint and Back fit 1080 px")
	picker.cards[0].grab_focus()
	picker.cards[0].seek(5.0)
	assert_eq(picker.cards[0].panel_box().focus, 0.0, "the box reads the focus on draw")
	await wait_process_frames(2)
	assert_gt(picker.cards[0].panel_box().focus, 0.0, "the focused card lights up")
