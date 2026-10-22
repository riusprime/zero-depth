extends SceneTree
## v0.7.5 PG screenshots (needs a renderer, not --headless): the Playground from the main menu with the Gun, some
## dummies and a boss, the F1 panel's Build and Spawn tabs, the DPS meter after shooting, and the room in Frozen Shore
## and Starfall. Shot setup only: the dummies, the boss and the cards go in through PlaygroundApi, and the shooting is
## a held action; the real input path is tests/e2e/test_e2e_playground.gd.
##   godot --path . --resolution 1920x1080 -s scripts/shots/playground.gd -- lang=es size=1280x720
##   -> build/shots/v0.7.5/playground/<lang>_<size>_<shot>.png

const OUT := "res://build/shots/v0.7.5/playground/"

var _main: Main
var _frame := 0
var _lang := "en"
var _size := "1920x1080"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			_lang = arg.trim_prefix("lang=")
		elif arg.begins_with("size="):
			_size = arg.trim_prefix("size=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"playground: renderer=%s lang=%s size=%s"
			% [RenderingServer.get_current_rendering_method(), _lang, _size]
		)
	)
	var dims := _size.split("x")
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		10, 12, 14, 16:
			_tap(KEY_DOWN)  # Play -> Options -> Credits -> Codex -> Playground
		18:
			_shot("menu")
			_tap(KEY_ENTER)
		24:
			_tap(KEY_RIGHT)  # the Gun
		26:
			_tap(KEY_ENTER)
		40:
			_setup()
		41:
			_aim_and_shoot(true)
		400:
			_shot("dps")
			_aim_and_shoot(false)
		402:
			_tap(KEY_F1)
		410:
			_shot("panel_build")
		411:
			_main.playground.panel.tabs.current_tab = 1
		418:
			_shot("panel_spawn")
		419:
			_main.playground.panel.tabs.current_tab = 2
			_main.playground.panel.find_child("Biome_frozen_shore", true, false).emit_signal(
				&"pressed"
			)
		440:
			_shot("frozen_shore")
		441:
			_main.playground.panel.find_child("Biome_starfall", true, false).emit_signal(&"pressed")
		462:
			_tap(KEY_F1)
		470:
			_shot("starfall")
		471:
			quit(0)
	return false


## Three dummies in a row east of the player (endless, endless, 20 000 HP), a Warlord to the north, and a few cards.
func _setup() -> void:
	var api := _main.playground.api
	var w := _main.driver.world
	var p := w.player_pos()
	api.place_dummy(p + Vector2(4.0, -1.5))
	api.place_dummy(p + Vector2(4.5, 0.5))
	api.place_dummy(p + Vector2(5.0, 2.5), 20000)
	for b: Dictionary in api.boss_choices():
		if b["name_key"] == &"BOSS_WARLORD":
			api.place_boss(b["index"], p + Vector2(-9.0, -9.0))
	var granted := 0
	for e: Dictionary in api.catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND and granted < 3:
			api.grant(e["code"], 3)
			granted += 1
	for e: Dictionary in api.catalog():
		if e["group"] == PlaygroundApi.GROUP_ABILITY and e["name_key"] == &"ABILITY_ORBIT_BLADES":
			api.grant(e["code"], 2)
	api.god = true


func _aim_and_shoot(on: bool) -> void:
	var w := _main.driver.world
	var at := w.player_pos() + Vector2(4.5, 0.5)
	var screen := _main.view.rig.camera.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(page: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "%s_%s_%s.png" % [_lang, _size, page])
	img.save_png(path)
	print("playground: shot ", path, " ", img.get_size())
