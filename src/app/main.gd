class_name Main
extends Node
## Composition root (ARCHITECTURE §2): boots the input map, profile and settings, then runs the menus and the
## stage. Only app/ may wire layers together.

const STAGE_SEED := 20261006
const END_PANEL_DELAY_TICKS := 45
## Run flow (v0.3.0 B): the run's data, and the fade-in from black when a floor starts.
const RUN_ID := &"three_floors"
const FADE_SECONDS := 0.45
## v0.3.5 PT: a floor that opens on the arrival column fades in faster, so the column shows.
const ARRIVAL_FADE_SECONDS := 0.2

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()
## The run in progress (null outside one): floors, biome order, carry, totals. _stage_seed is its run seed.
var run: RunState
## Sounds, ambience and captions (v0.3.0 AU); it outlives floors so the ambience can crossfade.
var audio := AudioDirector.new()
## v0.4.0 SV: the run save (room entries, close, Continue).
var saves: RunSaver

var _menu: Control
var _pause: PauseMenu
## Options opened from the pause menu (v0.3.0 O), over the paused stage.
var _pause_options: OptionsMenu
var _dev: DevPanel
var _hud: Hud
var _end: EndPanel
## Ticks since the fight ended; the end panel waits a moment so the last hit reads.
var _ended_ticks := 0
var _stage_seed := STAGE_SEED
var _run_biomes: Array[StringName] = []
var _fade := ColorRect.new()
var _fade_left := 0.0
var _fade_len := FADE_SECONDS


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().theme = load(ThemePalette.UI_THEME)
	InputDefaults.apply()
	profile = ProfileStore.shared()
	saves = RunSaver.new(RunSaveStore.shared())
	InputRemap.apply(profile)
	GameSettings.apply_all(profile)
	audio.setup(profile)
	add_child(audio)
	ViewPrefs.apply_settings(profile)  # v0.3.0 O: reduced motion, colour-blind palette
	ui.name = "UI"
	add_child(ui)
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	ui.add_child(_fade)
	show_main_menu()


func _process(delta: float) -> void:
	if _fade_left > 0.0:
		_fade_left = maxf(0.0, _fade_left - delta)
		_fade.color.a = _fade_left / _fade_len
		_fade.visible = _fade_left > 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		saves.close()  # v0.4.0 SV: the last room entry is on disk
		profile.save_file()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if (
		driver != null
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_QUOTELEFT
		and DevPanel.unlocked()
	):
		get_viewport().set_input_as_handled()
		toggle_dev_panel()
		return
	if (
		driver != null
		and _end == null
		and not driver.reader.choosing()  # Rewards: the pick's own cancel comes first.
		and not driver.reader.event_open()  # v0.5.0 EV: so does an event panel's
		and not driver.reader.shop_open()  # v0.5.0 SH: so does the shop's
		and event.is_action_pressed(&"pause")
	):
		get_viewport().set_input_as_handled()
		if _pause == null:
			open_pause()
		else:
			close_pause()


func is_playing() -> bool:
	return driver != null


func show_main_menu() -> void:
	saves.close()  # v0.4.0 SV: leaving a run (pause -> Main menu) keeps its last room entry
	_end_stage()
	audio.set_ambience(&"")
	var m := MainMenu.new(GameVersion.label(), OS.is_debug_build(), saves.store.has_save())
	m.continue_pressed.connect(continue_run)
	m.play_pressed.connect(show_build_picker)
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)
	m.galleries_pressed.connect(show_gallery)
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


## Play -> pick the build (v0.3.0 L15: Blade or Gun) -> the run. The pick is remembered in the profile; the build is
## the run's (RunState.build_id) and holds on every floor. v0.4.0 BS (owner F11, PD-01 flipped): there is no utility
## pick any more; Blink and Aegis are ability cards found in the run.
func show_build_picker() -> void:
	var defs := ContentRepository.load_all().all_of(&"build")
	var last := StringName(profile.section("loadout").get("build", "blade"))
	var p := BuildPicker.new(defs, last)
	p.picked.connect(
		func(id: StringName) -> void:
			profile.section("loadout")["build"] = String(id)
			start_stage()
	)
	p.back_pressed.connect(show_main_menu)
	_set_menu(p)


