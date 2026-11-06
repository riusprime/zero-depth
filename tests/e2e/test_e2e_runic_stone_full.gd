extends GutTest
## v0.9.5 RS2 (RUNIC_STONE.md R10, S6): nine lines learned (the test path), then the tenth for real: the language is
## switched from the hub's pause menu and Options with the stone awake. The stone pulses, speaks the new line, the
## runes ring it for good, and the Runic robe can be picked in the Wardrobe. Input events only; reads are fine.


func after_each() -> void:
	E2e.center_sticks()
	TranslationServer.set_locale("en")


func test_the_tenth_line_comes_from_switching_the_language_in_the_hub() -> void:
	var e := E2e.new(self)
	var profile := ProfileStore.new("")
	var repo := ContentRepository.load_all()
	var stone := RunicStone.new(profile, repo.get_def(&"runic_lines", &"main"))
	for i in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		assert_true(stone.learn(StringName("r%d" % i)))
	var robe: RobeDefinition = repo.get_def(&"robe", &"runic")
	assert_false(Wardrobe.robe_unlocked(profile, robe), "nine lines: the robe is still locked")
	var main: Main = await e.boot(profile)
	var walk := HubWalk.new(e)
	assert_true(await walk.enter())
	var hub := main.hub
	assert_true(hub.runic.stone.is_awake())
	assert_null(hub.view.stations[&"runic"]["root"].get_node_or_null("RuneRing"), "no ring yet")
	# Open the stone's bubble, then switch the language through the pause menu and Options.
	assert_true(await walk.walk_to(&"runic"))
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(hub.runic.bubble.is_open())
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	var options := main.get_node_or_null("UI/OptionsMenu") as OptionsMenu
	assert_not_null(options, "Options opens from the hub's pause menu")
	if options == null:
		return
	var tab := options.tabs[&"language"] as Button
	await e.click_at(tab.get_global_rect().get_center())
	await e.frames(2)
	var lang := options.find_child("language", true, false) as OptionCycler
	await e.click_at(lang.get_global_rect().position + Vector2(30, lang.size.y * 0.5))
	await e.frames(2)
	assert_eq(TranslationServer.get_locale(), "es", "the language changed")
	assert_true(hub.runic.stone.knows(&"r10"), "the stone heard it: the tenth line")
	assert_true(hub.runic.stone.is_full())
	assert_eq(hub.runic.stone.newest_first()[0], &"r10")
	assert_false(hub.runic.stone.pending_pulse, "it pulsed at once")
	var ring := hub.view.stations[&"runic"]["root"].get_node_or_null("RuneRing") as Node3D
	assert_not_null(ring, "the runes ring the stone")
	if ring != null:
		var turn: float = ring.rotation.y
		await e.frames(30)
		assert_ne(ring.rotation.y, turn, "and it turns")
	assert_true(Wardrobe.robe_unlocked(profile, robe), "the Runic robe unlocked")
	# Back out (Back returns to the pause menu; Esc closes it), then the Wardrobe.
	await e.click_at(options.find_child("Back", true, false).get_global_rect().get_center())
	await e.frames(2)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	await walk.use(&"wardrobe")
	var wardrobe := main.get_node_or_null("UI/WardrobePanel") as WardrobePanel
	assert_not_null(wardrobe, "the Wardrobe opens")
	if wardrobe == null:
		return
	for i in 12:
		if wardrobe.robe_cycler.value() == "runic":
			break
		await e.tap(KEY_RIGHT)
	assert_eq(wardrobe.robe_cycler.value(), "runic", "the Runic robe is in the list")
	assert_false(wardrobe.lock_note.visible, "and not locked")
	assert_eq(wardrobe.worn_robe, &"runic", "worn")
	assert_eq(main.hub.view.avatar.cloak_color, robe.cloak, "the hub's hero wears it")
	assert_eq(get_errors().size(), 0, "no engine or script error")
