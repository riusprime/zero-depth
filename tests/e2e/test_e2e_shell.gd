extends GutTest
## Boot -> main menu -> Play -> Esc pauses -> Main menu, by input events only.


func after_each() -> void:
	Input.action_release(&"pause")


func test_menu_play_pause_and_back() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "the main menu shows at boot")
	await e.start_from_menu()
	assert_true(main.is_playing(), "Enter on the focused Play button starts the stage")
	var tick_before := e.world().tick
	await e.frames(5)
	assert_gt(e.world().tick, tick_before, "the sim runs")
	await e.tap(KEY_ESCAPE)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Esc opens the pause menu")
	var paused_tick := e.world().tick
	await e.frames(5)
	assert_eq(e.world().tick, paused_tick, "the sim is paused")
	await e.tap(KEY_DOWN)  # Resume -> Restart run
	await e.tap(KEY_DOWN)  # -> Main menu
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_false(main.is_playing(), "Main menu ends the stage")
	assert_not_null(main.get_node_or_null("UI/MainMenu"))


func test_version_label_on_the_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var menu: MainMenu = main.get_node("UI/MainMenu")
	assert_eq(menu.version_label.text, GameVersion.label())
