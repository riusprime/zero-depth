extends SceneTree
## v0.7.5 CX screenshots (needs a renderer, not --headless): the Codex from the main menu, its four pages, in one
## language. Shot setup only: a memory-only profile with a few entries met (as a few runs would leave it); the menus
## are reached by key presses. The real input path is tests/e2e/test_e2e_codex.gd.
##   godot --path . --resolution 1920x1080 -s scripts/shots/codex.gd -- lang=es size=1280x720
##   -> build/shots/v0.7.5/codex/<lang>_<size>_<page>.png

const OUT := "res://build/shots/v0.7.5/codex/"

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
			"codex: renderer=%s lang=%s size=%s"
			% [RenderingServer.get_current_rendering_method(), _lang, _size]
		)
	)
	var dims := _size.split("x")
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	var codex := CodexStore.new(profile)
	for id: StringName in [
		&"gun_spread", &"gun_pierce", &"heavy", &"ember_core", &"trigger_on_hit", &"damage"
	]:
		codex.add(&"cards", id, &"offered", 3)
		codex.add(&"cards", id, &"taken", 2)
	codex.raise_to(&"cards", &"gun_spread", &"level", 3)
	codex.raise_to(&"cards", &"heavy", &"level", 2)
	for id: StringName in [&"charger", &"needle", &"swarmer", &"warden"]:
		codex.add(&"enemies", id, &"kills", 12)
	codex.add(&"enemies", &"charger", &"deaths")
	codex.add(&"bosses", &"warlord", &"fights", 2)
	codex.add(&"bosses", &"warlord", &"kills")
	codex.add(&"biomes", &"ruins", &"visits", 3)
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		10, 12, 14:
			_tap(KEY_DOWN)  # Play -> Options -> Credits -> Codex
		16:
			_tap(KEY_ENTER)
		30:
			_shot("cards_locked")
		31:
			_tap(KEY_DOWN)  # the second row's first card: Pierce, met
		40:
			_shot("cards")
		41:
			_tap(KEY_E)
		43, 45:
			_tap(KEY_RIGHT)  # the Charger
		50:
			_shot("enemies")
		51:
			_tap(KEY_E)
		53, 55, 57, 59, 61:
			_tap(KEY_RIGHT)  # the Warlord
		70:
			_shot("bosses")
		71:
			_tap(KEY_E)
		73, 75:
			_tap(KEY_RIGHT)  # the Ruins
		80:
			_shot("biomes")
		81:
			quit(0)
	return false


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
	print("codex: shot ", path, " ", img.get_size())
