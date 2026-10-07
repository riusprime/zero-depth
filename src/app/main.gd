class_name Main
extends Node
## Composition root (ARCHITECTURE §2): boots the input map, profile and settings, then runs the menus and the
## stage. Only app/ may wire layers together.

const STAGE_SEED := 20261006
const END_PANEL_DELAY_TICKS := 45
## Run flow (v0.3.0 B): the run's data, and the fade-in from black when a floor starts.
const RUN_ID := &"three_floors"
const FADE_SECONDS := 0.45

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()
## The run in progress (null outside one): floors, biome order, carry, totals. _stage_seed is its run seed.
var run: RunState
## Sounds, ambience and captions (v0.3.0 AU); it outlives floors so the ambience can crossfade.
var audio := AudioDirector.new()

var _menu: Control
var _pause: PauseMenu
var _dev: DevPanel
var _hud: Hud
var _end: EndPanel
## Ticks since the fight ended; the end panel waits a moment so the last hit reads.
var _ended_ticks := 0
var _stage_seed := STAGE_SEED
var _run_biomes: Array[StringName] = []
var _fade := ColorRect.new()
var _fade_left := 0.0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().theme = load(ThemePalette.UI_THEME)
	InputDefaults.apply()
	profile = ProfileStore.shared()
	InputRemap.apply(profile)
	GameSettings.apply_all(profile)
	audio.setup(profile)
	add_child(audio)
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
		_fade.color.a = _fade_left / FADE_SECONDS
		_fade.visible = _fade_left > 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
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
	_end_stage()
	audio.set_ambience(&"")
	var m := MainMenu.new(GameVersion.label(), OS.is_debug_build())
	m.play_pressed.connect(show_build_picker)
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)
	m.galleries_pressed.connect(show_gallery)
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


## Play -> pick the build (v0.3.0 L15: Blade or Gun) -> pick the utility -> the run. Both picks are remembered in
## the profile; the build is the run's (RunState.build_id) and holds on every floor.
func show_build_picker() -> void:
	var defs := ContentRepository.load_all().all_of(&"build")
	var last := StringName(profile.section("loadout").get("build", "blade"))
	var p := BuildPicker.new(defs, last)
	p.picked.connect(
		func(id: StringName) -> void:
			profile.section("loadout")["build"] = String(id)
			show_utility_picker()
	)
	p.back_pressed.connect(show_main_menu)
	_set_menu(p)


## The utility pick, after the build. The pick is remembered in the profile.
func show_utility_picker() -> void:
	var repo := ContentRepository.load_all()
	var defs := repo.all_of(&"utility")
	defs.sort_custom(
		func(a: UtilityDefinition, b: UtilityDefinition) -> bool: return a.kind < b.kind
	)
	var last := StringName(profile.section("loadout").get("utility", "guard"))
	var p := UtilityPicker.new(defs, last)
	p.picked.connect(
		func(id: StringName) -> void:
			profile.section("loadout")["utility"] = String(id)
			start_stage()
	)
	p.back_pressed.connect(show_build_picker)
	_set_menu(p)


func show_options() -> void:
	var o := OptionsMenu.new(profile)
	o.back_pressed.connect(show_main_menu)
	_set_menu(o)


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


## Builds the run's current floor: its seed, biome and enemy scaling from the run, the carry applied.
func _start_floor(repo: ContentRepository = null) -> void:
	if repo == null:
		repo = ContentRepository.load_all()
	var def: PlayerDefinition = repo.get_def(&"player", &"runner")
	var biome: BiomeDefinition = repo.get_def(&"biomes", _run_biomes[run.biome_of()])
	var utility: UtilityDefinition = repo.get_def(
		&"utility", StringName(profile.section("loadout").get("utility", "guard"))
	)
	var table := ContentCompiler.apply_utility(ContentCompiler.compile_player(def), utility)
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))  # v0.3.0 L15: the run's build.
	var spawning: SpawnDirectorDefinition = repo.get_def(&"spawning", &"floor_1")
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
		ContentCompiler.compile_spawning(spawning, repo),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),  # v0.3.0 E: altars, chests, shards.
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),  # v0.3.0 G: named combos.
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))  # v0.3.0 L19: the gamble shrine.
	)
	world.set_boss_tables(bosses)  # Bosses (v0.3.0 C), scaled for the floor like the enemies.
	Heat.enable(world, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))  # v0.3.0 L18
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(world)
	add_child(driver)
	view = WorldViewRoot.new()
	view.name = "WorldView"
	view.stage.prop_style = biome.id
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
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	_hud.pick_panel().picked.connect(driver.latch.note_pick)  # Rewards: a pick is input.
	_hud.sync(driver.reader)
	_hud.show_floor(run.floor_index, String(biome.name_key))
	_ended_ticks = 0
	driver.ticked.connect(_on_tick.bind(driver))
	_fade_left = FADE_SECONDS
	_fade.color.a = 1.0
	_fade.visible = true
	ui.move_child(_fade, ui.get_child_count() - 1)


func _on_tick(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return  # a stage that already ended, ticking once more before it's freed
	_hud.sync(driver.reader)
	var outcome := driver.reader.outcome()
	if outcome == 3 and _end == null:
		_next_floor()
		return
	if outcome == 0 or _end != null:
		return
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
	}
	if &"shards" in w:
		out["shards"] = int(w.get(&"shards"))
	return out


## The current floor's biome id.
func run_biome_id() -> StringName:
	return _run_biomes[run.biome_of()] if run != null else &""


## A new run with the next seed and the same build and utility.
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
	_pause.restart_pressed.connect(restart)
	_pause.main_menu_pressed.connect(show_main_menu)
	if driver.reader.has_gamble():  # v0.3.0 L19: the stats won at the gamble shrine.
		var stats := GambleStatsPanel.new()
		_pause.add_child(stats)
		stats.place_top_right(84)
		stats.sync(driver.reader)
	ui.add_child(_pause)
	_pause.focus_first()


func close_pause() -> void:
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
