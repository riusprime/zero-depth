extends GutTest
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring) through main.tscn with real input only: the small menu
## (Continue, Play, Options, Quit), Play -> the hub, the hero walks (the left stick) to each station and E opens its
## panel, the Portal Machine's build screen starts a run, the run's end offers Restart (one press) or the hub, Esc
## in the hub pauses it, and the hub never touches a run's save.

const SAVE := "res://tests/fixtures/saves/v061_blade_floor1.save"


func after_each() -> void:
	E2e.center_sticks()
	for a in [&"ui_accept", &"ui_down", &"ui_up", &"pause", &"interact"]:
		Input.action_release(a)


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _rows(menu: Node) -> Array:
	var out := []
	for c in (menu as MenuPanel).box.get_children():
		if c is Button:
			out.append(String(c.name))
	return out


func _wait_for_end(e: E2e, main: Main) -> EndPanel:
	for k in 4000:
		await e.frames(1)
		var p := main.get_node_or_null("UI/EndPanel")
		if p != null:
			return p
	return null


func test_the_small_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var menu := main.get_node_or_null("UI/MainMenu") as MainMenu
	assert_not_null(menu)
	assert_eq(_rows(menu), ["Continue", "Play", "Options", "Quit"], "the small menu (Q27)")
	assert_true(
		(menu.box.get_node("Continue") as Button).disabled, "Continue greyed out without a save"
	)
	assert_eq(_focused(main).name, &"Play", "Play has focus without a save")
	await e.tap(KEY_UP)
	assert_eq(_focused(main).name, &"Play", "the greyed-out Continue takes no focus")
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Options")
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Quit")


func test_play_walks_to_the_portal_machine_and_starts_a_run() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play goes to the hub")
	assert_null(main.get_node_or_null("UI/MainMenu"), "the menu is gone")
	assert_false(main.is_playing(), "no run yet")
	var hub := main.hub
	assert_eq(hub.at, &"", "the hero spawns away from every station")
	var start := hub.driver.reader.player_pos()
	assert_true(await walk.walk_to(&"portal"), "the hero walks to the Portal Machine")
	assert_gt((hub.driver.reader.player_pos() - start).length(), 5.0, "it walked there")
	var hud := main.get_node_or_null("UI/HubHud") as HubHud
	assert_not_null(hud)
	assert_eq(hud.prompt_text(), tr("HUB_PROMPT_PORTAL"), "its prompt shows")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/BuildPicker"), "E opens the build screen")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/BuildPicker"), "Esc closes it")
	assert_not_null(main.hub, "back in the hub")
	assert_false(main.hub.held, "the hero walks again")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/BuildPicker"))
	await e.tap(KEY_ENTER)
	await e.loaded()
	await e.frames(4)
	assert_true(main.is_playing(), "the build screen's pick starts the run")
	assert_null(main.hub, "the hub is gone")
	assert_true(await e.landed(), "the hero lands on floor 1's altar")


## v0.9.0 HB2 (owner: "click, choose weapon and then the character walks upstairs towards the portal and crosses it"):
## the pick closes the build screen, the hero climbs the machine's steps and crosses its ring (the portal flares) while
## the hub's World holds and a stick push is ignored; then the run loads as before. Watched on raw frames (E2e.frames
## waits a walk out).
func test_the_pick_walks_the_hero_up_into_the_portal() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await HubWalk.new(e).to_build_screen()
	e.key(KEY_ENTER, true)  # the pick (Blade)
	e.key(KEY_ENTER, false)
	var hub := main.hub
	assert_not_null(hub, "the hub stays for the walk")
	assert_true(hub.walking, "the pick starts the walk into the portal")
	var picker := main.get_node_or_null("UI/BuildPicker")
	assert_true(picker == null or picker.is_queued_for_deletion(), "the build screen closes")
	assert_false(main.loads.busy(), "no load yet: the hero walks first")
	var held_at := hub.driver.reader.player_pos()
	var top := 0.0
	var flared := false
	var moved := false
	var frames := 0
	while main.hub != null and not main.loads.busy() and frames < 600:
		e.joy_axis(JOY_AXIS_LEFT_X, 1.0)  # ignored during the walk
		top = maxf(top, hub.view.hero.position.y)
		flared = flared or hub.view.machine.flare > 0.9
		moved = moved or hub.driver.reader.player_pos() != held_at
		frames += 1
		await get_tree().physics_frame
	e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
	gut.p("HB2: the walk into the portal took %d frames (%.2f s)" % [frames, frames / 60.0])
	assert_gt(top, 1.0, "the hero climbs the machine's steps")
	assert_true(flared, "the portal flares as the hero crosses")
	assert_false(moved, "the hub's World holds; the stick is ignored")
	assert_between(frames, 100, 200, "about 2-3 s")
	await e.loaded()
	await e.frames(4)
	assert_true(main.is_playing(), "then the run starts as before")
	assert_true(await e.landed(), "the hero lands on floor 1's altar")


## v0.9.0 HB2: a press during the walk skips it (the run's load starts at once).
func test_a_press_skips_the_walk() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await HubWalk.new(e).to_build_screen()
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	for k in 10:
		await get_tree().physics_frame
	assert_true(main.hub != null and main.hub.walking and not main.loads.busy(), "walking")
	e.key(KEY_E, true)
	e.key(KEY_E, false)
	await get_tree().physics_frame
	assert_true(main.loads.busy(), "the press skips to the run's load")
	await e.loaded()
	await e.frames(4)
	assert_true(main.is_playing())


