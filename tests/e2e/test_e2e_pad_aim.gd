extends GutTest
## v0.8.0 N9 (owner O65, "The pad aim should it go where the hero faces."): on a pad, a shot before the right stick
## has aimed goes where the hero faces (the last move direction), not east (the old Vector2.RIGHT default, into the
## wall 1.6 m east of the spawn). Driven through main.tscn with Input.parse_input_event only.


func _press(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


func _sticks_off(e: E2e) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)


func after_each() -> void:
	for a in [&"shoot", &"primary", &"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func test_a_pad_shot_before_the_right_stick_goes_the_way_the_hero_walked() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)  # Play
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_not_null(picker)
	await _press(e, JOY_BUTTON_DPAD_RIGHT)
	assert_eq(picker.focused_id(), &"gun")
	await _press(e, JOY_BUTTON_A)  # Gun: the run starts
	assert_true(main.is_playing())
	var w := e.world()
	assert_eq(w.player.weapons, PlayerTable.WEAPON_GUN, "a Gun run")
	var start := w.player_pos()
	# Walk west with the left stick (open floor; the right stick is never touched), then let go.
	e.stick_toward(Vector2.LEFT)
	await e.frames(20)
	e.stick_toward(Vector2.ZERO)
	await e.frames(10)
	assert_lt(w.player_pos().x, start.x - 0.5, "the hero walked west")
	var west := Kin.angle_of(Vector2.LEFT)
	assert_eq(int(e.main.driver.reader.player_build()["facing"]), west, "and faces west")
	# The right trigger alone, the stick still untouched: the bolts fly west, the way the hero faces.
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var seen := 0
	var wrong := 0
	for f in 20:
		await e.frames(1)
		for i in w.projectiles.size():
			if w.projectiles.team[i] != ActorStore.TEAM_PLAYER:
				continue
			var v := Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i])
			if v.length() < 0.001:
				continue
			seen += 1
			if v.normalized().dot(Vector2.LEFT) < 0.9:
				wrong += 1
	_sticks_off(e)
	assert_gt(seen, 0, "the right trigger shoots")
	assert_eq(wrong, 0, "every bolt flies west (not east, the old untouched-stick aim)")
	assert_eq(w.aim_angle, west, "the aim is the hero's facing")
