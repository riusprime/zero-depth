extends GutTest
## v0.9.0 AS (owner Q5, Q14); AS2 (G2 AS = B "ribbon + pips"; owner "Let me choose"): the slot tag in the pick card's
## rarity line and the ribbon across it ("Replaces Twin", or "Choose one to replace" for a full Secondary or Element
## slot; PickPanel.card_face → PickSlot → StoneCard, the same face the shop, events and the Swap panel use), clear of
## the card's name and icon; the slot tag on the wand's tiles (WandRow), the slot pips (SlotPips) on the Build page and
## the Swap panel (a Blade run: only the Pattern's); a Swap for a full Secondary slot limited to its two cards; in
## English and Spanish; the ribbon burns and is whole again. Views only: they read the sim.

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


func _rect(c: Control) -> Rect2:
	return Rect2(c.position, c.size)


func test_the_pick_card_wears_its_slot_and_a_ribbon_in_both_languages() -> void:
	var w := _world([&"gun_twin", &"gun_pierce", &"gun_homing"])
	var r := WorldReader.new(w)
	var want := {
		"en": ["Pattern", "Replaces Twin", "Secondary", "Choose one to replace", "Element"],
		"es": ["Patrón", "Reemplaza a Gemelo", "Secundaria", "Elige cuál reemplazar", "Elemento"],
	}
	for lang: String in want:
		TranslationServer.set_locale(lang)
		var s := PickSlot.new(0)
		add_child_autofree(s)
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"halo_shot")))
		assert_eq([s.slot_text(), s.replaces_text()], [want[lang][0], want[lang][1]], lang)
		assert_true(
			s.card.tier_text().begins_with(want[lang][0] + " · "), "the tag leads the rarity line"
		)
		assert_eq(s.card.ribbon.shown_text(), want[lang][1].to_upper(), "the ribbon shouts")
		var title := s.card.find_child("Title", true, false) as Control
		var ribbon := _rect(s.card.ribbon).grow(-2.0)
		assert_false(ribbon.intersects(_rect(title)), "%s: the ribbon clears the name" % lang)
		assert_false(ribbon.intersects(_rect(s.card.socket)), "%s: and the icon" % lang)
		assert_lt(ribbon.position.y, s.card.gem_rect().position.y, "above the rarity gem")
		assert_true(s.card.text_fits(), "the sentence keeps clear of it")
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"gun_ricochet")))
		assert_eq(
			[s.slot_text(), s.replaces_text()], [want[lang][2], want[lang][3]], "%s: choose" % lang
		)
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"storm_core")))
		assert_eq([s.slot_text(), s.replaces_text()], [want[lang][4], ""], "%s: room left" % lang)
		assert_false(s.card.ribbon.visible, "no ribbon with room")
		s.show_card(PickPanel.card_face(self, r, WandLab.code(w, &"trigger_on_hit")))
		assert_eq(s.slot_text(), "", "%s: a free card has no tag" % lang)


func test_the_replaced_ribbon_burns_and_comes_back_whole() -> void:
	var w := _world([&"gun_twin"])
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(PickPanel.card_face(self, WorldReader.new(w), WandLab.code(w, &"gun_ring")))
	assert_false(s.replaced_burning())
	s.burn_replaced(0.5)
	assert_true(s.replaced_burning() or HudStyle.reduced_motion, "it burns (N8's dissolve)")
	s.burn_replaced(0.0)
	assert_false(s.replaced_burning(), "whole again")


func test_the_wand_tiles_and_the_pips_read_the_slots() -> void:
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
	var page := BuildPage.new()
	add_child_autofree(page)
	page.open(r.wand(), 8)
	assert_true(page.pips.visible)
	assert_eq(
		page.pips.text(),
		"Form: Orbs ●  ·  Pattern ●  ·  Secondary ●○  ·  Element ●○",
		"Form 1, Pattern 1, 2, 2"
	)
	TranslationServer.set_locale("es")
	page.pips.show_wand(r.wand())
	assert_eq(page.pips.text(), "Forma: Orbes ●  ·  Patrón ●  ·  Secundaria ●○  ·  Elemento ●○")
	var blade := _blade_world()
	var pips := SlotPips.new()
	add_child_autofree(pips)
	pips.show_wand(WorldReader.new(blade).wand())
	assert_eq(pips.counts().size(), 1, "a Blade run: only the Pattern's pip")
	assert_eq(int(pips.counts()[0][0]), WorldReader.SLOT_PATTERN)


func _blade_world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.floor_index = 3
	w.run_floor = 3
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.slot_table = WandCompiler.slots(_repo, w.item_tables)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	return w


func test_a_full_secondary_slot_opens_the_swap_limited_to_its_two_cards() -> void:
	TranslationServer.set_locale("en")
	var w := _world([&"gun_pierce", &"ember_core", &"gun_homing"])
	var ric := WandLab.code(w, &"gun_ricochet")
	assert_true(BuildSlots.needs_swap(w, ric))
	BuildSlots.open_swap(w, ric, BuildSlots.Source.REWARD, 0)
	var panel := SwapPanel.new()
	add_child_autofree(panel)
	panel.sync(WorldReader.new(w))
	assert_true(panel.visible)
	assert_eq(panel.choices(), [0, 2] as Array[int], "Pierce and Homing, not Ember Core")
	assert_eq(panel.row.focus, 0, "the focus starts on the first of them")
	assert_true(panel.pips.visible, "the pips over the wand")
	assert_string_contains(panel.title_text(), "Secondary")
	assert_eq(panel.row.tile(1).modulate.a, 0.5, "Ember Core's tile is dimmed")
	assert_eq(panel.row.tile(0).modulate, Color.WHITE)
