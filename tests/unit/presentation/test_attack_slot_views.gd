extends GutTest
## v0.9.0 AS (owner Q5, Q14; G2 option A): the slot tag and "Replaces <card>" on the pick card (PickPanel.card_face →
## PickSlot's slot line, the same face the shop, events and the Swap panel use), the slot tag on the wand's tiles
## (WandRow: the Build page and the Swap panel) and the Build page's slot counts, in English and Spanish; the replaced
## card's chip burns and is whole again. Views only: they read the sim.

var _repo: ContentRepository
var _locale := ""


func before_all() -> void:
	_repo = AttackScenario.repo()
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


func _world(ids: Array) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	var w := World.new(5, t)
	w.floor_index = 3
	w.run_floor = 3
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.slot_table = WandCompiler.slots(_repo, w.item_tables)
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)
	return w


func test_the_pick_card_shows_its_slot_and_what_it_replaces_in_both_languages() -> void:
	var w := _world([&"gun_twin", &"gun_pierce"])
	var r := WorldReader.new(w)
	var want := {
		"en": ["Pattern", "Replaces Twin", "Secondary", "Element"],
		"es": ["Patrón", "Reemplaza a Gemelo", "Secundaria", "Elemento"],
	}
	for lang: String in want:
		TranslationServer.set_locale(lang)
		var s := PickSlot.new(0)
		add_child_autofree(s)
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"halo_shot")))
		assert_eq([s.slot_text(), s.replaces_text()], [want[lang][0], want[lang][1]], lang)
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"gun_homing")))
		assert_eq([s.slot_text(), s.replaces_text()], [want[lang][2], ""], "%s: room left" % lang)
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"storm_core")))
		assert_eq(s.slot_text(), want[lang][3])
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"trigger_on_hit")))
		assert_eq(s.slot_text(), "", "%s: a free card has no tag" % lang)


func test_the_replaced_chip_burns_and_comes_back_whole() -> void:
	var w := _world([&"gun_twin"])
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(PickPanel.card_face(self, WorldReader.new(w), WandLab.code(w, &"gun_ring")))
	assert_false(s.replaced_burning())
	s.burn_replaced(0.5)
	assert_true(s.replaced_burning() or HudStyle.reduced_motion, "it burns (N8's dissolve)")
	s.burn_replaced(0.0)
	assert_false(s.replaced_burning(), "whole again")


func test_the_wand_tiles_and_the_build_page_read_the_slots() -> void:
	TranslationServer.set_locale("en")
	var w := _world([&"gun_ring", &"gun_swirl", &"ember_core", &"trigger_on_hit"])
	var r := WorldReader.new(w)
	var row := WandRow.new()
	add_child_autofree(row)
	row.show_wand(r.wand(), 8)
	assert_eq(
		[row.slot_of(0), row.slot_of(1), row.slot_of(2), row.slot_of(3)],
		[
			WorldReader.SLOT_PATTERN,
			WorldReader.SLOT_SECONDARY,
			WorldReader.SLOT_ELEMENT,
			WorldReader.SLOT_NONE
		]
	)
	assert_eq(row.level_text(0), "Lv 1 · Pattern", "the tag joins the level line")
	assert_eq(row.level_text(3), "", "a trigger: no tag")
	assert_eq(
		BuildPage.slot_counts_text(self, r.wand()),
		"Form: Orbs  ·  Pattern 1/1  ·  Secondary 1/2  ·  Element 1/2"
	)
	TranslationServer.set_locale("es")
	assert_eq(
		BuildPage.slot_counts_text(self, r.wand()),
		"Forma: Orbes  ·  Patrón 1/1  ·  Secundaria 1/2  ·  Elemento 1/2"
	)
	var page := BuildPage.new()
	add_child_autofree(page)
	page.open(r.wand(), 8)
	assert_string_contains(page.note_text(), "Patrón 1/1")
