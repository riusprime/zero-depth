extends GutTest
## v0.9.5 SL (G11, Q15 a): the real build screen shows the Blade padlocked with its condition; picking it does nothing
## (the Gun stays the pick); once the unlock is granted (the test path, SwordLock.grant) it picks as before.


func test_the_blade_is_padlocked_and_cannot_be_picked_until_unlocked() -> void:
	var e := E2e.new(self)
	e.blade_locked = true
	var main: Main = await e.boot()
	await HubWalk.new(e).to_build_screen()
	await e.frames(70)
	var picker := main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_not_null(picker)
	assert_true(picker.cards[0].is_locked(), "the Blade is padlocked")
	assert_eq(picker.cards[0].locked_key, &"BUILD_BLADE_LOCKED")
	assert_false(picker.cards[1].is_locked(), "the Gun is not")
	assert_eq(picker.focused_id(), &"gun", "the Gun has focus on a locked profile")
	assert_true(tr("BUILD_BLADE_LOCKED").begins_with("Beat the Hollow Crown"), "the condition (en)")
	await e.tap(KEY_LEFT)
	assert_eq(picker.focused_id(), &"blade")
	await e.tap(KEY_ENTER)
	await e.frames(10)
	assert_false(main.is_playing(), "the Blade can't be picked: no run starts")
	assert_not_null(main.get_node_or_null("UI/BuildPicker"), "the build screen stays")
	# Unlock it (the test path) and open the screen again.
	SwordLock.grant(main.profile)
	await e.tap(KEY_ESCAPE)  # back to the hub, then the Portal Machine again
	await e.frames(5)
	await HubWalk.new(e).use(&"portal")
	await e.frames(70)
	picker = main.get_node_or_null("UI/BuildPicker") as BuildPicker
	assert_false(picker.cards[0].is_locked(), "unlocked: no padlock")
	await e.tap(KEY_LEFT)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	await e.loaded()
	assert_true(main.is_playing(), "the Blade starts a run")
	assert_eq(main.run.build_id, &"blade")
