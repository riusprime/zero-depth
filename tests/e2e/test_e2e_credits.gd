extends GutTest
## Main menu -> Credits -> Back, by keyboard. The credits carry the Godot licence and the font's licence.


func test_credits_from_the_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_DOWN)  # Play -> Options
	await e.tap(KEY_DOWN)  # Options -> Credits
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var credits: CreditsView = main.get_node_or_null("UI/CreditsView")
	assert_not_null(credits, "Credits opens from the main menu")
	if credits == null:
		return
	assert_string_contains(credits.text.text, "Permission is hereby granted")  # Godot's MIT licence
	assert_string_contains(credits.text.text, "SIL OPEN FONT LICENSE")
	await e.tap(KEY_ENTER)  # Back has focus
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Back returns to the menu")
