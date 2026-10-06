extends SceneTree
## Screenshot tour of the real game (PRESENTATION_CONTRACTS §10): boots main.tscn and drives it with input
## events, saving PNGs to build/shots/<version>/<lang>/. Needs a renderer (not --headless):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tour.gd -- lang=es

var _main: Main
var _frame := 0
var _lang := "en"
var _dir := ""
var _script: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			_lang = arg.trim_prefix("lang=")
	_dir = "res://build/shots/%s/%s/" % [GameVersion.label(), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	# [frame, action]: menu -> credits -> back -> play -> move -> pause -> main menu -> options.
	_script = [
		[10, _shot.bind("01_main_menu")],
		[12, _key.bind(KEY_DOWN, true)],
		[13, _key.bind(KEY_DOWN, false)],
		[14, _key.bind(KEY_DOWN, true)],
		[15, _key.bind(KEY_DOWN, false)],
		[16, _key.bind(KEY_ENTER, true)],
		[17, _key.bind(KEY_ENTER, false)],
		[24, _shot.bind("02_credits")],
		[26, _key.bind(KEY_ENTER, true)],
		[27, _key.bind(KEY_ENTER, false)],
		[32, _key.bind(KEY_ENTER, true)],
		[33, _key.bind(KEY_ENTER, false)],
		[36, _shot.bind("03_utility_picker")],
		[37, _key.bind(KEY_ENTER, true)],
		[38, _key.bind(KEY_ENTER, false)],
		[44, _shot.bind("03_stage")],
		[41, _key.bind(KEY_D, true)],
		[81, _key.bind(KEY_D, false)],
		[82, _key.bind(KEY_W, true)],
		[112, _key.bind(KEY_W, false)],
		[120, _shot.bind("04_stage_moved")],
		[122, _key.bind(KEY_ESCAPE, true)],
		[123, _key.bind(KEY_ESCAPE, false)],
		[130, _shot.bind("05_pause")],
		[132, _key.bind(KEY_DOWN, true)],
		[133, _key.bind(KEY_DOWN, false)],
		[134, _key.bind(KEY_ENTER, true)],
		[135, _key.bind(KEY_ENTER, false)],
		[142, _key.bind(KEY_DOWN, true)],
		[143, _key.bind(KEY_DOWN, false)],
		[144, _key.bind(KEY_ENTER, true)],
		[145, _key.bind(KEY_ENTER, false)],
		[152, _shot.bind("06_options")],
		[154, quit.bind(0)],
	]


func _process(_delta: float) -> bool:
	_frame += 1
	for step: Array in _script:
		if step[0] == _frame:
			(step[1] as Callable).call()
	return false


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(name: String) -> void:
	var path := _dir + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("tour: ", path)