func show_options() -> void:
	var o := OptionsMenu.new(profile)
	o.back_pressed.connect(show_main_menu)
	o.setting_changed.connect(_on_setting_changed)
	_set_menu(o)


## Options from the pause menu (v0.3.0 O): the pause menu hides under it and comes back on Back.
func open_pause_options() -> void:
	if _pause == null or _pause_options != null:
		return
	_pause.visible = false
	_pause_options = OptionsMenu.new(profile, OptionsMenu.Layout.SIDEBAR, true)
	_pause_options.setting_changed.connect(_on_setting_changed)
	_pause_options.back_pressed.connect(close_pause_options)
	ui.add_child(_pause_options)
	_pause_options.focus_first()


func close_pause_options() -> void:
	if _pause_options != null:
		_pause_options.queue_free()
		_pause_options = null
	if _pause != null:
		_pause.visible = true
		(_pause.box.get_node("Options") as Button).grab_focus()


## A setting changed in Options: what lives in the view follows at once (GameSettings already applied the engine's).
func _on_setting_changed(_key: String) -> void:
	ViewPrefs.apply_settings(profile)
	if view != null:
		view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
		view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
		view.stage.set_lighting(GameSettings.get_value(profile, "lighting"))


func show_credits() -> void:
	var credits: CreditsDefinition = ContentRepository.load_all().get_def(&"credits", &"main")
	var c := CreditsView.new(credits)
	c.back_pressed.connect(show_main_menu)
	_set_menu(c)


func show_gallery() -> void:
	_set_menu(null)
	var g := Gallery.new()
	g.name = "Gallery"
	add_child(g)
	g.setup(&"ruins", 35.26, &"xray", true)


## Starts a run (v0.3.0 B) with the run seed _stage_seed, on its first floor.
func start_stage() -> void:
	_set_menu(null)
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", RUN_ID)
	_run_biomes = run_def.biomes.duplicate()
	var build := StringName(profile.section("loadout").get("build", "blade"))
	run = RunState.start(_stage_seed, ContentCompiler.compile_run(run_def), build)
	_start_floor(repo)


## v0.4.0 SV: Continue resumes the saved run at its last room entry. A save that doesn't fit is set aside.
func continue_run() -> void:
	var save := saves.store.read()
	if not RunSaver.is_usable(save):
		if not save.is_empty():
			saves.store.reject("payload version %s" % str(save.get("version")))
		show_main_menu()
		return
	_set_menu(null)
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", RUN_ID)
	_run_biomes = run_def.biomes.duplicate()
	_stage_seed = int(save["run"]["stage_seed"])
	run = RunSaver.run_from(save, ContentCompiler.compile_run(run_def))
	var err := _start_floor(repo, save)
	if err != "":
		saves.store.reject(err)
		show_main_menu()


