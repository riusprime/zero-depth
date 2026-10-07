extends GutTest
## Pick a utility before play and use it with real input (PLAN v0.1.0 Steps 3, 7b): Shift or the left bumper.
## Blink goes the way you're moving.


func after_each() -> void:
	for a in [&"utility", &"move_right", &"move_up"]:
		Input.action_release(a)


func test_guard_is_the_default_pick_and_shift_or_left_bumper_raises_it() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	assert_eq(e.world().player.utility, PlayerTable.Utility.GUARD)
	e.key(KEY_SHIFT, true)
	await e.frames(3)
	assert_true(e.world().guarding(), "holding Shift guards")
	e.key(KEY_SHIFT, false)
	await e.frames(2)
	assert_false(e.world().guarding())
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await e.frames(3)
	assert_true(e.world().guarding(), "holding the left bumper guards")
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, false)


func test_pick_blink_and_it_follows_movement_and_is_remembered() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)  # Play
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/UtilityPicker"), "the picker comes before the arena")
	await e.tap(KEY_DOWN)  # Guard -> Blink
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(e.world().player.utility, PlayerTable.Utility.BLINK)
	e.key(KEY_D, true)  # move screen-right: sim angle 512
	await e.frames(3)
	var start := e.world().player_pos()
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	e.joy_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await e.frames(2)
	e.key(KEY_D, false)
	var moved := e.world().player_pos() - start
	assert_gt(e.world().blink_cd, 0, "blinked")
	assert_gt(moved.length(), 3.0, "a full blink")
	assert_almost_eq(Kin.angle_of(moved), 512, 40, "the way you were moving")
	assert_eq(main.profile.section("loadout")["utility"], "blink", "remembered")
