extends GutTest
## v0.10.5 O6 (owner P4, 2026-11-01: "Danger, plus a separate tag"; D4 flipped from hidden to shown): the depths' answer
## tag shows the floor's catch-up m only above ×1, in en and es; the pause menu's one sentence follows it; WorldReader
## reads m without writing it; and the curve's shown danger fills smoothly through the overtime.

var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func test_the_multiplier_is_written_with_at_most_two_decimals() -> void:
	assert_eq(DepthsTag.multiplier_text(1414), "1.41")
	assert_eq(DepthsTag.multiplier_text(1400), "1.4")
	assert_eq(DepthsTag.multiplier_text(1050), "1.05")
	assert_eq(DepthsTag.multiplier_text(2000), "2")


func test_the_tag_shows_only_above_x1() -> void:
	assert_false(DepthsTag.shows(1000), "×1: hidden")
	assert_false(DepthsTag.shows(900))
	assert_true(DepthsTag.shows(1001))
	var t := DepthsTag.new()
	add_child_autofree(t)
	assert_false(t.visible, "hidden until read")
	t.set_multiplier(1000)
	assert_false(t.visible)
	t.set_multiplier(1414)
	assert_true(t.visible)
	t.set_multiplier(1000)
	assert_false(t.visible, "a new floor at ×1 hides it again")


func test_the_tag_words_it_in_english_and_spanish() -> void:
	var t := DepthsTag.new()
	add_child_autofree(t)
	TranslationServer.set_locale("en")
	t.set_multiplier(1414)
	assert_eq(t.label.text, "The depths answer ×1.41")
	TranslationServer.set_locale("es")
	await wait_frames(1)
	assert_eq(t.label.text, "Las profundidades responden ×1.41", "a language switch words it again")
	t.short = true
	t.set_multiplier(1500)
	assert_eq(t.label.text, "×1.5", "the short form (mockup A) is the number alone")


func test_the_pause_line_explains_it_in_one_sentence() -> void:
	TranslationServer.set_locale("en")
	var p := PauseMenu.new()
	add_child_autofree(p)
	p.show_depths(1000)
	assert_false(p.depths_line.visible, "×1: no line")
	p.show_depths(1414)
	assert_true(p.depths_line.visible)
	assert_string_starts_with(p.depths_line.text, "The depths answer ×1.41:")
	assert_eq(
		p.depths_line.text.count("."), 2, "one sentence (the decimal point and the full stop)"
	)
	TranslationServer.set_locale("es")
	await wait_frames(1)
	assert_string_starts_with(p.depths_line.text, "Las profundidades responden ×1.41:")


func test_the_reader_gives_the_floors_m_and_writes_nothing() -> void:
	var w := World.new(9, PlayerTable.starting_values())
	var r := WorldReader.new(w)
	assert_eq(r.catch_up_permille(), 1000, "no catch-up table: ×1")
	w.catch_up_table = CatchUpTable.new()
	w.catch_up.enemy = 1414
	var before := w.state_hash()
	assert_eq(r.catch_up_permille(), 1414)
	assert_eq(w.state_hash(), before, "reading changes nothing")


func test_the_shown_danger_fills_smoothly_through_the_overtime() -> void:
	var c := CurveTable.new()
	c.starts = PackedInt32Array([0, 600])
	c.tier_permille = PackedInt32Array([0, 3500])
	c.holds = PackedByteArray([0, 0])
	c.overtime_starts = PackedInt32Array([1200, 1800])
	c.overtime_step = 600
	c.overtime_max_tier = 20
	for ticks in [0, 300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700]:
		var shown := c.shown_permille_at(ticks)
		assert_eq(
			shown / 1000, c.tier_permille_at(ticks) / 1000, "the same whole tier at %d" % ticks
		)
		assert_gte(shown, c.tier_permille_at(ticks))
	assert_eq(c.shown_permille_at(900), 3750, "the peak's 3.5 halfway to the overtime's 4")
	assert_eq(c.shown_permille_at(1500), 4500, "halfway between two overtime starts")
	assert_eq(c.shown_permille_at(2100), 5500, "halfway through a step past the last start")
	var last := 0
	for ticks in range(0, 3000, 30):
		var s := c.shown_permille_at(ticks)
		assert_gte(s, last, "never falls (tick %d)" % ticks)
		last = s
