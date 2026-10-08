extends GutTest
## The biome lighting in the real game (v0.5.9 Step 1): a run's floor is lit by its biome's mood, and Options >
## Display > Lighting quality, reached with the pad from the pause menu, turns contact shadow and bounce light off
## on the running floor at once. Input events only (Input.parse_input_event); reads of nodes are fine.


func after_each() -> void:
	for a in [&"pause", &"ui_accept", &"ui_down", &"ui_up", &"ui_left", &"ui_right", &"ui_cancel"]:
		Input.action_release(a)


func _press(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _pad_to(e: E2e, main: Main, button: JoyButton, target: StringName, limit: int = 16) -> bool:
	for k in limit:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await _press(e, button)
	return _focused(main) != null and _focused(main).name == target


func test_the_floor_is_lit_by_its_mood_and_options_lower_the_lighting() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(5)
	var stage := main.view.stage
	assert_not_null(stage.mood, "the floor's biome gives the stage its mood")
	assert_eq(stage.environment.tonemap_mode, Environment.TONE_MAPPER_AGX)
	assert_true(stage.environment.ssao_enabled, "High by default: contact shadow on")
	await _press(e, JOY_BUTTON_START)
	assert_true(await _pad_to(e, main, JOY_BUTTON_DPAD_DOWN, &"Options"), "d-pad to Options")
	await _press(e, JOY_BUTTON_A)
	assert_true(await _pad_to(e, main, JOY_BUTTON_DPAD_DOWN, &"TabDisplay"), "d-pad to Display")
	await _press(e, JOY_BUTTON_DPAD_RIGHT)
	assert_true(
		await _pad_to(e, main, JOY_BUTTON_DPAD_DOWN, &"lighting"), "down to Lighting quality"
	)
	await _press(e, JOY_BUTTON_A)
	assert_eq(GameSettings.get_value(main.profile, "lighting"), "low", "pad A steps High -> Low")
	assert_false(stage.environment.ssao_enabled, "the running floor drops SSAO at once")
	assert_false(stage.environment.ssil_enabled, "and SSIL")
	assert_eq(get_errors().size(), 0, "no engine or script error")