## Builds the run's current floor: its seed, biome and enemy scaling from the run, the carry applied. `resume`: a
## save's payload (v0.4.0 SV), whose world snapshot is then written into the fresh floor; returns why it didn't fit.
func _start_floor(repo: ContentRepository = null, resume: Dictionary = {}) -> String:
	if repo == null:
		repo = ContentRepository.load_all()
	var def: PlayerDefinition = repo.get_def(&"player", &"runner")
	var biome: BiomeDefinition = repo.get_def(&"biomes", _run_biomes[run.biome_of()])
	var table := ContentCompiler.compile_player(def)  # v0.4.0 BS (F11): no utility at the start
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))  # v0.3.0 L15: the run's build.
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	# The floor's boss (v0.3.0 C): drawn from its floor's pool, scaled like the enemies; its arena sizes the room.
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(repo, run.floor_index))
	var arena := (
		BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
		if boss >= 0
		else null
	)
	var world := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_floor_spawning(repo, run.floor_index),  # v0.4.0 TU: with the floor's curve
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),  # v0.3.0 E: altars, chests, shards.
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),  # v0.3.0 G: named combos.
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine")),  # v0.3.0 L19: the gamble shrine.
		ContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))  # v0.5.5 AR: the sealed arenas
	)
	FloorScenario.add_shop(world, ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal")))  # v0.5.0 SH
	world.set_boss_tables(bosses)  # Bosses (v0.3.0 C), scaled for the floor like the enemies.
	world.ability_tables = ContentCompiler.compile_abilities(repo)  # v0.4.0 BS: the four slots,
	world.stat_tables = ContentCompiler.compile_stat_cards(repo)  # the stat cards,
	world.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))  # v0.4.0 AB
	world.legendary_table = ContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), world.stat_tables, world.item_tables
	)
	Abilities.grant_start(world)  # slot 1 = the build's weapon (floor 1; later floors carry it)
	Abilities.start_floor(world)
	if world.boss_flow != null:  # v0.3.5 PT: the portal's way in, and the arrival on floors after the first.
		world.boss_flow.set_transit(ViewPrefs.reduced_motion, run.floor_index > 1)
	Heat.enable(world, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))  # v0.3.0 L18
	EventCompiler.setup(world, repo)  # v0.5.0 EV: event rooms and curses, after the carry and the heat
	# v0.5.5 DS (D4): the hidden catch-up, read from the whole build once everything above is set up.
	world.catch_up_table = ContentCompiler.compile_catch_up(repo.get_def(&"scaling", &"catch_up"))
	CatchUp.start_floor(world)
	if not resume.is_empty():  # v0.4.0 SV: back to the saved room entry
		var err := WorldSnapshot.apply(world, resume["world"])
		if err != "":
			return err
	saves.begin_floor(world, run, _stage_seed, resume.get("rooms", PackedByteArray()))
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(world)
	add_child(driver)
	view = WorldViewRoot.new()
	view.name = "WorldView"
	view.stage.prop_style = biome.id
	view.stage.mood = biome.mood  # v0.5.9: the biome's lighting mood
	view.stage.lighting = GameSettings.get_value(profile, "lighting")
	add_child(view)
	# The boss room makes the floor's bounds lopsided; props scatter over a square centred on the origin.
	var b := driver.reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	view.setup(driver.reader, biome.palette, half + 4.0)
	view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
	view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
	var player_input := PlayerInput.new(view.rig, driver.reader)
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.ticked.connect(view.sync)
	audio.attach(driver.reader, biome.id)
	driver.ticked.connect(audio.sync.bind(driver.reader))
	_hud = Hud.new()
	_hud.minimap.state.preset = saves.rooms.duplicate()  # v0.4.0 SV: the rooms already entered
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	_hud.pick_panel().picked.connect(driver.latch.note_pick)  # Rewards: a pick is input.
	_hud.shop.panel.picked.connect(driver.latch.note_pick)  # v0.5.0 SH: so is a shop action.
	_hud.sync(driver.reader)
	_hud.show_floor(
		run.floor_index,
		String(biome.name_key),
		run.is_deep(),  # v0.5.0 RT: "Floor 2 · Deep"
		driver.reader.shards_left_behind() if resume.is_empty() else 0  # v0.5.5 EC (Q-S4)
	)
	_ended_ticks = 0
	driver.ticked.connect(_on_tick.bind(driver))
	_fade_len = FADE_SECONDS if run.floor_index == 1 else ARRIVAL_FADE_SECONDS
	_fade_left = _fade_len
	_fade.color.a = 1.0
	_fade.visible = true
	ui.move_child(_fade, ui.get_child_count() - 1)
	return ""


