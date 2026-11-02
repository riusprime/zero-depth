class_name TrainingFlow
extends RefCounted
## v0.10.5 O17 (owner P17): how Main goes into and out of the hub's Training Room, behind the loading cover (CoverLoads,
## as a run's floor): the hero walking down the hub's south door lane goes in with the hub hero's weapon; the terminal's
## weapon pick, its Reset and the pause menu's Restart build the room again; the exit pad goes back to the hub. The
## room (TrainingScenario) is built with none of the run's recorders attached: MetaHooks, CodexRecorder,
## AchievementTracker and RunSaver never see its World, so nothing done there counts (no Codex, achievements, records,
## unlocks, fragments or hints). Kept apart from Main (its file stays under the length cap).


## The hero walked down the hub's south door lane: the Training Room behind the cover.
static func enter(main: Main) -> void:
	if main.hub == null or main.loads.busy():
		return
	main.hub.set_held(true)
	var build := Wardrobe.build_of(main.profile)
	main.loads.behind(main.get_tree(), main.ui, start.bind(main, build), Main.FADE_SECONDS)


## The room again with weapon `build_id`, behind the cover.
static func reset(main: Main, build_id: StringName) -> void:
	main.close_pause()
	if main.driver != null:
		main.driver.paused = true
	main.loads.behind(main.get_tree(), main.ui, start.bind(main, build_id), Main.FADE_SECONDS)


## The hero walked onto the exit pad: back to the hub (its spawn, by the south door), behind the cover.
static func leave(main: Main) -> void:
	if main.training == null:
		return
	main.driver.paused = true
	main.loads.behind(main.get_tree(), main.ui, main._show_hub, Main.FADE_SECONDS)


## The Training Room with weapon `build_id`: the smaller room in the hub's light (its biome), the endless dummy, the
## terminal, the run's HUD (the hero's HP) and the DPS meter.
static func start(main: Main, build_id: StringName) -> void:
	main._end_hub()
	main._set_menu(null)
	main._end_stage()
	var repo := main._content()
	var biome: BiomeDefinition = repo.get_def(&"biomes", HubSession.BIOME)
	var driver := SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(TrainingScenario.build(repo, build_id, biome))
	main.driver = driver
	main.add_child(driver)
	var t := TrainingSession.new(
		driver,
		main.ui,
		build_id,
		weapons(repo, main.profile),
		main.codex,
		main.codex_catalog(repo),
		PlaygroundScenario.source_names(repo)
	)
	main.training = t
	t.on_pause_change = main._sync_pause
	t.leave_requested.connect(leave.bind(main))
	t.weapon_requested.connect(func(id: StringName) -> void: reset(main, id))
	t.reset_requested.connect(func() -> void: reset(main, t.build_id))
	main.add_child(t)
	room_view(main, biome)
	var props := TrainingProps.new()
	main.view.add_child(props)
	props.setup(
		TrainingRoom.terminal_point(t.room), TrainingRoom.exit_point(t.room), TrainingRoom.inward()
	)
	t.props = props
	var hud := Hud.new()
	main._hud = hud
	main.ui.add_child(hud)
	main.ui.move_child(hud, 0)
	hud.sync(driver.reader)
	driver.ticked.connect(main._on_playground_tick)
	driver.edited.connect(main._on_playground_tick)
	main.audio.set_ambience(HubSession.BIOME)
	main._sync_pause()


## The weapons the terminal offers, [{id, name_key}]: every build but a locked one (SwordLock: the Blade until earned).
static func weapons(repo: ContentRepository, profile: ProfileStore) -> Array:
	var out := []
	var locked := SwordLock.locked_builds(profile)
	for d: BuildDefinition in repo.all_of(&"build"):
		if not locked.has(d.id):
			out.append({"id": d.id, "name_key": d.name_key})
	return out


## v0.10.5 O17 (moved from Main): the Playground's or the Training Room's view of the driver's one room in `biome`,
## its input and sounds.


static func room_view(main: Main, biome: BiomeDefinition) -> PlayerInput:
	main.view = WorldViewRoot.new()
	main.view.name = "WorldView"
	main.view.stage.prop_style = biome.id
	main.view.stage.mood = biome.mood
	main.view.stage.look = biome.look
	if biome.look != null:
		main.view.actors.enemy_tint = biome.look.enemy_tint
	main._biome_path = biome.resource_path
	main.view.stage.lighting = GameSettings.get_value(main.profile, "lighting")
	main.add_child(main.view)
	var b := main.driver.reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	main.view.setup(main.driver.reader, biome.palette, half + 4.0)
	main.view.rig.shake_enabled = GameSettings.get_value(main.profile, "shake") == "on"
	main.view.ink.set_style(
		InkPass.style_from_setting(GameSettings.get_value(main.profile, "outline"))
	)
	var player_input := PlayerInput.new(main.view.rig, main.driver.reader)
	player_input.name = "PlayerInput"
	main.view.add_child(player_input)
	main.driver.input_source = player_input.sample
	main.driver.ticked.connect(main.view.sync)
	main.driver.edited.connect(main.view.sync)
	main.audio.detach()
	main.audio.attach(main.driver.reader, biome.id)
	return player_input
