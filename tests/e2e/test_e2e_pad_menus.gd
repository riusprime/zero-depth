extends GutTest
## Every menu works on a pad (v0.2.0 PLAN L3, owner: "for controller you can't press A or X"): the d-pad and the
## left stick move focus, and pad A (Xbox A / PS Cross, both JOY_BUTTON_A) presses the focused button. Input
## events only.


func after_each() -> void:
	for a in [&"pause", &"ui_accept", &"ui_down", &"ui_up"]:
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


func test_pad_a_plays_and_pause_goes_home() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_eq(_focused(main).name, &"Play", "Play has focus at boot")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(
		main.get_node_or_null("UI/UtilityPicker"), "pad A on Play opens the utility picker"
	)
	assert_null(main.get_node_or_null("UI/MainMenu"))
	await _press(e, JOY_BUTTON_A)
	assert_true(main.is_playing(), "pad A on the focused utility starts the arena")
	await e.frames(3)
	await _press(e, JOY_BUTTON_START)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Start pauses")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Restart", "d-pad down moves focus to Restart run")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"MainMenu", "and on to Main menu")
	await _press(e, JOY_BUTTON_A)
	await e.frames(2)
	assert_false(main.is_playing(), "pad A on Main menu ends the stage")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))


func test_pad_a_resumes_from_pause() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)
	await _press(e, JOY_BUTTON_A)
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
	assert_eq(_focused(main).name, &"Back")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "pad A on Back returns to the main menu")
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Credits")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/CreditsView"), "pad A on Credits opens the credits")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "pad A on Back leaves the credits")


func test_pad_back_from_the_utility_picker() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)
	var picker := main.get_node_or_null("UI/UtilityPicker")
	assert_not_null(picker)
	for k in 8:
		await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"Back", "the d-pad walks down to Back")
	await _press(e, JOY_BUTTON_A)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "pad A on Back returns to the main menu")


func test_pad_a_on_the_end_panel() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await _press(e, JOY_BUTTON_A)
	await _press(e, JOY_BUTTON_A)
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel, "standing still, you die")
	if panel == null:
		return
	await _press(e, JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focused(main).name, &"MainMenu")
	await _press(e, JOY_BUTTON_A)
	await e.frames(2)
	assert_false(main.is_playing(), "pad A on the end panel's Main menu goes home")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))
