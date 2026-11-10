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


## Owner, 2026-11-10: God lasts "until you untick it", not until the panel closes.
func test_god_outlasts_the_closed_panel_until_it_is_unticked() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	await _click_god(e, main)
	assert_true(main.driver.debug.god, "ticked")
	await e.tap(KEY_QUOTELEFT)
	assert_false(main.is_dev_panel_open())
	assert_true(
		main.driver.debug != null and main.driver.debug.god, "God is still on with the panel closed"
	)
	var hp := main.driver.reader.player_hp()
	await e.frames(30)
	assert_false(main.driver.debug.paused, "and the sim runs")
	assert_eq(main.driver.reader.player_hp(), hp)
	await e.tap(KEY_QUOTELEFT)
	var god := main.get_node("UI/DevPanel").find_child("God", true, false) as Button
	assert_true(god.button_pressed, "the reopened panel shows it on")
	await _click_god(e, main)
	assert_false(main.driver.debug.god, "unticked")
	await e.tap(KEY_QUOTELEFT)
	assert_null(main.driver.debug, "and with God off the closed panel leaves nothing behind")


func _click_god(e: E2e, main: Main) -> void:
	var god := main.get_node("UI/DevPanel").find_child("God", true, false) as Button
	await e.click_at(god.get_global_rect().get_center())
