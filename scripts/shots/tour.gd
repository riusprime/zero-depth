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
	# [frame, action]
	_script = [
		[10, func() -> void: _shot("01_main_menu")],
		[12, func() -> void: _key(KEY_ENTER, true)],
		[13, func() -> void: _key(KEY_ENTER, false)],
		[20, func() -> void: _shot("02_stage")],
		[21, func() -> void: _key(KEY_D, true)],
		[61, func() -> void: _key(KEY_D, false)],
		[62, func() -> void: _key(KEY_W, true)],
		[92, func() -> void: _key(KEY_W, false)],
		[100, func() -> void: _shot("03_stage_moved")],
		[102, func() -> void: _key(KEY_ESCAPE, true)],
		[103, func() -> void: _key(KEY_ESCAPE, false)],
		[110, func() -> void: _shot("04_pause")],
		[112, func() -> void: quit(0)],
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
