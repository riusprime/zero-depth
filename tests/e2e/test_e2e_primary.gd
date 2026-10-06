extends GutTest
## The primary through real input (PLAN v0.1.0 Step 2): a click swings, a hold-and-release fires a bolt, on the
## mouse and on the pad's right trigger.


func after_each() -> void:
	Input.action_release(&"primary")


func _player_bolts(w: World) -> int:
	var n := 0
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			n += 1
	return n


func test_click_swings_and_hold_fires_a_bolt_with_the_mouse() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	e.mouse_button(MOUSE_BUTTON_LEFT, true)
	e.mouse_button(MOUSE_BUTTON_LEFT, false)
	await e.frames(2)
	assert_gt(e.world().swing_t, 0, "a click swings")
	await e.frames(30)
	e.mouse_button(MOUSE_BUTTON_LEFT, true)
	await e.frames(55)
	assert_true(PlayerKit.charging(e.world()), "holding charges")
	e.mouse_button(MOUSE_BUTTON_LEFT, false)
	await e.frames(3)
	assert_eq(_player_bolts(e.world()), 1, "release fires a bolt")


func test_the_right_trigger_does_the_same() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await e.frames(2)
	assert_gt(e.world().swing_t, 0, "the trigger swings")
	await e.frames(55)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await e.frames(3)
	assert_eq(_player_bolts(e.world()), 1, "releasing the trigger fires a bolt")
