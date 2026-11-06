extends GutTest
## v0.9.5 RS1 (RUNIC_STONE.md S1): the Credits are an item of the main menu again (Play, Options, Credits, Quit): Down
## twice from Play, Enter, and Esc is Back to the menu. The credits carry the Godot licence and the font's licence. The
## hub's stone no longer opens them (test_e2e_runic_stone).


func after_each() -> void:
	E2e.center_sticks()


func test_credits_from_the_main_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_DOWN)  # Options
	await e.tap(KEY_DOWN)  # Credits
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var credits: CreditsView = main.get_node_or_null("UI/CreditsView")
	assert_not_null(credits, "Credits opens from the main menu")
	if credits == null:
		return
	assert_string_contains(credits.text.text, "Permission is hereby granted")  # Godot's MIT licence
	assert_string_contains(credits.text.text, "SIL OPEN FONT LICENSE")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CreditsView"), "Esc closes them")
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "back at the main menu")
	assert_null(main.hub, "no hub behind it")
