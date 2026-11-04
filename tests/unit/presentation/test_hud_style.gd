extends GutTest
## v0.3.0 UI (PLAN L21, L23, L24): the HUD style helper builds every piece in every style; the danger meter maps
## tiers and progress to lit marks and progress with no text; the low-HP warning turns on below 30 % of max HP
## and off again above it. v0.3.5 F15: the calm HUD; plain labels (no ghost copies, no glitch), thin bars.
## v0.5.5 A5 (owner pick): the HUD ships in B "Ember stone" (stone slabs, ember line, red HP bar), the corner minimap
## has no black background, and the menus wear C "Cold glass" (MenuStyle) with no build cards beside them.


func after_each() -> void:
	HudStyle.current = HudStyle.DEFAULT
	HudStyle.reduced_motion = false


func _world() -> World:
	var w := World.new(9, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	return w


## v0.10.5 O6 (owner P4): the bar fills with the tier and its progress, full at FULL_TIER.
func test_the_danger_bar_fills_with_tier_and_progress() -> void:
	assert_eq(DangerMeter.fill_of(0, 0.0), 0.0, "the floor's start: empty")
	assert_almost_eq(DangerMeter.fill_of(2, 0.5), 2.5 / DangerMeter.FULL_TIER, 0.0001)
	assert_eq(DangerMeter.fill_of(DangerMeter.FULL_TIER, 0.0), 1.0, "full at the full tier")
	assert_eq(DangerMeter.fill_of(DangerMeter.FULL_TIER + 6, 0.9), 1.0, "capped past it")
	assert_eq(DangerMeter.fill_of(-3, -1.0), 0.0)
	assert_false(DangerMeter.is_full(DangerMeter.FULL_TIER - 1))
	assert_true(DangerMeter.is_full(DangerMeter.FULL_TIER))


func test_the_danger_bar_runs_green_to_yellow_to_red() -> void:
	var low := DangerMeter.color_at(0.0)
	var mid := DangerMeter.color_at(0.5)
	var high := DangerMeter.color_at(1.0)
	assert_true(low.is_equal_approx(DangerMeter.GREEN))
	assert_true(mid.is_equal_approx(DangerMeter.YELLOW))
	assert_true(high.is_equal_approx(DangerMeter.RED))
	assert_gt(low.g, low.r, "empty is green")
	assert_gt(high.r, high.g * 2.0, "full is red")
	var m := DangerMeter.new()
	add_child_autofree(m)
	m.set_danger(DangerMeter.FULL_TIER, 0.0)
	assert_true(m.bar_color().is_equal_approx(DangerMeter.RED), "the full bar is red")


func test_the_full_bar_blinks_slowly_and_holds_steady_red_under_reduced_motion() -> void:
	var m := DangerMeter.new()
	add_child_autofree(m)
	m.set_danger(DangerMeter.FULL_TIER - 1, 0.9)
	assert_false(m.blinking(), "not full: no blink")
	assert_eq(m.level(), 1.0)
	m.set_danger(DangerMeter.FULL_TIER, 0.0)
	assert_true(m.blinking(), "full: it blinks")
	var seen := PackedFloat32Array()
	for k in 120:
		m._process(1.0 / 60.0)
		seen.append(m.level())
	var lo := 1.0
	for v in seen:
		lo = minf(lo, v)
	assert_almost_eq(lo, DangerMeter.BLINK_LOW, 0.02, "it dims to BLINK_LOW within 2 s")
	assert_lte(DangerMeter.BLINK_HZ, 1.0, "slowly: at most once a second")
	HudStyle.reduced_motion = true
	assert_false(m.blinking(), "reduced motion: no blink")
	for k in 30:
		m._process(1.0 / 60.0)
		assert_eq(m.level(), 1.0, "steady")
	assert_true(m.bar_color().is_equal_approx(DangerMeter.RED), "steady red")


func test_the_hazard_stripes_are_a_generated_diagonal_tile() -> void:
	var t := DangerMeter.stripes()
	assert_not_null(t)
	var img := t.get_image()
	assert_eq(img.get_size(), Vector2i(DangerMeter.STRIPE, DangerMeter.STRIPE))
	assert_eq(img.get_pixel(0, 0).r, 1.0, "a light band")
	assert_almost_eq(img.get_pixel(DangerMeter.STRIPE - 1, 0).r, DangerMeter.STRIPE_DARK, 0.01)
	assert_eq(img.get_pixel(1, 2), img.get_pixel(2, 1), "the bands run diagonally")


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
	assert_almost_eq(m.fill(), 0.3 / DangerMeter.FULL_TIER, 0.0001)
	m.set_danger(1, 0.0)
	assert_true(m.pulsing(), "a new tier pulses")
	assert_almost_eq(m.fill(), 1.0 / DangerMeter.FULL_TIER, 0.0001)
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
	# v0.10.5 W3-O17: the shipped style is Astral (the owner's W3-O13b pick, 2026-11-04); EMBER was A5's pick B.
	assert_eq(HudStyle.DEFAULT, HudStyle.Style.ASTRAL, "the owner's W3-O13b pick")
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(WorldReader.new(_world()))
	for l in hud.find_children("*", "Label", true, false):
		assert_eq(
			l.get_children().filter(func(c: Node) -> bool: return c is Label).size(),
			0,
			"%s has no ghost copies" % l.name
		)
		# v0.5.5 A4: the pick cards' titles are coloured capitals (v0.8.0 MU: carved on the stone tablet,
		# StoneCard); every other HUD label stays plain type.
		# v0.8.0 N8: the tablet's face hangs from the card's pivot (StoneCard → CardFx → Pivot → Face → Title)
		var card_title := l.name == &"Title" and l.get_parent().get_parent().get_parent() is CardFx
		# v0.10.5 W3-O17: Astral's titles (W3-O16's headings and plates) are Cinzel capitals by design
		var f := l.get_theme_font(&"font") as FontVariation
		var astral_title := f != null and f.base_font == AstralCardArt.serif().base_font
		if not astral_title:
			assert_eq((l as Label).uppercase, card_title, "%s is plain type" % l.get_path())
	assert_lte(Hud.BAR.y, 12.0, "a thin HP bar (v0.9.5 HU: 15 percent bigger than 10)")
	assert_lte(DangerMeter.SIZE.y, 16.0, "a slim danger meter")
	assert_lte(BossBar.BAR.y, 10.0, "a thin boss bar")
	var f := HudStyle.font(true)
	assert_eq(f.spacing_glyph, 0, "no wide tracking")
	assert_eq(f.variation_transform, Transform2D.IDENTITY, "no slant or stretch")


## v0.5.5 A5: "ingame UI, heat, health and minimap from B": the HP and top plates are ember-lit stone slabs, HP is a
## red bar, and the warning still visibly changes the fill. v0.10.5 W3-O17: EMBER is no longer the default; it is
## still a style, built here on purpose.
func test_the_ember_stone_hud() -> void:
	HudStyle.current = HudStyle.Style.EMBER
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(WorldReader.new(_world()))
	var hp := hud.find_child("HpPlate", true, false) as HudFrame
	var top := hud.find_child("TopPlate", true, false) as HudFrame
	assert_eq(hp.style, HudStyle.Style.EMBER)
	assert_true(hp.ember, "the HP slab carries the ember line")
	assert_true(top.ember, "so does the top slab")
	assert_eq(hud.hp_bar().color, HudStyle.HP_RED, "HP is a red bar (B)")
	assert_eq(HudStyle.text_color(), HudStyle.EMBER_TEXT, "warm type")
	hud.hp_bar().warn = true
	assert_ne(hud.hp_bar().fill_color(), HudStyle.HP_RED, "the low-HP pulse shows on a red bar")
	var pts := HudStyle.plate_points(Rect2(0, 0, 200, 60))
	assert_eq(pts.size(), 8, "a chamfered (chipped) slab, not a rectangle")


## v0.10.5 W3-O17 (owner, 2026-11-04: "and what about the rest of the UI? it should match the new style"; UI style
## Astral, W3_O13_UI_STYLE_G2.md round 2): the HUD is unboxed (no slab), the HP bar is one continuous moon-blue bar with
## the HP medallion at its left end and the weapon's name over it, the warning still changes the fill and tints the
## medallion, the type is Astral's (Cinzel titles, Astral text colour), and nothing orange is left in the HUD's tokens.
func test_the_astral_hud() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	var w := _world()
	var r := WorldReader.new(w)
	hud.sync(r)
	await wait_process_frames(2)
	var hp := hud.find_child("HpPlate", true, false) as HudFrame
	assert_eq(hp.style, HudStyle.Style.ASTRAL)
	assert_eq(hud.hp_bar().style, HudStyle.Style.ASTRAL, "the continuous Astral bar")
	assert_eq(hud.hp_bar().color, HudStyle.A_HP, "HP is Astral's moon-blue")
	assert_eq(HudStyle.text_color(), HudStyle.A_TEXT)
	var medal := hud.find_child("HpMedal", true, false) as Control
	assert_not_null(medal, "the HP medallion")
	assert_almost_eq(
		medal.get_global_rect().end.x, hp.get_global_rect().position.x, 1.0, "at the bar's left end"
	)
	assert_lt(medal.get_global_rect().end.y, hud.get_viewport_rect().size.y, "on screen")
	var floor_label := hud.find_child("FloorLabel", true, false) as Label
	assert_eq(
		floor_label.get_theme_font(&"font"), HudStyle.serif(600, 5), "the floor line in Cinzel"
	)
	w.actors.hp[0] = r.player_max_hp() / 5
	hud.sync(r)
	for k in 7:
		hud._process(1.0 / 60.0)
	assert_ne(hud.hp_bar().fill_color(), HudStyle.A_HP, "the low-HP pulse shows on the bar")
	assert_gt(medal.get("warn"), 0.0, "and on the medallion")
	for c: Color in [HudStyle.A_HP, HudStyle.A_ACCENT, HudStyle.A_METAL, HudStyle.A_TEXT]:
		assert_gt(c.b, c.r, "a cool token")
	assert_gt(DangerMeter.YELLOW.b, 0.5, "the ramp's middle is a pale gold, not an orange")


## v0.5.5 A5 (owner: "we should remove the black background tho"): the corner minimap draws no panel; the full map
## (held) keeps its backdrop. Its lines draw over a dark halo so they read on light floors.
func test_the_corner_minimap_has_no_black_background() -> void:
	var m := Minimap.new()
	add_child_autofree(m)
	assert_false(m.corner.draws_backdrop(), "the corner map floats over the game")
	assert_true(m.full_map.draws_backdrop(), "the held full map keeps its dimmed panel")
	assert_gt(MinimapStyle.SHADOW.a, 0.0, "a dark halo under the lines")


## v0.5.5 A5: the heat meter keeps its straight bar, ticks and colours (HeatLooks is the shared table other steps
## read); only its frame changed.
func test_the_heat_bar_keeps_its_colours() -> void:
	assert_eq(HeatLooks.HOT, Color("#FFA63A"))
	assert_eq(HeatLooks.OVERCLOCK, Color("#FF4A1A"))
	assert_eq(HeatLooks.COOL, Color("#4E6A80"))
	assert_lte(HeatMeter.BAR_H, 8.0, "still a thin straight bar")


## v0.5.5 A5: the pause menu is a left-aligned list over the blurred game, with a key hint, the run's line, and no
## build cards beside it; v0.8.0 MU (owner O14, G2 "menu style B"): on a carved stone slab, Ember stone.
func test_the_ember_stone_pause_menu() -> void:
	var m := PauseMenu.new()
	add_child_autofree(m)
	assert_eq(m.theme, MenuStyle.theme(), "the Ember stone theme")
	assert_not_null(m.find_child("MenuBackdrop", true, false), "the game blurred behind")
	assert_true(m.slab.get_theme_stylebox("panel") is StoneBox, "the list sits on a stone slab")
	assert_true(m.slab.is_ancestor_of(m.box), "the rows are on the slab")
	assert_eq(m.find_children("*", "StoneCard", true, false).size(), 0, "no cards beside it")
	assert_eq(m.find_children("*", "BuildCard", true, false).size(), 0, "no build cards beside it")
	for c in m.box.get_children():
		if c is Button:
			assert_eq(
				(c as Button).alignment, HORIZONTAL_ALIGNMENT_LEFT, "%s left-aligned" % c.name
			)
	assert_eq((m.footer.get_node("Hint") as Label).text, "UI_PAUSE_HINT")
	m.show_run(2, 222.0, 87, 146)
	assert_eq(m.run_line.text, tr("UI_PAUSE_RUN") % [2, 3, 42, 87, 146])
	m.focus_first()
	await wait_frames(2)
	assert_true(m.marker.visible, "the ember diamond marks the focused row")
	assert_lt(m.marker.global_position.x, (m.box.get_node("Resume") as Button).global_position.x)


func test_the_danger_meter_shows_the_tier_number_from_tier_4_and_turns_red_at_10() -> void:
	assert_false(DangerMeter.shows_number(3))
	assert_true(DangerMeter.shows_number(4))
	assert_false(DangerMeter.is_full(9))
	assert_true(DangerMeter.is_full(10), "v0.10.5 O6: red (and full) at 10")
	var m := DangerMeter.new()
	add_child_autofree(m)
	m.set_danger(3, 0.0)
	m.set_danger(7, 0.0)
	assert_true(m.pulsing(), "a rise pulses")
	assert_almost_eq(m.fill(), 0.7, 0.0001)
	assert_eq(m.tier_shown(), 7)
	assert_eq(tr("HUD_DANGER_TIER") % 7, "×7")


## v0.9.5 HU (owner: the HP plate "15% bigger"; the spells "the same height as the health bar, but lower both about 2
## cm"): the HP bar 345 x 12, its type 16 pt, the plate and the ability squares on one bottom line 20 px up.
func test_the_hp_plate_is_15_percent_bigger_and_shares_the_squares_bottom_line() -> void:
	assert_eq(Hud.BAR, Vector2(345, 12))
	assert_almost_eq(Hud.BAR.x / 300.0, 1.15, 0.001)
	assert_eq(Hud.HP_FONT, 16)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(WorldReader.new(_world()))
	await wait_process_frames(3)
	var plate := hud.get("_hp_frame") as Control
	var bottom := hud.get_viewport_rect().size.y - Hud.BOTTOM_LINE
	assert_almost_eq(
		plate.get_global_rect().end.y, bottom, 1.0, "the plate sits 20 px above the bottom"
	)
	assert_lte(plate.size.y, AbilitySquares.SIDE, "no taller than a square: both bottom-aligned")
	assert_eq(hud.hp_bar().size.x, 345.0)
	assert_false(hud.has_method("_pip"), "the old blue pips are gone")
	var squares := hud.ability_squares
	assert_almost_eq(
		squares.rect_of(&"attack").end.y, bottom, 1.0, "the squares' bottom is the plate's bottom"
	)
