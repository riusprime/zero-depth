extends GutTest
## v0.7.5 SM (owner N8): the first-run hints through main.tscn and real input only. A fresh profile's first run shows
## the move hint (with the bound keys), walking closes it, the attack hint follows and a click closes it, then dash;
## each is kept as seen in the profile. A new run doesn't show them again. Pause → Options → Accessibility → Reset
## hints (keyboard) forgets them, and the next run shows the move hint again. With "Show hints" off nothing shows.


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"primary", &"dash"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Waits (real frames) until the hints show `id` (&"" for none); false if they never did.
func _shows(e: E2e, hints: OnboardingHints, id: StringName, budget: int = 900) -> bool:
	for k in budget:
		if hints.current_id() == id and (id == &"" or hints.showing()):
			return true
		await e.frames(1)
	return false


func _key_to(e: E2e, main: Main, key: Key, target: StringName, budget: int = 14) -> bool:
	for k in budget:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await e.tap(key)
	return _focused(main) != null and _focused(main).name == target


## Pause → Restart (Resume, Build, Restart): a new run, floor 1.
func _restart(e: E2e, main: Main) -> void:
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_true(await _key_to(e, main, KEY_DOWN, &"Restart"))
	await e.tap(KEY_ENTER)
	await e.frames(4)


func test_first_run_hints_show_once_and_options_reset_them() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_true(main.is_playing())
	var hints := main.get_node_or_null("UI/OnboardingHints") as OnboardingHints
	assert_not_null(hints, "the hints live on the UI layer")
	assert_true(await _shows(e, hints, &"move"), "a first run opens with the move hint")
	assert_eq(hints.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it blocks nothing")
	assert_string_contains(hints.text(), "[W A S D]", "with the bound keys")
	assert_string_contains(hints.text(), tr("HINT_MOUSE"))
	assert_true(main.driver != null and not main.driver.paused, "the game runs under it")
	assert_has(main.profile.section("hints")["seen"], "move", "kept as seen in the profile")
	# Walk: the move hint closes, the attack hint follows (the Blade swings on the left click).
	var from := e.world().player_pos()
	e.key(KEY_D, true)
	await e.frames(45)
	e.key(KEY_D, false)
	assert_gt(e.world().player_pos().distance_to(from), OnboardingHints.MOVE_DONE_M, "walked")
	assert_true(await _shows(e, hints, &"attack"), "then the attack hint")
	assert_string_contains(hints.text(), OnboardingHints.key(&"primary", InputRebind.KBM))
	e.mouse_button(MOUSE_BUTTON_LEFT, true)
	await e.frames(2)
	e.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_true(await _shows(e, hints, &"dash"), "a swing closes it: then dash")
	assert_string_contains(hints.text(), "[%s]" % OS.get_keycode_string(KEY_SPACE))
	await e.tap(KEY_SPACE)
	assert_true(await _shows(e, hints, &""), "a dash closes the last first-run step")
	for id in ["move", "attack", "dash"]:
		assert_has(main.profile.section("hints")["seen"], id)
	# A new run: nothing again.
	await _restart(e, main)
	assert_true(main.is_playing(), "a new run")
	await e.frames(30)
	assert_eq(hints.current_id(), &"", "the move hint doesn't show again")
	assert_false(hints.visible)
	# Pause → Options → Accessibility → Reset hints.
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_true(await _key_to(e, main, KEY_DOWN, &"Options"))
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var options := main.get_node_or_null("UI/OptionsMenu") as OptionsMenu
	assert_not_null(options, "Options over the pause")
	assert_true(await _key_to(e, main, KEY_DOWN, &"TabAccessibility"))
	await e.tap(KEY_RIGHT)
	assert_true(await _key_to(e, main, KEY_DOWN, &"ResetHints"), "down to Reset hints")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_eq(main.profile.section("hints")["seen"], [], "every hint forgotten")
	assert_true(
		(options.find_child("HintsResetDone", true, false) as Control).visible, "it says so"
	)
	await e.tap(KEY_ESCAPE)  # to the category
	await e.tap(KEY_ESCAPE)  # out of Options, on the pause menu
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/OptionsMenu"))
	assert_true(await _key_to(e, main, KEY_UP, &"Restart"))
	await e.tap(KEY_ENTER)
	await e.frames(4)
	assert_true(await _shows(e, hints, &"move"), "the next run shows the move hint again")


func test_show_hints_off_shows_none() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["hints"] = "off"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	await e.start_from_menu()
	assert_true(main.is_playing())
	var hints := main.get_node("UI/OnboardingHints") as OnboardingHints
	await e.frames(60)
	assert_eq(hints.current_id(), &"", "Show hints: Off")
	assert_false(hints.visible)
	assert_eq(main.profile.section("hints")["seen"], [], "and nothing is marked seen")


func test_the_move_hint_names_the_pad_once_a_pad_is_used() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var hints := main.get_node("UI/OnboardingHints") as OnboardingHints
	assert_true(await _shows(e, hints, &"move"))
	e.joy_button(JOY_BUTTON_LEFT_STICK, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_LEFT_STICK, false)
	await e.frames(1)
	assert_eq(hints.device, InputRebind.PAD, "the last device is the pad")
	assert_string_contains(hints.text(), tr("HINT_PAD_LEFT_STICK"), "the hint names its stick")
	assert_string_contains(hints.text(), tr("HINT_PAD_RIGHT_STICK"))
