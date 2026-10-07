extends GutTest
## The shake option reaches the camera (PLAN v0.1.0 Step 6).


func test_shake_off_in_the_profile_turns_the_camera_shake_off() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["shake"] = "off"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	await e.start_from_menu()
	assert_false(main.view.rig.shake_enabled)


func test_shake_is_on_by_default() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_true(main.view.rig.shake_enabled)
