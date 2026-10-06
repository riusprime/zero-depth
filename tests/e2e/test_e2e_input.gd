extends GutTest
## Move, aim and dash on both devices through real input events (PLAN v0.0.1 Step 9).


func after_each() -> void:
	for a in [
		&"move_up",
		&"move_down",
		&"move_left",
		&"move_right",
		&"aim_up",
		&"aim_down",
		&"aim_left",
		&"aim_right",
		&"dash"
	]:
		Input.action_release(a)


func _moved_angle(e: E2e, from: Vector2) -> int:
	return Kin.angle_of(e.world().player_pos() - from)


func test_kbm_w_moves_screen_up() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	var start := e.world().player_pos()
	e.key(KEY_W, true)
	await e.frames(30)
	e.key(KEY_W, false)
	assert_gt((e.world().player_pos() - start).length(), 1.5, "moved")
	assert_almost_eq(_moved_angle(e, start), 1536, 20, "W is screen-up: sim angle 1536 (135°)")


func test_pad_left_stick_moves_screen_up() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	var start := e.world().player_pos()
	e.joy_axis(JOY_AXIS_LEFT_Y, -1.0)
	await e.frames(30)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	assert_gt((e.world().player_pos() - start).length(), 1.5, "moved")
	assert_almost_eq(_moved_angle(e, start), 1536, 20, "stick up is screen-up")


func test_tap_inside_one_frame_still_dashes() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	e.key(KEY_SPACE, true)
	e.key(KEY_SPACE, false)  # released before any tick ran
	await e.frames(2)
	assert_true(e.world().is_dashing() or e.world().dash_cooldown_left > 0, "the dash happened")


func test_mouse_and_stick_aim_agree() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var player := e.world().player_pos()
	var screen := main.view.rig.camera.unproject_position(
		SimPlane.to_3d(player + Vector2(3, 1), 0.5)
	)
	await e.mouse_to(screen)
	await e.frames(3)
	var received := main.get_viewport().get_mouse_position()
	assert_almost_eq(
		received.distance_to(screen), 0.0, 1.0, "the game received the intended position"
	)
	var pi: PlayerInput = main.view.get_node("PlayerInput")
	var target: Vector2 = pi.mouse_world(received)
	var mouse_aim := e.world().aim_angle
	assert_almost_eq(
		mouse_aim, Kin.angle_of(target - player), 2, "the mouse aims at the point under it"
	)
	# The stick is screen-relative: aim the same direction by rotating it -45° into screen space.
	var d := (target - player).normalized()
	var stick := Vector2(d.x + d.y, d.y - d.x) * 0.70710678
	e.joy_axis(JOY_AXIS_RIGHT_X, stick.x)
	e.joy_axis(JOY_AXIS_RIGHT_Y, -stick.y)
	await e.frames(3)
	assert_almost_eq(e.world().aim_angle, mouse_aim, 1, "pad and mouse aim agree within one unit")
	e.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	e.joy_axis(JOY_AXIS_RIGHT_Y, 0.0)


func test_remapped_key_from_profile_moves_the_player() -> void:
	var profile := ProfileStore.new("")
	InputRemap.set_binding(profile, &"move_up", [[&"key", KEY_I]])
	var e := E2e.new(self)
	await e.boot(profile)
	await e.start_from_menu()
	var start := e.world().player_pos()
	e.key(KEY_W, true)
	await e.frames(10)
	e.key(KEY_W, false)
	assert_almost_eq((e.world().player_pos() - start).length(), 0.0, 0.01, "W no longer moves up")
	e.key(KEY_I, true)
	await e.frames(20)
	e.key(KEY_I, false)
	assert_gt((e.world().player_pos() - start).length(), 1.0, "I does")
	InputDefaults.apply()
