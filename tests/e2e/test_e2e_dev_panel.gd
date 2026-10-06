extends GutTest
## Backtick opens the dev panel on the stage (tests run in a debug build).


func test_backtick_toggles_the_panel() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await e.tap(KEY_QUOTELEFT)
	assert_false(main.is_dev_panel_open())
