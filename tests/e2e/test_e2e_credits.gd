extends GutTest
## Main menu -> Play -> the hub's Credits stone (v0.9.0 HB) -> Back, by input events. The credits carry the Godot
## licence and the font's licence.


func after_each() -> void:
	E2e.center_sticks()


func test_credits_from_the_hub() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var walk := HubWalk.new(e)
	await walk.enter()
	await walk.use(&"credits")
	var credits: CreditsView = main.get_node_or_null("UI/CreditsView")
	assert_not_null(credits, "Credits opens from the hub's Credits stone")
	if credits == null:
		return
	assert_string_contains(credits.text.text, "Permission is hereby granted")  # Godot's MIT licence
	assert_string_contains(credits.text.text, "SIL OPEN FONT LICENSE")
	await e.tap(KEY_ENTER)  # Back has focus
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CreditsView"), "Back closes them")
	assert_not_null(main.hub, "back in the hub")
