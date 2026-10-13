extends GutTest
## v0.7.5 SM (owner N8): a wand card's level on its card face (PickPanel.card_face, shared by the altar and chest pick,
## the shop, the event panel and the Swap) and on the HUD's wand pips and the Build page's row. A wand card not held
## reads "Lv 1"; held at N, "Lv N → N+1"; the legendary altar's level-5 version "Lv N → 5" ("Lv 5" when not held);
## an ability card follows the same rule; a stat card has no badge. The badge fits on the card in English and
## Spanish at the pick's and the shop's scales. Views only: they read the sim.

const BASE := Vector2(1920, 1080)

var _repo: ContentRepository
var _locale := ""


func before_all() -> void:
	_repo = AttackScenario.repo()
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_all() -> void:
	TranslationServer.set_locale(_locale)


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


func test_a_wand_card_reads_lv_1_then_lv_n_to_n_plus_1() -> void:
	var w := _world([])
	var r := WorldReader.new(w)
	var code := WandLab.code(w, &"wide_arc")
	assert_true(bool(r.card_info(code)["wand"]), "Wide Arc is a wand card")
	var face := PickPanel.card_face(self, r, code)
	assert_eq(face["level_text"], "Lv 1", "not held")
	assert_eq(face["held_level"], 0)
	assert_true(BuildSlots.take(w, code))
	face = PickPanel.card_face(self, r, code)
	assert_eq(face["level_text"], "Lv 1 → 2", "held at 1")
	assert_true(CardLevels.set_level(w, code, 3))
	face = PickPanel.card_face(self, r, code)
	assert_eq(face["level_text"], "Lv 3 → 4", "held at 3")
	TranslationServer.set_locale("es")
	assert_eq(PickPanel.card_face(self, r, code)["level_text"], "Nv 3 → 4", "in Spanish")
	TranslationServer.set_locale("en")
	var legendary := PickPanel.legendary_face(self, face, 5)
	assert_eq(legendary["level_text"], "Lv 3 → 5", "the legendary altar gives its level-5 version")
	var fresh := PickPanel.legendary_face(
		self, PickPanel.card_face(self, r, WandLab.code(w, &"long_edge")), 5
	)
	if bool(r.card_info(WandLab.code(w, &"long_edge"))["wand"]):
		assert_eq(fresh["level_text"], "Lv 5", "not held: straight to 5")


func test_an_item_that_does_not_level_and_a_stat_card_show_no_badge() -> void:
	var w := _world([])
	var r := WorldReader.new(w)
	var item := WandLab.code(w, &"ember_edge")
	assert_false(bool(r.card_info(item)["wand"]))
	assert_eq(PickPanel.card_face(self, r, item)["level_text"], "", "no level, no badge")
	var stat := Offers.STAT_BASE  # the first stat card, common
	assert_eq(PickPanel.card_face(self, r, stat)["level_text"], "")


func test_an_ability_card_follows_the_same_rule() -> void:
	var w := _world([])
	var r := WorldReader.new(w)
	var bomb := WandLab.code(w, &"bomb_lobber")
	assert_eq(PickPanel.card_face(self, r, bomb)["level_text"], "Lv 1")
	assert_true(BuildSlots.take(w, bomb))
	assert_eq(PickPanel.card_face(self, r, bomb)["level_text"], "Lv 1 → 2")


func test_the_badge_fits_on_the_card_at_the_pick_and_shop_scales() -> void:
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for scale in [PickSlot.PICK_SCALE, 0.8]:
			var s := PickSlot.new(0, scale)
			add_child_autofree(s)
			(
				s
				. show_card(
					{
						"id": &"wide_arc",
						"title": "Wide Arc",
						"sentence": "x",
						"color": Color.WHITE,
						"tier": 1,
						"tier_text": "Modifier · Rare",
						"type": WorldReader.CARD_MOD,
						"level_text": tr("UI_CARD_LEVEL_UP") % [4, 5],
					}
				)
			)
			await wait_physics_frames(1)
			var card := s.card
			var r := card.level_rect()
			assert_eq(card.level_text(), tr("UI_CARD_LEVEL_UP") % [4, 5])
			assert_true(
				Rect2(Vector2.ZERO, card.custom_minimum_size).encloses(r),
				"%s at %.1f: the badge %s is on the card" % [lang, scale, r]
			)
			assert_lt(
				r.end.y,
				card.content_rect().position.y + 0.5,
				"above the text panel: the title is clear"
			)
	TranslationServer.set_locale("en")


func test_the_hud_pips_and_the_build_row_show_a_wand_cards_level() -> void:
	var w := _world([&"wide_arc", &"ember_edge"])
	var code := WandLab.code(w, &"wide_arc")
	assert_true(CardLevels.set_level(w, code, 4))
	var r := WorldReader.new(w)
	var hud := BuildHud.new()
	add_child_autofree(hud)
	hud.sync(r)
	var k := Array(w.mod_slots).find(code)
	assert_eq(hud.pip_level_text(k), "4", "the wand card's pip says its level")
	assert_eq(hud.pip_level_text(Array(w.mod_slots).find(WandLab.code(w, &"ember_edge"))), "")
	var row := WandRow.new()
	add_child_autofree(row)
	row.show_wand(r.wand(), 8)
	assert_eq(row.level_text(k), "Lv 4", "and its tile on the Build page")
