extends GutTest
## v0.10.5 W3-S17: every glyph of the overlevel badge (UI_CARD_OVERLEVEL) exists in the font the level label uses.


func _check(font: Font, text: String, who: String) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 32:
			continue
		assert_true(font.has_char(c), "%s lacks U+%04X in '%s'" % [who, c, text])


func test_overlevel_glyphs_exist_in_card_font() -> void:
	var f: Font = HudStyle.font(true)
	for loc in ["en", "es"]:
		TranslationServer.set_locale(loc)
		_check(f, tr("UI_CARD_OVERLEVEL"), "level font (" + loc + ")")
	TranslationServer.set_locale("en")
	gut.p("has_char U+2726 level font: %s" % f.has_char(0x2726))
	gut.p("has_char U+25C6 level font: %s" % f.has_char(0x25C6))
