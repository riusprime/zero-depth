extends GutTest
## v0.11.0 O10 (owner Q19; SPELLS.md "Readability"): what the spells draw. The HUD: four small squares above the ability
## squares, hidden until a spell is held; a held slot shows its spell, a cooldown sweep from full (just cast) down to 0
## (ready), and a flash the frame it casts. The world: each cast drawn once in its element's colour (never red or
## purple). The pick: a spell card's kind line, level badge and Replace line. Reads only.

const W := preload("res://tests/support/mx4_world.gd")


func _world(items: Array, enemies: Array) -> World:
	var w := W.world(&"gun", items, enemies)
	w.reward_table = ContentCompiler.compile_rewards(W.repo().get_def(&"rewards", &"floor"))
	w.spell_tables = SpellCompiler.compile(W.repo(), w.item_tables)
	w.spell_rules = SpellCompiler.compile_rules(W.repo())
	return w


func test_the_squares_show_the_spell_its_sweep_and_the_flash_on_cast() -> void:
	var w := _world([&"frost_core"], [[Vector2(2, 0), 100000]])
	var reader := WorldReader.new(w)
	var screen: Control = add_child_autofree(Control.new())
	screen.size = Vector2(1920, 1080)
	var sq := SpellSquares.new()
	screen.add_child(sq)
	sq.sync(reader)
	assert_false(sq.visible, "no spell: hidden")
	Offers.apply(w, Offers.spell_code(Spells.FROST_NOVA))
	sq.sync(reader)
	assert_true(sq.visible, "a spell held: shown")
	assert_eq(sq.slot_count(), 4, "four squares")
	assert_eq(sq.spell_id(0), &"spell_frost_nova")
	assert_eq(sq.spell_id(1), &"", "the rest empty")
	assert_eq(sq.sweep(0), 0.0, "ready")
	w.step(W.frame())
	sq.sync(reader)
	assert_true(sq.flashing(0), "it cast: the square flashes")
	assert_almost_eq(sq.sweep(0), 1.0, 0.01, "just cast: the sweep is full")
	for k in 360:
		w.step(W.frame())
	sq.sync(reader)
	assert_almost_eq(sq.sweep(0), 0.5, 0.01, "half way after 6 s")
	await get_tree().process_frame
	await wait_seconds(SpellSquares.FLASH_SECONDS + 0.05)
	assert_false(sq.flashing(0), "the flash is short")
	var r := sq.rect_of(0)
	var ab := 1080.0 - AbilitySquares.MARGIN_BOTTOM - AbilitySquares.SIDE
	assert_lt(r.end.y, ab, "above the ability squares")
	assert_gt(r.position.y, 1080.0 - Hud.ITEMS_LIFT, "below the item row")
	assert_false(SpellSquares.wedge(r, 0.5).is_empty(), "a sweep wedge to draw")


func test_each_cast_is_drawn_once_in_its_element_colour() -> void:
	var w := _world(
		[&"frost_core", &"ember_core", &"storm_core"],
		[[Vector2(2, 0), 100000], [Vector2(0, 6), 100000], [Vector2(0.5, 6.5), 100000]]
	)
	for k in [Spells.FROST_NOVA, Spells.FIREBALL, Spells.SKY_STRIKE]:
		Offers.apply(w, Offers.spell_code(k))
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	var reader := WorldReader.new(w)
	for k in 80:
		w.step(W.frame())
		view.sync(reader)
	var drawn := view.spell_drawn()
	assert_eq(int(drawn.get(WorldReader.SPELL_FX_NOVA, 0)), 1, "one nova")
	assert_eq(int(drawn.get(WorldReader.SPELL_FX_BURST, 0)), 1, "one burst")
	assert_eq(int(drawn.get(WorldReader.SPELL_FX_BOLT, 0)), 3, "three bolts")
	for e in 5:
		var c := SpellLooks.color(e)
		var red := c.r > 0.8 and c.g < 0.35 and c.b < 0.35
		var purple := c.r > 0.45 and c.b > 0.45 and c.g < 0.35
		assert_false(purple, "element %d: never purple" % e)
		if e != WorldReader.SPELL_ELEMENT_BLEED:
			assert_false(red, "element %d: never red" % e)


## v0.11.0 O11: every spell of the fifteen has its look in the world (a cast or a lasting shape, drawn) and its icon,
## four at a time at Lv 5 (the slots) with a pack in reach and a dash now and then.
func test_every_spell_has_a_look_and_an_icon() -> void:
	var cards := [&"frost_core", &"ember_core", &"storm_core", &"venom_core", &"shared_bleed"]
	var seen := {}
	for g: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14]]:
		var enemies := []
		for k in 8:
			enemies.append([Vector2(1.5 + (k % 4) * 0.9, -1.5 + (k / 4) * 2.5), 100000])
		var w := _world(cards, enemies)
		w.pair_table = WandCompiler.pairs(W.repo())
		w.loop = 2
		for k: int in g:
			for n in 5:
				Offers.apply(w, Offers.spell_code(k))
		for i in range(1, 9):
			Engines.add_bleed(w, i, 2, 1)  # TEST HELPER: bleeding, so Leech has a target
		var view: AttackFormView = add_child_autofree(AttackFormView.new())
		var reader := WorldReader.new(w)
		for t in 240:
			var d := InputFrame.DASH if t == 60 else 0
			w.step(W.frame(d, d, 0, Vector2i(0, 127) if t == 60 else Vector2i.ZERO))
			view.sync(reader)
		for k: Variant in view.spell_seen():
			seen[int(k)] = true
	for k in 15:
		var id: StringName = SpellDefinition.SPELLS[k]
		assert_true(seen.has(k), "%s: drawn in the world" % id)
		assert_true(SpellLooks.has_icon(id), "%s: an icon" % id)


func test_the_pick_card_names_the_spell_its_level_and_what_it_replaces() -> void:
	var w := _world([&"ember_core"], [])
	var reader := WorldReader.new(w)
	var code := Offers.spell_code(Spells.FIREBALL)
	var face := PickPanel.card_face(self, reader, code)
	assert_eq(int(face["type"]), WorldReader.CARD_SPELL)
	assert_eq(face["title"], tr("SPELL_FIREBALL"))
	assert_eq(face["tier_text"], tr("UI_CARD_SPELL_LEVEL") % 1)
	assert_eq(face["color"], SpellLooks.color(WorldReader.SPELL_ELEMENT_FIRE))
	Offers.apply(w, code)
	face = PickPanel.card_face(self, reader, code)
	assert_eq(face["tier_text"], tr("UI_CARD_SPELL_LEVEL") % 2, "held: taking it again gives Lv 2")
	assert_eq(face["form_line"], tr("SPELL_FIREBALL_LV2"), "the level's line")
	assert_eq(int(face["held_level"]), 1)
	w.spell_rules.slots = 1  # TEST HELPER: one slot, so a second spell meets it full
	Offers.apply(w, W.item(w, &"frost_core"))
	face = PickPanel.card_face(self, reader, Offers.spell_code(Spells.FROST_NOVA))
	assert_eq(
		face["replaces_text"], tr("UI_SLOT_REPLACES") % tr("SPELL_FIREBALL"), "Replaces Fireball"
	)
