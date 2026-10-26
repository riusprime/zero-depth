extends GutTest
## v0.9.5 RS1 (RUNIC_STONE.md): the hub's Runic Stone, driven the way a player does (Input events only; reads are fine).
## Locked it shows no prompt, only a faint "..." bubble, and a press only hums. A purple-rune activation in a run (the
## achievement stat the tracker records) wakes it on the next hub visit: veins lit and pulsing, the prompt reads "Read",
## a press opens the newest line in glyphs. Seven presses in a row learn the third line. The Credits are in the menu.


func after_each() -> void:
	E2e.center_sticks()


func _enter_hub(e: E2e, profile: ProfileStore) -> Main:
	var main: Main = await e.boot(profile)
	assert_true(await HubWalk.new(e).enter(), "Play goes to the hub")
	return main


func test_locked_stone_shows_no_prompt_and_only_hums() -> void:
	var e := E2e.new(self)
	var profile := ProfileStore.new("")
	var main := await _enter_hub(e, profile)
	var walk := HubWalk.new(e)
	assert_true(await walk.walk_to(&"runic"))
	var hub := main.hub
	assert_eq(hub.at, &"runic")
	assert_eq(hub.hud.prompt_text(), "", "locked: no interact prompt")
	assert_eq(hub.hud.station_name(), tr("HUB_RUNIC_STONE"), "it is the Runic Stone")
	assert_eq(hub.runic.bubble.mode, RuneBubble.Mode.DOTS, "only a faint ... bubble")
	assert_false(hub.view.runic_lit(), "dark: no veins")
	main.audio.played_log.clear()
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(hub.runic.bubble.mode, RuneBubble.Mode.DOTS, "a press opens no line")
	assert_eq(hub.runic.bubble.glyph_count(), 0)
	assert_has(main.audio.played_log, &"void_hum", "a low hum")
	assert_null(main.get_node_or_null("UI/CreditsView"), "and no credits")
	assert_eq(RunicStone.new(profile, null).learned(), [], "nothing learned")


func test_a_purple_activation_wakes_the_stone_on_the_next_visit() -> void:
	var e := E2e.new(self)
	var profile := ProfileStore.new("")
	var main: Main = await e.boot(profile)
	# The run's side: the tracker records a purple-rune room activated (AchievementTracker -> the stat).
	AchievementStore.new(profile).add_stat(RunicStone.PURPLE_STAT)
	var walk := HubWalk.new(e)
	assert_true(await walk.enter())
	var hub := main.hub
	assert_true(hub.runic.stone.is_awake(), "the hub entry learned r1")
	assert_true(hub.view.runic_lit(), "the veins glow")
	assert_false(hub.runic.stone.pending_pulse, "and pulsed once")
	assert_true(await walk.walk_to(&"runic"))
	assert_eq(hub.hud.prompt_text(), tr("HUB_PROMPT_RUNIC_READ"), "awake: [button] Read")
	assert_string_contains(hub.hud.prompt_text(), "Read")
	await e.tap(KEY_E)
	await e.frames(2)
	var bubble := hub.runic.bubble
	assert_true(bubble.visible and bubble.mode == RuneBubble.Mode.LINE, "the bubble opens")
	var want := RuneCipher.encode("WHAT SLEEPS BELOW REMEMBERS").filter(
		func(g: int) -> bool: return g != RuneCipher.GAP
	)
	assert_eq(bubble.glyph_count(), want.size(), "the line, in glyphs")
	await e.frames(90)
	assert_eq(bubble.shown_count(), want.size(), "every glyph faded in")
	# Walking away closes it.
	assert_true(await walk.walk_to(&"archive"))
	assert_false(bubble.is_open(), "walking away closes the bubble")


func test_seven_presses_learn_the_third_line() -> void:
	var e := E2e.new(self)
	var profile := ProfileStore.new("")
	var main: Main = await e.boot(profile)
	AchievementStore.new(profile).add_stat(RunicStone.PURPLE_STAT)
	var walk := HubWalk.new(e)
	assert_true(await walk.enter())
	assert_true(await walk.walk_to(&"runic"))
	var hub := main.hub
	for i in 6:
		await e.tap(KEY_E)
		await e.frames(2)
	assert_false(hub.runic.stone.knows(&"r3"), "six are not enough")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_true(hub.runic.stone.knows(&"r3"), "the seventh in a row")
	var want := RuneCipher.encode("PATIENCE IS A KEY").filter(
		func(g: int) -> bool: return g != RuneCipher.GAP
	)
	assert_eq(hub.runic.bubble.glyph_count(), want.size(), "the bubble shows the new line")
	assert_eq(hub.runic.stone.newest_first()[0], &"r3")


func test_credits_are_reachable_from_the_main_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(
		main.get_node_or_null("UI/CreditsView"), "Options, Credits, Quit: Credits opens"
	)
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Esc returns to the menu")
