extends GutTest


func after_each() -> void:
	Input.action_release(&"move_right")


func test_camera_follows_the_player() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	e.key(KEY_D, true)
	await e.frames(60)
	e.key(KEY_D, false)
	await e.frames(60)
	var player := SimPlane.to_3d(e.world().player_pos())
	var cam := main.view.rig.position
	assert_gt(player.length(), 3.0, "the player walked away from the centre")
	assert_lt(
		Vector2(cam.x - player.x, cam.z - player.z).length(),
		1.6,
		"the camera caught up (dead zone 1.5 m)"
	)
