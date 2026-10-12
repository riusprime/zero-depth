extends GutTest
## v0.6.5 WN2 (docs/design/WAND.md rule 4): the wand's views. The row (WandRow) shows each card in slot order with its
## frame colour, name and level, a divider after each trigger card and the brackets that say what each part of the
## wand is ("the shot you fire", "cast on hit →"); the Build page and the Swap panel at 8 slots (with three cuts, and
## the Swap's new card placed in the row) fit the 1920 x 1080 base, so 1280 x 720 (canvas_items stretch); every wand
## card's name fits its tile in English and Spanish; the HUD's pips show the cuts. Views only: they read the sim.

const EIGHT: Array = [
	&"ember_edge",
	&"trigger_on_hit",
	&"long_edge",
	&"trigger_on_end",
	&"twin_arc",
	&"trigger_on_kill",
	&"serrated_edge",
	&"wide_arc",
]
const ABILITY_MODS: Array = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]
const BASE := Vector2(1920, 1080)
const LANGS: Array[String] = ["en", "es"]

var _repo: ContentRepository
var _locale := ""


func before_all() -> void:
	_repo = AttackScenario.repo()
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


## `rect` (content laid out centred in the test's viewport, whatever its height) fits the 1920 x 1080 base: its size
## does, and it stays inside the base's width.
func _fits(rect: Rect2) -> bool:
	return (
		rect.size.x <= BASE.x
		and rect.size.y <= BASE.y
		and rect.position.x >= 0.0
		and rect.end.x <= BASE.x
	)


func _world(ids: Array) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.floor_index = 3
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)
	return w


func test_the_row_cuts_after_each_trigger_and_names_the_parts() -> void:
	var r := WorldReader.new(_world(EIGHT))
	var row := WandRow.new()
	add_child_autofree(row)
	TranslationServer.set_locale("en")
	row.show_wand(r.wand(), 8)
	assert_eq(row.slot_count(), 8)
	assert_eq(row.cut_positions().size(), 3, "three trigger cards, three dividers")
	assert_eq(
		Array(row.bracket_texts()),
		["the shot you fire", "cast on hit →", "cast where it ends →", "too deep to cast"],
		"the parts of the wand, the third trigger's past the compile's depth"
	)
	for k in 8:
		assert_false(row.card_name(k).is_empty(), "slot %d has its name" % (k + 1))
	TranslationServer.set_locale("es")
	assert_eq(row.bracket_texts()[1], "se lanza al impactar →", "and in Spanish")


func test_the_row_shows_levels_and_empty_slots() -> void:
	var w := _world([&"bomb_lobber", &"ember_edge"])
	var r := WorldReader.new(w)
	var row := WandRow.new()
	add_child_autofree(row)
	TranslationServer.set_locale("en")
	row.show_wand(r.wand(), 8)
	assert_eq(row.level_text(0), "Lv 1", "an ability modifier shows its level")
	assert_eq(row.level_text(1), "", "an item has no level")
	assert_eq(row.card_name(2), "Empty", "the slots past the cards are empty")
	assert_eq(row.cut_positions().size(), 0)
	assert_eq(Array(row.bracket_texts()), ["the shot you fire"])


func test_the_build_page_at_eight_slots_fits_the_screen_in_both_languages() -> void:
	var r := WorldReader.new(_world(EIGHT))
	for lang in LANGS:
		TranslationServer.set_locale(lang)
		var page := BuildPage.new()
		add_child_autofree(page)
		page.open(r.wand(), 8)
		await wait_physics_frames(2)
		var rect := page.content_rect()
		assert_true(_fits(rect), "%s: the Build page %s fits %s" % [lang, rect, BASE])
		assert_true(
			page.row.row_width() <= 1400.0, "%s: the row is %d px" % [lang, page.row.row_width()]
		)
		assert_false(page.read_back_text().is_empty(), "%s: the read-back" % lang)
		gut.p("%s: build page %s, row %d px" % [lang, rect, page.row.row_width()])


func test_the_swap_at_eight_slots_fits_the_screen_with_the_new_card_placed() -> void:
	var w := _world(EIGHT)
	Offers.apply(w, AttackScenario.item_index(w.item_tables, &"overcharge"))
	assert_true(BuildSlots.swapping(w))
	var r := WorldReader.new(w)
	for lang in LANGS:
		TranslationServer.set_locale(lang)
		var panel := SwapPanel.new()
		add_child_autofree(panel)
		panel.sync(r)
		await wait_physics_frames(2)
		assert_eq(panel.slot_count(), 8)
		var rect := panel.content_rect()
		assert_true(_fits(rect), "%s: the Swap %s fits %s" % [lang, rect, BASE])
		panel._start_place(3)  # the new card put in the row: nine tiles
		await wait_physics_frames(2)
		assert_eq(panel.row.slot_count(), 9)
		rect = panel.content_rect()
		assert_true(_fits(rect), "%s: with the new card placed, %s fits" % [lang, rect])
		gut.p("%s: swap %s, row %d px" % [lang, rect, panel.row.row_width()])


func test_every_wand_card_name_fits_its_tile_in_both_languages() -> void:
	var w := AttackScenario.world(&"blade", [], true, [])
	var ids: Array[StringName] = []
	var keys: Array[StringName] = []
	for t in w.item_tables:
		if BuildSlots.is_slot_item(t):
			ids.append(t.id)
	for id: StringName in ids:
		keys.append(Offers.info(w, WandLab.code(w, id))["name_key"])
	for id: StringName in ABILITY_MODS:
		keys.append(Offers.info(w, WandLab.code(w, id))["name_key"])
	var font := HudStyle.font(true)
	var width := WandRow.TILE.x - 16.0
	var line_h := font.get_height(WandRow.NAME_SIZE)
	var checked := 0
	for lang in LANGS:
		TranslationServer.set_locale(lang)
		for key: StringName in keys:
			var text := tr(key)
			for word in text.split(" ", false):
				var ww := (
					font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, WandRow.NAME_SIZE).x
				)
				assert_true(
					ww <= width, "%s: '%s' of '%s' is %d px (%d)" % [lang, word, text, ww, width]
				)
			var sz := font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_CENTER, width, WandRow.NAME_SIZE
			)
			assert_true(sz.y <= line_h * 2.0 + 1.0, "%s: '%s' fits in two lines" % [lang, text])
			checked += 1
	assert_gt(checked, 100, "every slot card, both languages")
	assert_true(WandRow.NAME_SIZE >= 13 and WandRow.SMALL_SIZE >= 12, "legible at 1280 x 720")


func test_the_hud_pips_show_the_cuts() -> void:
	var r := WorldReader.new(_world(EIGHT))
	var hud := BuildHud.new()
	add_child_autofree(hud)
	hud.sync(r)
	assert_eq(hud.filled_pips(), 8)
	assert_eq(Array(hud.cut_slots()), [1, 3, 5], "a cut after each trigger card")
	assert_eq(hud.pip_level_text(1), BuildHud.TRIGGER_MARK)
