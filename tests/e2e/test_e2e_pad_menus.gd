extends GutTest
## Every menu works on a pad (v0.2.0 PLAN L3, owner: "for controller you can't press A or X"): the d-pad and the
## left stick move focus, and pad A (Xbox A / PS Cross, both JOY_BUTTON_A) presses the focused button. Input
## events only. v0.9.0 HB (owner Q27): Play goes to the hub; the left stick walks to a station and pad X (interact)
## uses it.


func after_each() -> void:
	E2e.center_sticks()
	for a in [&"pause", &"ui_accept", &"ui_down", &"ui_up", &"interact"]:
		Input.action_release(a)


func _press(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


## The left stick pushed down past the deadzone and back to centre: one focus step. Godot moves focus on a stick
## event only if Input saw it as "just pressed" in the same frame, and an event parsed inside a physics frame
## counts for the next one; a real pad's events arrive between frames, so the push is sent from a process frame.
func _stick_down(e: E2e) -> void:
	await get_tree().process_frame
	e.joy_axis(JOY_AXIS_LEFT_Y, 1.0)
	await e.frames(1)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await e.frames(1)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _wait_for_end(e: E2e, main: Main) -> EndPanel:
	for k in 4000:
		await e.frames(1)
		var p := main.get_node_or_null("UI/EndPanel")
		if p != null:
			return p
	return null


## Pad A on Play (the hub), the stick to a station, pad X at it.
func _pad_to_station(e: E2e, main: Main, id: StringName) -> void:
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.hub, "pad A on Play goes to the hub")
	assert_true(await HubWalk.new(e).walk_to(id), "the left stick walks to the %s" % id)
	await _press(e, JOY_BUTTON_X)


func test_pad_a_plays_and_pause_goes_home() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_eq(_focused(main).name, &"Play", "Play has focus at boot")
	await _pad_to_station(e, main, &"portal")
	assert_not_null(
		main.get_node_or_null("UI/BuildPicker"),
		"pad X at the Portal Machine opens the build screen"
	)
	assert_null(main.get_node_or_null("UI/MainMenu"))
	await _press(e, JOY_BUTTON_A)
	await e.loaded()
	assert_true(
		main.is_playing(), "pad A on a build starts the run (no utility pick since v0.4.0 BS)"
	)
	await e.frames(3)
	await _press(e, JOY_BUTTON_START)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Start pauses")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Build", "d-pad down moves focus to Build (v0.6.5 WN2)")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Restart", "then Restart run")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Options", "then Options (v0.3.0 O)")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Codex", "then the Codex (v0.7.5 CX)")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Hub", "and on to the Rune Ring (v0.9.0 HB, owner 2026-10-23)")
	await _press(e, JOY_BUTTON_A)
	await e.frames(2)
	assert_false(main.is_playing(), "pad A on it ends the stage")
	assert_not_null(main.hub, "back in the hub")
	assert_null(main.get_node_or_null("UI/MainMenu"))


func test_pad_a_resumes_from_pause() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _pad_to_station(e, main, &"portal")
	await _press(e, JOY_BUTTON_A)  # Blade
	await e.loaded()
	# v0.8.0 N11: the world holds at tick 0 under the loading cover until the hero lands, so pause once landed.
	assert_true(await e.landed(), "the hero landed")
	await _press(e, JOY_BUTTON_START)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"))
	await _press(e, JOY_BUTTON_A)  # Resume has focus
	assert_null(main.get_node_or_null("UI/PauseMenu"), "pad A on Resume closes the pause menu")
	var tick := e.world().tick
	await e.frames(3)
	assert_gt(e.world().tick, tick, "the sim runs again")


func test_stick_moves_focus_and_pad_a_opens_options_and_credits() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _stick_down(e)
	assert_eq(_focused(main).name, &"Options", "the left stick moves focus down")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/OptionsMenu"), "pad A on Options opens Options")
	assert_eq(_focused(main).name, &"TabAudio", "the first category has focus (v0.3.0 O)")
	await _press(e, JOY_BUTTON_B)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "pad B goes back to the main menu")
	await _press(e, JOY_BUTTON_DPAD_UP)
	assert_eq(_focused(main).name, &"Play")
	# v0.9.5 RS1: the Credits are a main-menu item (Play, Options, Credits, Quit).
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Credits", "the d-pad reaches Credits")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/CreditsView"), "pad A on Credits opens them")
	await _press(e, JOY_BUTTON_A)
	assert_null(main.get_node_or_null("UI/CreditsView"), "pad A on Back leaves the credits")
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "back at the main menu")


## v0.4.0 BS (F11): the utility picker is gone; the build screen is the last menu before the run.
func test_pad_back_from_the_build_screen() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _pad_to_station(e, main, &"portal")
	assert_not_null(main.get_node_or_null("UI/BuildPicker"))
	assert_null(main.get_node_or_null("UI/UtilityPicker"), "no utility picker any more")
	await _press(e, JOY_BUTTON_B)
	assert_null(main.get_node_or_null("UI/BuildPicker"), "pad B on the build screen closes it")
	assert_not_null(main.hub, "back in the hub (v0.9.0 HB)")


func test_pad_a_on_the_end_panel() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _pad_to_station(e, main, &"portal")
	await _press(e, JOY_BUTTON_A)  # Blade
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel, "standing still, you die")
	if panel == null:
		return
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Hub")
	await _press(e, JOY_BUTTON_A)
	await e.frames(2)
	assert_false(main.is_playing(), "pad A on the end panel's Hub ends the run")
	assert_not_null(main.hub, "and goes to the hub (v0.9.0 HB)")