func _on_tick(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return  # a stage that already ended, ticking once more before it's freed
	saves.after_tick(driver.world, run, _stage_seed)  # v0.4.0 SV: a first entry into a room saves
	_hud.sync(driver.reader)
	var outcome := driver.reader.outcome()
	if outcome == 3 and _end == null:
		_next_floor()
		return
	if outcome == 0 or _end != null:
		return
	if _ended_ticks == 0:
		saves.discard()  # v0.4.0 SV: a death or a win ends the run's save
	_ended_ticks += 1
	if _ended_ticks >= END_PANEL_DELAY_TICKS:
		show_end_panel(outcome == 1)


## The run's portal was taken: carry over, then the next floor (with its card and a fade-in).
func _next_floor() -> void:
	run.finish_floor(driver.world)
	_end_floor()
	_start_floor()


func show_end_panel(won: bool) -> void:
	close_pause()
	_end = EndPanel.new(
		won, driver.reader.killer_kind(), driver.reader.killer_cause_key(), run_recap()
	)
	_end.restart_pressed.connect(restart)
	_end.main_menu_pressed.connect(show_main_menu)
	ui.add_child(_end)
	_end.focus_first()


## The run recap's numbers (EndPanel): floor reached, run time and kills over every floor, shards when the world
## counts them, and the items held.
func run_recap() -> Dictionary:
	if run == null or driver == null:
		return {}
	var w := driver.world
	var names: Array[String] = []
	for idx in driver.reader.items_owned():
		names.append(String(driver.reader.item_name_key(idx)))
	var out := {
		"floor": run.floor_index,
		"floors": run.table.floors,
		"seconds": float(run.total_ticks(w)) / SimTick.TICKS_PER_SECOND,
		"kills": run.total_kills(w),
		"items": names,
		"routes": run.routes.duplicate(),  # v0.5.0 RT: the route of each floor reached
	}
	if &"shards" in w:
		out["shards"] = int(w.get(&"shards"))
	out["threat"] = driver.reader.threat()  # v0.5.0 EV: threat T now, and the run's peak
	out["threat_peak"] = driver.reader.threat_peak()
	return out


## The current floor's biome id.
func run_biome_id() -> StringName:
	return _run_biomes[run.biome_of()] if run != null else &""


## A new run with the next seed and the same build.
func restart() -> void:
	_stage_seed += 1
	_end_stage()
	start_stage()


func toggle_dev_panel() -> void:
	if _dev != null:
		_dev.queue_free()
		_dev = null
		driver.debug = null
		return
	driver.debug = DebugApi.new(driver.world)
	driver.debug.reseed_requested.connect(_reseed)
	_dev = DevPanel.new(driver.debug)
	ui.add_child(_dev)


func is_dev_panel_open() -> bool:
	return _dev != null


func _reseed(seed_value: int) -> void:
	_stage_seed = seed_value
	_end_stage()
	start_stage()


func open_pause() -> void:
	driver.paused = true
	_pause = PauseMenu.new()
	_pause.resume_pressed.connect(close_pause)
	_pause.options_pressed.connect(open_pause_options)
	_pause.restart_pressed.connect(restart)
	_pause.main_menu_pressed.connect(show_main_menu)
	if driver.reader.has_gamble():  # v0.3.0 L19: the stats won at the gamble shrine.
		var stats := GambleStatsPanel.new()
		_pause.add_child(stats)
		stats.place_top_right(84)
		stats.sync(driver.reader)
	if driver.reader.threat_peak() > 0:  # v0.5.0 EV: threat T and the curses held
		var threat := ThreatPanel.new()
		_pause.add_child(threat)
		threat.place_top_left(84)
		threat.sync(driver.reader)
	ui.add_child(_pause)
	_pause.focus_first()


func close_pause() -> void:
	if _pause_options != null:
		_pause_options.queue_free()
		_pause_options = null
	if _pause != null:
		_pause.queue_free()
		_pause = null
	if driver != null:
		driver.paused = false


func _set_menu(m: Control) -> void:
	if _menu != null:
		_menu.queue_free()
	_menu = m
	if m != null:
		ui.add_child(m)
		if m.has_method("focus_first"):
			m.call("focus_first")


func _end_stage() -> void:
	_end_floor()
	run = null


## Frees one floor's nodes (driver, view, HUD, panels); the run itself stays.
func _end_floor() -> void:
	close_pause()
	audio.detach()
	for n in [_hud, _end, _dev, driver, view, get_node_or_null("Gallery")]:
		_drop(n)
	_hud = null
	_end = null
	_dev = null
	driver = null
	view = null


## Takes a node out of the tree now and frees it at the end of the frame, so the next floor's nodes get their plain
## names (UI/Hud, SimDriver, WorldView) in the same frame.
static func _drop(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()
