extends GutTest
## v0.7.5 SM (ROADMAP §0.4): the dev panels' release switch through main.tscn and real input. With the switch ON (this
## project) F10 opens the master panel in a run; with it OFF (what the `public_release` feature tag sets in an
## export) F10 and ` open nothing. The test flips the project setting only for itself (an export's override is what
## does it in a build) and puts it back.

var _was: Variant


func before_each() -> void:
	_was = ProjectSettings.get_setting(DevGate.SETTING, true)


func after_each() -> void:
	ProjectSettings.set_setting(DevGate.SETTING, _was)


func test_f10_opens_the_panel_only_while_the_switch_is_on() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_true(main.is_playing())
	ProjectSettings.set_setting(DevGate.SETTING, false)
	await e.tap(KEY_F10)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/DevMasterPanel"), "switch OFF: F10 opens nothing")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/DevPanel"), "nor does `")
	assert_false(main.driver.paused, "and the run goes on")
	ProjectSettings.set_setting(DevGate.SETTING, true)
	await e.tap(KEY_F10)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/DevMasterPanel"), "switch ON: F10 opens the panel")
	await e.tap(KEY_F10)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/DevMasterPanel"), "and closes it")
