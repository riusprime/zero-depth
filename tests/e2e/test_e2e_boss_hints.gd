extends GutTest
## v0.11.0 O2 (owner L4, Q12 a): the boss hint through main.tscn and real input. No boss points at anything yet (the
## Gatekeeper's pillars come with O3), so the test stands in for boss code: it sets a marker in the live world as a
## boss would (World.objectives), and everything after that is the game's own path: the HUD's hint pings it on
## screen and points an arrow at one off screen, the run counts as a meeting in the Codex's profile section, and
## Pause -> Options -> Accessibility -> "Boss hints" (keyboard) turns it off, which hides it.

const PILLAR := ObjectiveMarkers.GATEKEEPER_PILLAR


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _key_to(e: E2e, main: Main, key: Key, target: StringName, budget: int = 16) -> bool:
	for k in budget:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await e.tap(key)
	return _focused(main) != null and _focused(main).name == target


func test_the_hint_shows_counts_and_options_turn_it_off() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_true(main.is_playing())
	var view := main.get_node_or_null("UI/Hud/ObjectiveHints") as ObjectiveHints
	assert_not_null(view, "the hint lives on the HUD")
	await e.frames(5)
	assert_false(view.visible, "nothing pointed at: no hint")
	# The stand-in for boss code (O3 calls this from the Gatekeeper's fight).
	var w := e.world()
	w.objectives.point(PILLAR, w.player_pos() + Vector2(1.5, 0))
	w.objectives.point(PILLAR, w.player_pos() + Vector2(80, 0))
	await e.frames(5)
	assert_true(view.visible, "a hint shows")
	assert_true(view.showing(PILLAR, ObjectiveHints.PING), "a ping on the pillar on screen")
	assert_true(view.showing(PILLAR, ObjectiveHints.ARROW), "an arrow at the one off screen")
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it blocks nothing")
	var hints := MechanicHints.new(main.codex)
	assert_eq(hints.runs(PILLAR), 1, "this run counts as the first meeting, in the Codex")
	await e.frames(30)
	assert_eq(hints.runs(PILLAR), 1, "once per run")
	# Pause -> Options -> Accessibility -> Boss hints: Off.
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_true(await _key_to(e, main, KEY_DOWN, &"Options"))
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/OptionsMenu"), "Options over the pause")
	assert_true(await _key_to(e, main, KEY_DOWN, &"TabAccessibility"))
	await e.tap(KEY_RIGHT)
	assert_true(await _key_to(e, main, KEY_DOWN, &"boss_hints"), "down to Boss hints")
	await e.tap(KEY_RIGHT)
	await e.frames(2)
	assert_eq(GameSettings.get_value(main.profile, MechanicHints.SETTING), "off", "Boss hints: Off")
	await e.tap(KEY_ESCAPE)  # to the category
	await e.tap(KEY_ESCAPE)  # out of Options, on the pause menu
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/OptionsMenu"))
	await e.tap(KEY_ESCAPE)  # resume
	await e.frames(5)
	assert_false(main.driver.paused, "playing again")
	assert_false(view.visible, "off hides the hint")
