extends GutTest
## v0.3.0 UI (PLAN L21, L23, L24): the HUD style helper builds every piece in every style; the danger meter maps
## tiers and progress to lit marks and progress with no text; the low-HP warning turns on below 30 % of max HP
## and off again above it. v0.3.5 F15: the calm HUD; plain labels (no ghost copies, no glitch), thin bars.


func after_each() -> void:
	HudStyle.current = HudStyle.DEFAULT
	HudStyle.reduced_motion = false


func _world() -> World:
	var w := World.new(9, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	return w


func test_danger_meter_maps_tiers_to_lit_chevrons() -> void:
	assert_eq(DangerMeter.lit_chevrons(0), 1, "tier 1 lights the first chevron")
	assert_eq(DangerMeter.lit_chevrons(2), 3)
	assert_eq(DangerMeter.lit_chevrons(DangerMeter.CHEVRONS - 1), DangerMeter.CHEVRONS)
	assert_eq(DangerMeter.lit_chevrons(DangerMeter.CHEVRONS + 4), DangerMeter.CHEVRONS, "capped")
	assert_false(DangerMeter.overdrive(DangerMeter.CHEVRONS - 1))
	assert_true(DangerMeter.overdrive(DangerMeter.CHEVRONS), "past the last chevron: overdrive")


func test_danger_meter_maps_progress_to_segments() -> void:
	assert_eq(DangerMeter.lit_segments(0.0), 0)
	assert_eq(DangerMeter.lit_segments(0.55), 5)
	assert_eq(DangerMeter.lit_segments(0.999), DangerMeter.SEGMENTS - 1)
	assert_eq(DangerMeter.lit_segments(1.0), DangerMeter.SEGMENTS)
	assert_eq(DangerMeter.lit_segments(-1.0), 0)


func test_danger_runs_cool_to_hot() -> void:
	assert_eq(DangerMeter.heat(0), 0.0)
	assert_eq(DangerMeter.heat(DangerMeter.CHEVRONS - 1), 1.0)
	var cool := HudStyle.danger_color(0.0)
	var hot := HudStyle.danger_color(1.0)
	assert_gt(cool.b, cool.r, "tier 1 is cool (blue over red)")
	assert_gt(hot.r, hot.b, "the top tier is hot (red over blue)")


func test_the_reader_gives_progress_toward_the_next_tier() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	assert_eq(r.tier_progress(), 0.0, "no spawn director, no progress")
	w.spawner = SpawnTable.new()
	w.run_ticks = w.spawner.tier_ticks + w.spawner.tier_ticks / 2
	assert_eq(r.tier(), 1)
	assert_almost_eq(r.tier_progress(), 0.5, 0.001)


func test_the_meter_pulses_when_the_tier_rises_and_shows_no_text() -> void:
	var m := DangerMeter.new()
	add_child_autofree(m)
	m.set_danger(0, 0.3)
	assert_false(m.pulsing(), "the first reading is not a rise")
	assert_eq(m.chevrons_lit(), 1)
	assert_eq(m.segments_lit(), 3)
	m.set_danger(1, 0.0)
	assert_true(m.pulsing(), "a new tier pulses")
	assert_eq(m.chevrons_lit(), 2)
	for k in 60:
		m._process(1.0 / 60.0)
	assert_false(m.pulsing(), "the pulse fades")
	m.set_danger(0, 0.0)
	assert_false(m.pulsing(), "a new floor's reset is not a rise")
	assert_eq(
		m.find_children("*", "Label", true, false).size(), 0, "no numbers: the meter has no text"
	)


func test_low_hp_threshold_is_thirty_percent() -> void:
	assert_false(HudStyle.low_hp(30, 100), "30 % is not below 30 %")
	assert_true(HudStyle.low_hp(29, 100))
	assert_true(HudStyle.low_hp(1, 100))
	assert_false(HudStyle.low_hp(0, 100), "dead is the recap's business")
	assert_true(HudStyle.low_hp(35, 120), "35 / 120 = 29 %")
	assert_false(HudStyle.low_hp(36, 120), "36 / 120 = 30 %")


func test_the_hud_blinks_red_below_thirty_percent_and_stops_above() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	var mx := r.player_max_hp()
	hud.sync(r)
	assert_false(hud.low_hp_warning(), "full HP: no warning")
	assert_false(hud.vignette().visible)
	w.actors.hp[0] = mx * 3 / 10 - 1
	hud.sync(r)
	assert_true(hud.low_hp_warning(), "below 30 %: the bar pulses red and the edge glows")
	assert_true(hud.vignette().visible)
	assert_ne(hud.hp_bar().fill_color(), hud.hp_bar().color, "the fill is tinted red")
	w.actors.hp[0] = mx * 3 / 10
	hud.sync(r)
	assert_false(hud.low_hp_warning(), "back at 30 %: it stops")
	assert_false(hud.vignette().visible)
	assert_eq(hud.hp_bar().fill_color(), hud.hp_bar().color)


func test_the_pulse_holds_steady_in_calm_mode() -> void:
	HudStyle.reduced_motion = true
	assert_eq(HudStyle.pulse(0.0), 1.0)
	assert_eq(HudStyle.pulse(0.37), 1.0)
	HudStyle.reduced_motion = false
	assert_ne(HudStyle.pulse(0.0), HudStyle.pulse(0.25), "it moves otherwise")


func test_every_style_builds_every_piece() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	for s: int in HudStyle.Style.values():
		HudStyle.current = s as HudStyle.Style
		var f := HudStyle.font(true)
		assert_true(f is FontVariation, "style %d has a font" % s)
		assert_not_null(f.base_font, "built on the bundled TTF")
		var hud := Hud.new()
		add_child_autofree(hud)
		hud.sync(r)
		hud.show_floor(1, "BIOME_RUINS")
		for k in 3:
			hud._process(1.0 / 60.0)
		assert_eq(hud.danger_meter().style, s, "the HUD's pieces take the current style")
		assert_eq(hud.hp_bar().style, s)
		assert_true(hud.floor_card_showing())


func test_the_calm_hud_has_plain_labels_and_thin_bars() -> void:
	assert_eq(HudStyle.DEFAULT, HudStyle.Style.BARE, "the owner's pick (2026-10-07)")
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(WorldReader.new(_world()))
	for l in hud.find_children("*", "Label", true, false):
		assert_eq(
			l.get_children().filter(func(c: Node) -> bool: return c is Label).size(),
			0,
			"%s has no ghost copies" % l.name
		)
		# v0.5.5 A4: the pick cards' titles are coloured capitals, as in the owner's card reference
		# (docs/roadmap/v0.5.5/refs/card_style_reference.webp); every other HUD label stays plain type.
		var card_title := l.name == &"Title" and l.get_parent().get_parent() is CrystalCard
		assert_eq((l as Label).uppercase, card_title, "%s is plain type" % l.name)
	assert_lte(Hud.BAR.y, 10.0, "a thin HP bar")
	assert_lte(DangerMeter.SIZE.y, 16.0, "a slim danger meter")
	assert_lte(BossBar.BAR.y, 10.0, "a thin boss bar")
	var f := HudStyle.font(true)
	assert_eq(f.spacing_glyph, 0, "no wide tracking")
	assert_eq(f.variation_transform, Transform2D.IDENTITY, "no slant or stretch")
