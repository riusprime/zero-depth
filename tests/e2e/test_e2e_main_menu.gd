extends GutTest
## v0.9.5 MM: the redesigned main menu from the real game, by input events only: five plates in order, Continue
## greyed out (no save) and skipped by the focus, the keys and the pad move one focus, Play goes to the hub, Credits
## opens and Esc returns.


func after_each() -> void:
	E2e.center_sticks()
	for a in [&"ui_accept", &"ui_down", &"ui_up"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func test_the_five_plates_and_the_focus() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var menu: MainMenu = main.get_node("UI/MainMenu")
	var names := []
	for c in menu.box.get_children():
		if c is StoneButton:
			names.append(String(c.name))
	assert_eq(names, ["Continue", "Play", "Options", "Credits", "Quit"])
	assert_true(
		(menu.box.get_node("Continue") as Button).disabled, "no save: Continue is greyed out"
	)
	assert_eq(_focused(main).name, &"Play", "and skipped: Play has the focus")
	assert_true((_focused(main) as StoneButton).is_lit())
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Options")
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Credits")
	await e.tap(KEY_UP)
	assert_eq(_focused(main).name, &"Options", "Up goes back")
	e.joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await e.frames(1)
	e.joy_button(JOY_BUTTON_DPAD_DOWN, false)
	await e.frames(2)
	assert_eq(_focused(main).name, &"Credits", "the pad's d-pad moves the same focus")


func test_enter_on_play_goes_to_the_hub() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_not_null(main.hub, "Enter on Play goes to the hub")
	assert_null(main.get_node_or_null("UI/MainMenu"))


func test_credits_open_and_esc_returns() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/CreditsView"), "Credits opens")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Esc returns to the menu")
