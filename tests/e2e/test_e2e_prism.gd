extends GutTest
## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5, F7): the Prism through main.tscn with real input only. The Playground (the
## main menu's row, the Gun), F1: God mode (Player tab), then the final boss's "Phase 2" button (Spawn tab) jumps the
## fight to the Prism. With the Gun's fire held on her: the Cross's spin-up draws four aim lines, then four beams turn
## while her shield turns every shot away (no HP lost), a bolt's aim line shows, and in the window after (the gold
## ring, the beams out) the shots land; the hero is still standing.

const LIMIT := 1500

var _e: E2e
var _scale := Vector2.ONE


func after_each() -> void:
	if _e != null:
		_mouse(Vector2.ZERO, MOUSE_BUTTON_RIGHT, false)


func _screen(main: Main, p: Vector2) -> Vector2:
	return main.view.rig.camera.unproject_position(SimPlane.to_3d(p, SimPlane.CORE_HEIGHT))


func _press(main: Main, n: String) -> void:
	var b := main.playground.panel.find_child(n, true, false) as Button
	assert_not_null(b, n)
	b.grab_focus()
	await _e.tap(KEY_ENTER)
	await _e.frames(2)


func _mouse(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos / _scale
	ev.global_position = pos / _scale
	_e.send(ev)


func _tab(main: Main, i: int) -> void:
	var tabs := main.playground.panel.tabs
	var bar := tabs.get_tab_bar()
	await _e.click_at(bar.get_global_rect().position + bar.get_tab_rect(i).get_center())
	await _e.frames(2)
	assert_eq(tabs.current_tab, i, "tab %d" % i)


func test_the_prism_from_the_playground_jump() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	for k in 4:  # Play -> Options -> Credits -> Codex -> Playground
		await _e.tap(KEY_DOWN)
	await _e.tap(KEY_ENTER)
	await _e.frames(2)
	await _e.tap(KEY_RIGHT)  # the Gun
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_not_null(main.playground, "in the Playground")
	var w := _e.world()
	await _e.tap(KEY_F1)
	await _tab(main, 3)
	await _press(main, "God")
	await _tab(main, 1)
	await _press(main, "FinalPhase2")
	await _e.tap(KEY_F1)
	assert_false(main.driver.paused, "the game runs")
	var reader := main.driver.reader
	var frames := 0
	while frames < 300:
		var b := reader.boss_index()
		if b >= 0 and reader.actor_state(b) != WorldReader.STATE_SPAWN:
			break
		await _e.frames(1)
		frames += 1
	var i := reader.boss_index()
	assert_gte(i, 0, "a body is here")
	assert_eq(reader.final_phase(), 1, "the jump went to phase 2")
	assert_eq(reader.actor_kind(i), WorldReader.KIND_PRISM, "the Prism")
	var avatar: Node = main.view.actors.actor_node(reader.actor_id(i)).get_meta(&"enemy_avatar")
	assert_true(avatar is PrismAvatar, "drawn as the Prism")
	var views := main.view.prism_views
	var aim := _screen(main, reader.actor_pos(i))
	await _e.mouse_to(aim)
	_mouse(aim, MOUSE_BUTTON_RIGHT, true)  # the Gun fires at her while the button is held
	var saw_aim_lines := false
	var saw_beams := false
	var saw_bolt_line := false
	var spin_hp := -1
	var spin_lost := 0
	var window_hp := -1
	var window_lost := 0
	var windows := 0
	var was_window := false
	frames = 0
	while frames < LIMIT and windows < 1:
		await _e.frames(1)
		frames += 1
		i = reader.boss_index()
		if i < 0:
			break
		var c := reader.boss_cross(i)
		if c.is_empty():
			continue
		var hp := reader.actor_hp(i)
		if c["winding"] and views.aim_count() == 4:
			saw_aim_lines = true
		if not c["winding"] and not c["window"]:
			if views.beam_count() == 4:
				saw_beams = true
			if spin_hp >= 0:
				spin_lost += maxi(0, spin_hp - hp)
			spin_hp = hp
		if views.bolt_line_drawn():
			saw_bolt_line = true
		if c["window"]:
			assert_true(views.window_drawn(), "the window's ring")
			if window_hp >= 0:
				window_lost += maxi(0, window_hp - hp)
			window_hp = hp
		elif was_window:
			windows += 1
		was_window = c["window"]
	_mouse(aim, MOUSE_BUTTON_RIGHT, false)
	assert_true(saw_aim_lines, "the spin-up's four aim lines")
	assert_true(saw_beams, "four beams turning")
	assert_true(saw_bolt_line, "a fast bolt's aim line")
	assert_eq(spin_lost, 0, "shielded while the Cross turns: every shot turned away")
	assert_gt(window_lost, 0, "in the window the shots land")
	assert_eq(windows, 1, "a whole Cross and its window")
	assert_false(w.player_dead(), "the hero still stands")
