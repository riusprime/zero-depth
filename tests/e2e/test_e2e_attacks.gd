extends GutTest
## Melee and shooting on separate buttons, through real input (PLAN v0.1.0 Step 7b; owner, 2026-10-07):
## left click / left trigger swings; right click / right trigger held shoots.


func after_each() -> void:
	for a in [&"primary", &"shoot"]:
		Input.action_release(a)


func _player_bolts(w: World) -> int:
	var n := 0
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			n += 1
	return n


func test_mouse_left_swings_right_held_shoots() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	e.mouse_button(MOUSE_BUTTON_LEFT, true)
	e.mouse_button(MOUSE_BUTTON_LEFT, false)
	await e.frames(2)
	assert_gt(e.world().swing_t, 0, "a left click swings")
	assert_eq(_player_bolts(e.world()), 0, "and doesn't shoot")
	await e.frames(30)
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.frames(20)
	assert_gte(_player_bolts(e.world()), 2, "holding right click keeps shooting")
	assert_eq(e.world().swing_t, 0, "and doesn't swing")
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)


func test_left_trigger_swings_right_trigger_shoots() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await e.frames(2)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	assert_gt(e.world().swing_t, 0, "the left trigger swings")
	await e.frames(30)
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await e.frames(20)
	assert_gte(_player_bolts(e.world()), 2, "holding the right trigger keeps shooting")
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
