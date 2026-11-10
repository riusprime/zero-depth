extends GutTest
## The Show FPS switch in the real game: Options (main menu, keyboard only) turns the frame-rate counter on and off,
## and the choice survives a restart. Input events only; reads of nodes are fine.


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _key_to(e: E2e, main: Main, key: Key, target: StringName, budget: int = 16) -> bool:
	for k in budget:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await e.tap(key)
	return _focused(main) != null and _focused(main).name == target


## Main menu -> Options -> Display, with the Show FPS switch focused.
func _to_switch(e: E2e, main: Main) -> void:
	assert_true(await _key_to(e, main, KEY_DOWN, &"Options"), "down to Options")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/OptionsMenu"), "Options opens")
	assert_true(await _key_to(e, main, KEY_DOWN, &"TabDisplay"), "down to Display")
	await e.tap(KEY_RIGHT)
	assert_true(await _key_to(e, main, KEY_DOWN, &"show_fps"), "down to Show FPS")


func test_the_counter_follows_the_switch_and_survives_a_restart() -> void:
	var profile := ProfileStore.new("")
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var counter := main.get_node("FpsCounter") as FpsCounter
	assert_false(counter.visible, "off by default")
	await _to_switch(e, main)
	await e.tap(KEY_RIGHT)  # Off -> On
	await e.frames(2)
	assert_eq(GameSettings.get_value(profile, "show_fps"), "on")
	assert_true(counter.visible, "on shows the counter, in the menu too")
	var text := counter.get_node("Value") as Label
	var digits := RegEx.create_from_string("^\\d+ FPS$")
	assert_not_null(digits.search(text.text), "shows a number and FPS: " + text.text)
	assert_eq(text.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it never eats a click")
	await e.tap(KEY_RIGHT)  # On -> Off
	await e.frames(2)
	assert_false(counter.visible, "off hides it")
	assert_false(counter.is_processing(), "and stops it")
	await e.tap(KEY_RIGHT)  # back On
	await e.frames(2)
	assert_true(counter.visible)
	# Restart the game over the same profile.
	main.queue_free()
	await e.frames(2)
	var again: Main = await e.boot(profile)
	var counter2 := again.get_node("FpsCounter") as FpsCounter
	assert_true(counter2.visible, "still on after a restart")
	assert_not_null(digits.search(counter2.shown_text()), "with a number: " + counter2.shown_text())
