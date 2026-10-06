class_name Main
extends Node
## Composition root (ARCHITECTURE §2): boots the input map, profile and settings, then runs the menus and the
## stage. Only app/ may wire layers together.

const STAGE_SEED := 20261006
const END_PANEL_DELAY_TICKS := 45

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()

var _menu: Control
var _pause: PauseMenu
var _dev: DevPanel
var _hud: Hud
var _end: EndPanel
## Ticks since the fight ended; the end panel waits a moment so the last hit reads.
var _ended_ticks := 0
var _stage_seed := STAGE_SEED


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().theme = load(ThemePalette.UI_THEME)
	InputDefaults.apply()
	profile = ProfileStore.shared()
	InputRemap.apply(profile)
	GameSettings.apply_all(profile)
	ui.name = "UI"
	add_child(ui)
	show_main_menu()


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
	if driver != null and _end == null and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _pause == null:
			open_pause()
		else:
			close_pause()


func is_playing() -> bool:
	return driver != null


func show_main_menu() -> void:
	_end_stage()
	var m := MainMenu.new(GameVersion.label(), OS.is_debug_build())
	m.play_pressed.connect(show_utility_picker)
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)
	m.galleries_pressed.connect(show_gallery)
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


## Play -> pick the utility -> the arena. The pick is remembered in the profile.
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
	p.back_pressed.connect(show_main_menu)
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


func start_stage() -> void:
	_set_menu(null)
	var repo := ContentRepository.load_all()
	var def: PlayerDefinition = repo.get_def(&"player", &"runner")
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	var utility: UtilityDefinition = repo.get_def(
		&"utility", StringName(profile.section("loadout").get("utility", "guard"))
	)
	var table := ContentCompiler.apply_utility(ContentCompiler.compile_player(def), utility)
	var encounter: EncounterDefinition = repo.get_def(&"encounters", &"combat_lab")
	var world := StageScenario.build(
		_stage_seed,
		table,
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_encounter(encounter, repo)
	)
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(world)
	add_child(driver)
	view = WorldViewRoot.new()
	view.name = "WorldView"
	add_child(view)
	view.setup(driver.reader, biome.palette, StageScenario.ARENA_HALF)
	var player_input := PlayerInput.new(view.rig, driver.reader)
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.ticked.connect(view.sync)
	_hud = Hud.new()
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	_hud.sync(driver.reader)
	_ended_ticks = 0
	driver.ticked.connect(_on_tick.bind(driver))


func _on_tick(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return  # a stage that already ended, ticking once more before it's freed
	_hud.sync(driver.reader)
	var outcome := driver.reader.outcome()
	if outcome == 0 or _end != null:
		return
	_ended_ticks += 1
	if _ended_ticks >= END_PANEL_DELAY_TICKS:
		show_end_panel(outcome == 1)


func show_end_panel(won: bool) -> void:
	close_pause()
	_end = EndPanel.new(won, driver.reader.killer_kind())
	_end.restart_pressed.connect(restart)
	_end.main_menu_pressed.connect(show_main_menu)
	ui.add_child(_end)
	_end.focus_first()


## A new fight with the next seed and the same utility.
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
	_pause.main_menu_pressed.connect(show_main_menu)
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
	close_pause()
	for n in [_hud, _end]:
		if n != null:
			n.queue_free()
	_hud = null
	_end = null
	if _dev != null:
		_dev.queue_free()
		_dev = null
	for n in [driver, view, get_node_or_null("Gallery")]:
		if n != null:
			n.queue_free()
	driver = null
	view = null
