extends GutTest
## v0.8.0 TX3: the owner's element glyphs (ElementGlyphs). Every card whose modifiers name an element (an ELEMENT
## op) is in the table with that element, and nothing else is; every element a modifier may name has a glyph on the
## owner's sheets; an elemental card's socket wears its glyph (InlaySocket's badge) and a plain card's does not.

const CARD_DIRS := ["res://data/items", "res://data/stat_cards", "res://data/abilities"]


func _modifiers() -> Dictionary:
	var out := {}
	for path in ContentScanner.scan("res://data/modifiers"):
		var m: Resource = load(path)
		out[m.id] = m
	return out


## Card id → the first element its modifiers name (&"" for none).
func _elements() -> Dictionary:
	var mods := _modifiers()
	var out := {}
	for dir: String in CARD_DIRS:
		for path in ContentScanner.scan(dir):
			var card: Resource = load(path)
			var found := &""
			var ids: Array = card.get("modifiers") if card.get("modifiers") != null else []
			for mid: StringName in ids:
				if found != &"" or not mods.has(mid):
					continue
				found = _first_element(mods[mid].ops)
			out[card.id] = found
	return out


## The first element an ELEMENT op in `ops` names, a HOOK op's own `hook_ops` included (&"" for none).
func _first_element(ops: Array) -> StringName:
	for op: ModifierOpDefinition in ops:
		if op.op == ModifierOpDefinition.Op.ELEMENT:
			return op.element
		var inner := _first_element(op.hook_ops)
		if inner != &"":
			return inner
	return &""


func test_every_elemental_card_is_in_the_table_with_its_element() -> void:
	var el := _elements()
	assert_gt(el.size(), 40, "the cards were found")
	var n := 0
	for id: StringName in el:
		assert_eq(ElementGlyphs.element_of(id), el[id], "%s wears its modifiers' element" % id)
		if el[id] != &"":
			n += 1
	assert_eq(n, ElementGlyphs.ELEMENT_OF.size(), "the table lists only elemental cards")


func test_every_element_has_a_glyph_on_the_owners_sheets() -> void:
	for e: StringName in ModifierOpDefinition.ELEMENTS:
		var r := ElementGlyphs.region(e)
		assert_eq(r.size(), 2, "%s has a glyph" % e)
		assert_eq((r[0] as Texture2D).get_size(), Vector2(512, 512), "%s: its sheet" % e)
		assert_eq((r[1] as Rect2).size, Vector2(256, 256), "%s: one quarter" % e)


func test_an_elemental_cards_socket_wears_its_glyph() -> void:
	var s := InlaySocket.new()
	add_child_autofree(s)
	s.size = Vector2(80, 80)
	s.show_item(&"ember_edge", Color.ORANGE, Color.ORANGE)
	assert_eq(s.element, &"ember")
	assert_true(s.shows_glyph(), "a flame on Ember Edge")
	s.show_item(&"glacial_edge", Color.CYAN, Color.CYAN)
	assert_eq(s.element, &"frost")
	s.show_item(&"swift_feet", Color.GREEN, Color.GREEN)
	assert_eq(s.element, &"", "a plain card")
	assert_false(s.shows_glyph())
	s.show_item(&"ember_edge", Color.ORANGE, Color.ORANGE)
	s.size = Vector2(30, 30)
	assert_false(s.shows_glyph(), "none on a socket too small to read it")


## v0.8.0 N1 (owner O54, D42 "(a)"): the Legendary items (and only they) are in LEGENDARY; the Blade items with no
## element that aren't Legendary (and only they) are in BLADE_PLAIN.
func test_the_spare_glyphs_lists_follow_the_content() -> void:
	var el := _elements()
	var legendary := {}
	var plain := {}
	for path in ContentScanner.scan("res://data/items"):
		var card: ItemDefinition = load(path)
		if card.rarity == ItemDefinition.Rarity.LEGENDARY:
			legendary[card.id] = true
		elif card.requires_weapon == &"blade" and el.get(card.id, &"") == &"":
			plain[card.id] = true
	assert_gt(legendary.size(), 0, "legendary cards found")
	assert_gt(plain.size(), 10, "plain Blade cards found")
	assert_eq(legendary.size(), ElementGlyphs.LEGENDARY.size(), "as many Legendary cards as listed")
	for id: StringName in legendary:
		assert_true(ElementGlyphs.LEGENDARY.has(id), "%s is Legendary: the star burst" % id)
	for id: StringName in ElementGlyphs.LEGENDARY:
		assert_true(legendary.has(id), "%s is listed Legendary but isn't" % id)
	for id: StringName in plain:
		assert_true(
			ElementGlyphs.BLADE_PLAIN.has(id), "%s is a plain Blade card: the crossed blades" % id
		)
	for id: StringName in ElementGlyphs.BLADE_PLAIN:
		assert_true(plain.has(id), "%s is listed as a plain Blade card but isn't" % id)


func test_a_card_wears_the_star_the_element_or_the_crossed_blades() -> void:
	assert_eq(ElementGlyphs.glyph_of(&"inferno_core"), &"star", "Legendary over its element")
	assert_eq(ElementGlyphs.glyph_of(&"trigger_on_hit_twice"), &"star")
	assert_eq(
		ElementGlyphs.glyph_of(&"ember_edge"), &"ember", "an elemental Blade card keeps its element"
	)
	assert_eq(ElementGlyphs.glyph_of(&"flurry"), &"blades", "a plain Blade card")
	assert_eq(ElementGlyphs.glyph_of(&"swift_feet"), &"", "a plain non-Blade card wears none")
	for g: StringName in [&"star", &"blades"]:
		assert_eq(ElementGlyphs.region(g).size(), 2, "%s is on the owner's sheet" % g)
	var s := InlaySocket.new()
	add_child_autofree(s)
	s.size = Vector2(80, 80)
	s.show_item(&"flurry", Color.WHITE, Color.WHITE)
	assert_eq(s.element, &"blades")
	assert_true(s.shows_glyph(), "the crossed blades on Flurry")
	s.show_item(&"chain_blast", Color.ORANGE, Color.ORANGE)
	assert_eq(s.element, &"star")
	assert_true(s.shows_glyph(), "the star burst on Chain Blast")
