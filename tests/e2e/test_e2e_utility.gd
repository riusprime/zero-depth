extends GutTest
## Pick a utility before play and use it with real input (PLAN v0.1.0 Step 3).


func after_each() -> void:
	Input.action_release(&"utility")


func test_guard_is_the_default_pick_and_right_mouse_raises_it() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	assert_eq(e.world().player.utility, PlayerTable.Utility.GUARD)
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.frames(3)
	assert_true(e.world().guarding(), "holding right mouse guards")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	await e.frames(2)
	assert_false(e.world().guarding())


func test_pick_blink_and_the_left_trigger_blinks_and_it_is_remembered() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)  # Play
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/UtilityPicker"), "the picker comes before the arena")
	await e.tap(KEY_DOWN)  # Guard -> Blink
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(e.world().player.utility, PlayerTable.Utility.BLINK)
	var start := e.world().player_pos()
	e.joy_axis(JOY_AXIS_RIGHT_X, 1.0)
	await e.frames(3)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await e.frames(3)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	await e.frames(2)
	assert_gt(e.world().blink_cd, 0, "blinked")
	assert_gt((e.world().player_pos() - start).length(), 1.0, "moved by the blink")
	assert_eq(main.profile.section("loadout")["utility"], "blink", "remembered")
