extends GutTest
## The Options screen in the real game (v0.3.0 O): opened from the pause menu with a pad, a volume and screen shake
## changed there, a key remapped with the keyboard and used in play; and the mouse path from the main menu.
## Input events only (Input.parse_input_event); reads of nodes and the world are fine.


func after_each() -> void:
	InputDefaults.apply()
	ViewPrefs.reduced_motion = false
	ThemePalette.mode = &"off"
	TranslationServer.set_locale("en")
	GameSettings.apply_one(ProfileStore.new(""), "audio/master")
	for a in [
		&"pause", &"ui_accept", &"ui_down", &"ui_up", &"ui_left", &"ui_right", &"ui_cancel", &"dash"
	]:
		Input.action_release(a)


func _press(e: E2e, button: JoyButton) -> void:
	e.joy_button(button, true)
	await e.frames(1)
	e.joy_button(button, false)
	await e.frames(2)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Taps `keycode` until the focused control is named `target` (at most `limit` taps).
func _key_to(e: E2e, main: Main, keycode: Key, target: StringName, limit: int = 16) -> bool:
	for k in limit:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await e.tap(keycode)
		await e.frames(1)
	return _focused(main) != null and _focused(main).name == target


func _pad_to(e: E2e, main: Main, button: JoyButton, target: StringName, limit: int = 16) -> bool:
	for k in limit:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await _press(e, button)
	return _focused(main) != null and _focused(main).name == target


func test_options_from_pause_with_the_pad_then_a_remapped_key_works_in_play() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(5)
	assert_true(main.is_playing())
	assert_true(main.view.rig.shake_enabled, "shake starts on")
	# Pad: Start pauses, the d-pad walks to Options, A opens it.
	await _press(e, JOY_BUTTON_START)
	assert_not_null(main.get_node_or_null("UI/PauseMenu"), "Start pauses")
	assert_true(await _pad_to(e, main, JOY_BUTTON_DPAD_DOWN, &"Options"), "d-pad to Options")
	await _press(e, JOY_BUTTON_A)
	var options := main.get_node_or_null("UI/OptionsMenu") as OptionsMenu
	assert_not_null(options, "pad A on Options opens Options over the pause")
	assert_false(
		(main.get_node("UI/PauseMenu") as Control).visible, "the pause menu hides under it"
	)
	assert_eq(_focused(main).name, &"TabAudio", "Audio has focus")
	# A volume: right into Audio's first slider, then left lowers it one step.
	await _press(e, JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focused(main).name, &"audio_master", "d-pad right enters the section")
	await _press(e, JOY_BUTTON_DPAD_LEFT)
	assert_eq(int(GameSettings.get_value(main.profile, "audio/master")), 75, "80 -> 75")
	var master := AudioServer.get_bus_index("Master")
	assert_almost_eq(
		AudioServer.get_bus_volume_db(master), linear_to_db(0.75), 0.01, "the bus follows"
	)
	# B goes back to the category list; down to Accessibility; into it; A flips shake.
	await _press(e, JOY_BUTTON_B)
	assert_eq(_focused(main).name, &"TabAudio", "pad B leaves the section for its category")
	assert_true(await _pad_to(e, main, JOY_BUTTON_DPAD_DOWN, &"TabAccessibility"))
	assert_eq(options.current, &"accessibility", "focusing a category shows it")
	await _press(e, JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focused(main).name, &"shake")
	await _press(e, JOY_BUTTON_A)
	assert_eq(GameSettings.get_value(main.profile, "shake"), "off", "pad A flips the choice")
	assert_false(main.view.rig.shake_enabled, "the running view's shake turns off at once")
	# Keyboard: back to the categories, up to Controls, into it, down to Dash's key, Enter, then J.
	await e.tap(KEY_ESCAPE)
	assert_eq(_focused(main).name, &"TabAccessibility", "Esc also steps back to the category")
	assert_true(await _key_to(e, main, KEY_UP, &"TabControls"))
	await e.tap(KEY_RIGHT)
	assert_true(
		await _key_to(e, main, KEY_DOWN, &"dash_kbm"), "walk down to Dash's keyboard binding"
	)
	await e.tap(KEY_ENTER)
	assert_true(options.capturing(), "Enter waits for a key")
	await e.tap(KEY_J)
	assert_false(options.capturing())
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_J], "Dash is J now")
	assert_true(main.profile.section("bindings").has("dash"), "and the profile keeps it")
	assert_eq((options.bind_buttons["dash/kbm"] as Button).text, OS.get_keycode_string(KEY_J))
	# Out: Esc to the category, Esc out of Options (back on the pause menu), up to Resume, Enter.
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/OptionsMenu"), "Options closed")
	assert_true((main.get_node("UI/PauseMenu") as Control).visible, "the pause menu is back")
	assert_eq(_focused(main).name, &"Options", "with Options focused")
	assert_true(await _key_to(e, main, KEY_UP, &"Resume"))
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_null(main.get_node_or_null("UI/PauseMenu"), "resumed")
	# In play: Space no longer dashes, J does.
	var w := e.world()
	await e.tap(KEY_SPACE)
	await e.frames(3)
	assert_false(w.is_dashing() or w.dash_cooldown_left > 0, "Space no longer dashes")
	await e.tap(KEY_J)
	var dashed := false
	for k in 6:
		await e.frames(1)
		dashed = dashed or w.is_dashing() or w.dash_cooldown_left > 0
	assert_true(dashed, "J dashes in play")
	assert_eq(get_errors().size(), 0, "no engine or script error")


func test_the_mouse_changes_the_language_from_the_main_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	var options := main.get_node_or_null("UI/OptionsMenu") as OptionsMenu
	assert_not_null(options, "Options opens from the main menu")
	var tab := options.tabs[&"language"] as Button
	await e.click_at(tab.get_global_rect().get_center())
	await e.frames(2)
	assert_eq(options.current, &"language", "clicking a category shows it")
	var lang := options.find_child("language", true, false) as OptionCycler
	# Its left end: GUT's own output panel covers the right of the headless window and would take the click.
	await e.click_at(lang.get_global_rect().position + Vector2(30, lang.size.y * 0.5))
	await e.frames(2)
	assert_eq(GameSettings.get_value(main.profile, "language"), "es", "a click steps the choice")
	assert_eq(TranslationServer.get_locale(), "es")
	assert_eq(tab.text, "UI_SECTION_LANGUAGE", "labels stay keys")
	await e.click_at(options.find_child("Back", true, false).get_global_rect().get_center())
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Back returns to the main menu")