func test_each_station_opens_its_panel() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var walk := HubWalk.new(e)
	await walk.enter()
	# The Rune Archive: the Codex.
	await walk.use(&"archive")
	var codex := main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "the Rune Archive opens the Codex")
	if codex != null:
		assert_ne(codex.page, CodexView.ACHIEVEMENTS, "on its first page")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CodexView"), "Esc returns to the hub")
	# The Trophy Area: the achievements.
	await walk.use(&"trophy")
	codex = main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "the Trophy Area opens the Codex")
	if codex != null:
		assert_eq(codex.page, CodexView.ACHIEVEMENTS, "on the Achievements page")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	# v0.9.0 RB: the Wardrobe's own panel (test_e2e_wardrobe picks there); Esc closes it.
	await walk.use(&"wardrobe")
	assert_not_null(main.get_node_or_null("UI/WardrobePanel"), "the wardrobe opens its panel")
	assert_true(main.hub.driver.paused, "the hub holds under it")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/WardrobePanel"), "Esc closes it")
	assert_false(main.hub.driver.paused)
	# The Progression Station: its stand-in.
	for id: StringName in [&"progression"]:
		await walk.use(id)
		var p := main.get_node_or_null("UI/HubPanel_%s" % id) as HubStationPanel
		assert_not_null(p, "the %s opens its panel" % id)
		assert_true(main.hub.driver.paused, "the hub holds under it")
		await e.tap(KEY_ENTER)  # Back has focus
		await e.frames(2)
		assert_null(main.get_node_or_null("UI/HubPanel_%s" % id), "Back closes it")
		assert_false(main.hub.driver.paused)
	# The Credits stone.
	await walk.use(&"credits")
	assert_not_null(main.get_node_or_null("UI/CreditsView"), "the Credits stone opens the credits")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/CreditsView"))
	assert_not_null(main.hub, "still in the hub")


func test_the_hub_pause_goes_to_the_main_menu() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await HubWalk.new(e).enter()
	await e.tap(KEY_ESCAPE)
	await e.frames(1)
	assert_not_null(main.get_node_or_null("UI/HubPauseMenu"), "Esc pauses the hub")
	assert_true(main.hub.driver.paused)
	await e.tap(KEY_ESCAPE)
	await e.frames(1)
	assert_null(main.get_node_or_null("UI/HubPauseMenu"), "Esc again resumes")
	await e.tap(KEY_ESCAPE)
	await e.frames(1)
	await e.tap(KEY_DOWN)  # Resume -> Options
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/OptionsMenu"), "Options from the hub's pause")
	await e.tap(KEY_ESCAPE)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/HubPauseMenu"), "its Back returns to the hub's pause")
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)  # -> Main menu
	assert_eq(_focused(main).name, &"MainMenu")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_not_null(main.get_node_or_null("UI/MainMenu"), "Main menu leaves the hub")
	assert_null(main.hub)


func test_after_a_run_restart_in_one_press_or_the_hub() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var seed_before := e.world().seed_value
	var panel := await _wait_for_end(e, main)
	assert_not_null(panel, "standing still, you die")
	if panel == null:
		return
	assert_ne(panel.recap_line("Floor"), "", "the run summary")
	assert_eq(_focused(main).name, &"Restart", "Restart has focus")
	await e.tap(KEY_ENTER)
	await e.loaded()
	await e.frames(3)
	assert_null(main.get_node_or_null("UI/EndPanel"), "one press restarts")
	assert_true(main.is_playing())
	assert_eq(e.world().seed_value, seed_before + 1, "a new run, the next seed")
	panel = await _wait_for_end(e, main)
	assert_not_null(panel)
	if panel == null:
		return
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Hub")
	await e.tap(KEY_ENTER)
	await e.frames(3)
	assert_false(main.is_playing(), "the run is over")
	assert_not_null(main.hub, "the hero is back in the hub")
	assert_null(main.get_node_or_null("UI/MainMenu"))
	assert_eq(main.hub.at, &"", "at the spawn")


func test_the_hub_in_spanish() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "es"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var walk := HubWalk.new(e)
	await walk.enter()
	await walk.walk_to(&"portal")
	var hud := main.get_node_or_null("UI/HubHud") as HubHud
	assert_eq(hud.station_name(), "Máquina de Portales", "the station's name in Spanish")
	assert_eq(hud.prompt_text(), "[E / X] Empezar una partida", "and its prompt")
	TranslationServer.set_locale("en")


func test_the_hub_never_touches_the_run_save() -> void:
	var r := RunSaveStore.decode(FileAccess.get_file_as_bytes(SAVE))
	var store := RunSaveStore.new("")
	assert_true(store.write((r[0] as Dictionary)["payload"]))
	var before := store.read()
	var e := E2e.new(self)
	var main: Main = await e.boot(null, store)
	assert_eq(_focused(main).name, &"Continue", "Continue, focused first with a save")
	await e.tap(KEY_DOWN)
	assert_eq(_focused(main).name, &"Play")
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play goes to the hub")
	await walk.walk_to(&"trophy")
	await walk.walk_to(&"wardrobe")
	await e.tap(KEY_ESCAPE)
	await e.frames(1)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_true(store.has_save(), "the save is still there")
	assert_eq(store.read(), before, "untouched")
	assert_eq(_focused(main).name, &"Continue", "and Continue still offers it")
