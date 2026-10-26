extends GutTest
## v0.9.5 TX: what a Pattern or Secondary Gun card does on the form held (FormCardText). Every allowed (form, card)
## pair of data/wand/attack_slots.tres has an en and an es line; a card the form does not allow reads "Does nothing on
## this form"; only the Orbs have no lines. The cells are read from the data, never listed here.

const CSV := "res://locale/strings.csv"
const MAX_EN := 70
const ELEMENTS: Array[StringName] = [
	&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]


func _table() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			out[row[0]] = row
	return out


func _forms() -> Array:
	var out: Array = []
	for r in FormCardText.slots().forms:
		if r.id != &"orbs":
			out.append(r)
	return out


func _pairs() -> Array:
	var out: Array = []
	for r in _forms():
		for c: StringName in r.allowed:
			if ELEMENTS.has(c):
				continue
			out.append([r.id, c])
	return out


func test_every_allowed_pair_is_a_card_with_a_line() -> void:
	var pairs := _pairs()
	assert_gt(pairs.size(), 90, "the data has the cells (101 at FC9)")
	for p: Array in pairs:
		assert_true(FormCardText.CARDS.has(p[1]), "%s on %s is a known card" % [p[1], p[0]])


func test_every_allowed_pair_has_an_en_and_an_es_line() -> void:
	var table := _table()
	for p: Array in _pairs():
		var key := FormCardText.key_for(p[0], p[1])
		assert_true(table.has(key), "%s is in strings.csv" % key)
		if table.has(key):
			assert_false(String(table[key][1]).strip_edges().is_empty(), "%s has en" % key)
			assert_false(String(table[key][2]).strip_edges().is_empty(), "%s has es" % key)


func test_en_lines_are_short() -> void:
	var table := _table()
	for p: Array in _pairs():
		var key := FormCardText.key_for(p[0], p[1])
		if table.has(key):
			assert_lte(String(table[key][1]).length(), MAX_EN, "%s en length" % key)
			assert_lte(String(table[key][2]).length(), MAX_EN, "%s es length" % key)


func test_line_for_returns_the_cells_line_in_each_language() -> void:
	var keep := TranslationServer.get_locale()
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for p: Array in _pairs():
			var line := FormCardText.line_for(p[0], p[1])
			assert_ne(line, "", "%s/%s has a line in %s" % [p[0], p[1], lang])
			assert_ne(line, FormCardText.key_for(p[0], p[1]), "translated, not the key (%s)" % lang)
			assert_ne(line, FormCardText.OFF_KEY)
	TranslationServer.set_locale(keep)


func test_an_off_pair_reads_does_nothing() -> void:
	var keep := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var off := 0
	for r in _forms():
		for c: StringName in FormCardText.CARDS:
			if r.allowed.has(c):
				continue
			off += 1
			assert_eq(
				FormCardText.line_for(r.id, c), "Does nothing on this form", "%s on %s" % [c, r.id]
			)
	assert_gt(off, 0, "some cells are off")
	TranslationServer.set_locale("es")
	assert_eq(FormCardText.line_for(&"laser", &"gun_threadline"), "No hace nada con esta forma")
	TranslationServer.set_locale(keep)


func test_a_pair_is_empty_only_on_the_orbs() -> void:
	for r in FormCardText.slots().forms:
		for c: StringName in FormCardText.CARDS:
			var line := FormCardText.line_for(r.id, c)
			if r.id == &"orbs":
				assert_eq(line, "", "the Orbs have no lines (%s)" % c)
			else:
				assert_ne(line, "", "%s on %s has a line" % [c, r.id])


func test_other_cards_and_the_blade_have_no_line() -> void:
	assert_eq(FormCardText.line_for(&"laser", &"ember_core"), "", "an element core")
	assert_eq(FormCardText.line_for(&"laser", &"gun_bomb"), "", "a form card")
	assert_eq(FormCardText.line_for(&"", &"gun_ring"), "", "no form (the Blade)")
	assert_eq(FormCardText.line_for(&"nope", &"gun_ring"), "", "an unknown form")


func test_the_accent_is_the_form_cards_colour() -> void:
	for r in _forms():
		var c := FormCardText.accent_for(r.id)
		assert_eq(c.a, 1.0, "%s: an opaque colour" % r.id)
		var expect := ItemLooks.color_of_id(r.card)
		assert_true(
			c == expect or c == FormCardText.FALLBACK,
			"%s: its card's colour or the fallback" % r.id
		)
	assert_eq(FormCardText.accent_for(&"nope"), FormCardText.FALLBACK)
