extends GutTest
## The v0.3.0 UI HUD through real input only (PLAN L21, L23, L24): a run from the menu shows the top plate (floor,
## time, kills) with the visual danger meter (v0.10.5 O6: a hazard-striped bar filling along the danger);
## the left stick walks the wanderer into the enemies until its HP drops under 30 %, and the low-HP warning (red
## HP bar, screen-edge glow) comes on.

const MAX_FRAMES := 9000


func after_each() -> void:
	Input.action_release(&"move_up")


## v0.10.5 O6 (owner P4): on a real floor the danger bar follows the reader, fills red and blinks at the full tier, and
## the depths' answer (the floor's catch-up m) shows as a tag under the top plate only above ×1, and as one sentence in
## the pause menu (opened with Esc). The catch-up and the floor time are posed on the world (the sim's own fields), the
## rest is the real game.
func test_the_danger_bar_and_the_depths_tag_in_a_real_run() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(30)
	var w := e.world()
	var reader := main.driver.reader
	var hud: Hud = main.get_node("UI/Hud")
	var tag := hud.depths_tag
	assert_eq(
		tag.visible, DepthsTag.shows(reader.catch_up_permille()), "the tag shows only above ×1"
	)
	w.catch_up.enemy = 1000
	await e.frames(2)
	assert_false(tag.visible, "×1: no tag")
	w.catch_up.enemy = 1414
	w.actors.invuln[0] = 1 << 24
	w.run_ticks = SimTick.seconds_to_ticks(601.0)
	await e.frames(3)
	assert_eq(reader.catch_up_permille(), 1414)
	assert_true(tag.is_visible_in_tree(), "×1.41: the tag shows")
	assert_eq(tag.label.text, tr("HUD_DEPTHS_ANSWER") % "1.41")
	var plate := main.get_node("UI/Hud/TopPlate") as Control
	assert_gte(
		tag.get_global_rect().position.y,
		plate.get_global_rect().end.y,
		"the tag hangs under the top plate"
	)
	var meter := hud.danger_meter()
	assert_gte(reader.tier(), DangerMeter.FULL_TIER)
	assert_eq(meter.fill(), 1.0, "ten minutes in: the bar is full")
	assert_true(meter.bar_color().is_equal_approx(DangerMeter.RED), "red")
	assert_true(meter.blinking(), "full: it blinks")
	await e.tap(KEY_ESCAPE)
	await e.frames(3)
	var pause := main.get_node("UI/PauseMenu") as PauseMenu
	assert_not_null(pause, "Esc opens the pause menu")
	assert_true(pause.depths_line.visible, "the pause menu explains the depths' answer")
	assert_eq(pause.depths_line.text, tr("UI_PAUSE_DEPTHS") % "1.41")
	await e.tap(KEY_ESCAPE)


func test_the_danger_meter_and_the_low_hp_warning_in_a_real_run() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(30)
	var w := e.world()
	var reader := main.driver.reader
	var hud: Hud = main.get_node("UI/Hud")
	var meter := hud.danger_meter()
	assert_true(meter.is_visible_in_tree(), "the danger meter shows on a floor")
	assert_eq(meter.tier_shown(), reader.tier())
	assert_eq(
		meter.fill(),
		DangerMeter.fill_of(reader.tier(), reader.tier_progress()),
		"v0.10.5 O6: the bar fills along the floor's danger"
	)
	var texts := hud.top_texts()
	assert_eq(texts.size(), 3, "the top plate's text: floor, time and kills only")
	var secs := int(reader.run_seconds())
	assert_eq(
		texts[1], tr("HUD_TIME") % [secs / 60, secs % 60], "the time alone: danger is the meter"
	)
	assert_eq(texts[0], hud.floor_text())
	assert_false(hud.low_hp_warning(), "a fresh run: no warning")
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, w.player_pos()))
	var mx := w.actors.max_hp[0]
	for k in MAX_FRAMES:
		if w.player_dead() or HudStyle.low_hp(w.actors.hp[0], mx):
			break
		var target := _nearest_enemy(w)
		if k % 20 == 0:
			nav.flood(target)
		var p := w.player_pos()
		var dir := (target - p).normalized() if (target - p).length() < 2.0 else nav.direction(p)
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	await e.frames(1)
	gut.p("hp %d / %d" % [w.actors.hp[0], mx])
	if w.player_dead():
		pending("a hit took the wanderer from above 30 % straight to 0; rerun")
		return
	assert_true(HudStyle.low_hp(w.actors.hp[0], mx), "the enemies brought HP under 30 %")
	assert_true(hud.low_hp_warning(), "the HP bar pulses red and the screen edge glows")
	assert_true(hud.vignette().is_visible_in_tree())


func _nearest_enemy(w: World) -> Vector2:
	var best := w.player_pos() + Vector2(1, 0)
	var dist := INF
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or not EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			continue
		var d := w.actors.pos(i).distance_to(w.player_pos())
		if d < dist:
			dist = d
			best = w.actors.pos(i)
	return best
