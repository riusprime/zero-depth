class_name Main
extends Node
## Composition root (ARCHITECTURE §2): boots the input map, profile and settings, then runs the menus and the
## stage. Only app/ may wire layers together.

const STAGE_SEED := 20261006

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()

var _menu: Control
var _pause: PauseMenu


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
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
	if driver != null and event.is_action_pressed(&"pause"):
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
	m.play_pressed.connect(start_stage)
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)
	m.galleries_pressed.connect(show_gallery)
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


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
	var world := StageScenario.build(STAGE_SEED, ContentCompiler.compile_player(def))
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
	for n in [driver, view, get_node_or_null("Gallery")]:
		if n != null:
			n.queue_free()
	driver = null
	view = null
