extends GutTest
## v0.10.5 O3 (owner L6, 2026-11-01: "we still have to work on the last phase"; O3_PRISM.md): the Prism's last phase
## through main.tscn with real input only. The Playground (F10 -> Playground, the Gun), F1: God mode (Player tab), then
## "The Prism's last phase" (Spawn tab) jumps the fight to the Prism just under 50 % HP. With the Gun's fire held on
## her: her Facet Lances come (facets at the rim, then lance lines and strikes drawn) while her shield turns every shot
## away, then she kneels: her core shows and the shots land; the hero is still standing.

const LIMIT := 4200

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


func test_the_prisms_last_phase_from_the_playground() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	_scale = await _e._mouse_scale()
	await _e.open_playground_picker()
	await _e.tap(KEY_RIGHT)  # the Gun
	await _e.tap(KEY_ENTER)
	await _e.frames(4)
	assert_not_null(main.playground, "in the Playground")
	var w := _e.world()
	await _e.tap(KEY_F1)
	await _tab(main, 3)
	await _press(main, "God")
	await _tab(main, 1)
	await _press(main, "FinalPrismLast")
	await _e.tap(KEY_F1)
	var reader := main.driver.reader
	var frames := 0
	while frames < 300:
		var b := reader.boss_index()
		if b >= 0 and reader.actor_state(b) != WorldReader.STATE_SPAWN:
			break
		await _e.frames(1)
		frames += 1
	var i := reader.boss_index()
	assert_eq(reader.actor_kind(i), WorldReader.KIND_PRISM, "the Prism")
	assert_lt(reader.actor_hp(i) * 2, reader.actor_max_hp(i), "under half her HP: her last phase")
	var views := main.view.prism_views
	var aim := _screen(main, reader.actor_pos(i))
	await _e.mouse_to(aim)
	_mouse(aim, MOUSE_BUTTON_RIGHT, true)
	var saw_facets := false
	var saw_lines := false
	var saw_strike := false
	var lance_hp := -1
	var lance_lost := 0
	var saw_core := false
	var kneel_hp := -1
	var kneel_lost := 0
	frames = 0
	while frames < LIMIT:
		await _e.frames(1)
		frames += 1
		i = reader.boss_index()
		if i < 0:
			break
		var hp := reader.actor_hp(i)
		var l := reader.boss_lances(i)
		if not l.is_empty():
			saw_facets = saw_facets or views.last.facets_drawn() > 0
			saw_lines = saw_lines or views.last.lance_lines() > 0
			saw_strike = saw_strike or views.last.lance_strikes() > 0
			if lance_hp >= 0:
				lance_lost += maxi(0, lance_hp - hp)
			lance_hp = hp
		var k := reader.boss_kneel(i)
		if not k.is_empty() and int(k["stage"]) == 1:
			saw_core = saw_core or views.last.core_drawn()
			if kneel_hp >= 0:
				kneel_lost += maxi(0, kneel_hp - hp)
			kneel_hp = hp
		elif kneel_hp >= 0:
			break  # she has risen
	_mouse(aim, MOUSE_BUTTON_RIGHT, false)
	gut.p(
		(
			"O3 e2e: frames %d, lost in the lances %d, in the kneel %d"
			% [frames, lance_lost, kneel_lost]
		)
	)
	assert_true(saw_facets, "the facets at the rim")
	assert_true(saw_lines, "the lances' lines")
	assert_true(saw_strike, "a lance striking")
	assert_eq(lance_lost, 0, "shielded while the lances fly")
	assert_true(saw_core, "her core shows while she kneels")
	assert_gt(kneel_lost, 0, "the shots land while she is down")
	assert_false(w.player_dead(), "the hero still stands")
