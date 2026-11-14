extends GutTest
## v0.10.5 O6 (owner P4, 2026-11-01: "Danger, plus a separate tag"; D4 flipped from hidden to shown): the depths' answer
## tag (v0.11.0 F12: a heating skull and the multiplier) shows the floor's catch-up m only above ×1; the pause menu
## has the same; WorldReader reads m without writing it; and the curve's shown danger fills smoothly through the
## overtime.

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


func test_the_tag_is_a_skull_and_the_multiplier_in_every_language() -> void:
	var t := DepthsTag.new()
	add_child_autofree(t)
	TranslationServer.set_locale("en")
	t.set_multiplier(1414)
	assert_eq(t.label.text, "×1.41", "the multiplier alone: no sentence")
	assert_eq(t.get_child_count(), 2, "a skull and a label, nothing else")
	TranslationServer.set_locale("es")
	await wait_frames(1)
	assert_eq(t.label.text, "×1.41", "the same in Spanish")


func test_the_level_steps_with_the_multiplier() -> void:
	assert_eq(DepthsTag.level_of(1001), 1)
	assert_eq(DepthsTag.level_of(1150), 1, "up to 1.15")
	assert_eq(DepthsTag.level_of(1151), 2)
	assert_eq(DepthsTag.level_of(1400), 2, "up to 1.40")
	assert_eq(DepthsTag.level_of(1414), 3)
	assert_eq(DepthsTag.level_of(1800), 3, "up to 1.80")
	assert_eq(DepthsTag.level_of(2500), 4, "up to 2.50")
	assert_eq(DepthsTag.level_of(2501), 5, "above")
	assert_eq(DepthsTag.level_of(9000), 5)
	var t := DepthsTag.new()
	add_child_autofree(t)
	t.set_multiplier(1414)
	assert_eq(t.level(), 3)


func test_the_five_colours_get_darker_so_they_read_without_hue() -> void:
	assert_eq(DepthsTag.COLORS.size(), 5)
	for k in 4:
		assert_gt(
			DepthsTag.COLORS[k].get_luminance(),
			DepthsTag.COLORS[k + 1].get_luminance(),
			"step %d is lighter than step %d" % [k + 1, k + 2]
		)
	assert_eq(DepthsTag.color_of(1100), DepthsTag.COLORS[0])
	assert_eq(DepthsTag.color_of(3000), DepthsTag.COLORS[4])


func test_the_pause_line_is_the_same_skull_and_multiplier() -> void:
	TranslationServer.set_locale("en")
	var p := PauseMenu.new()
	add_child_autofree(p)
	p.show_depths(1000)
	assert_false(p.depths_line.visible, "×1: no line")
	p.show_depths(1414)
	assert_true(p.depths_line.visible)
	assert_eq(p.depths_line.label.text, "×1.41", "no sentence")
	assert_eq(p.depths_line.level(), 3)


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
