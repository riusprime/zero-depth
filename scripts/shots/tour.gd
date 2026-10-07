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
		[44, _shot.bind("03a_build_picker")],  # v0.3.0 L15: the build screen, Blade focused
		[45, _key.bind(KEY_ENTER, true)],
		[46, _key.bind(KEY_ENTER, false)],
		[56, _shot.bind("03_stage")],
		[53, _key.bind(KEY_D, true)],
		[93, _key.bind(KEY_D, false)],
		[94, _key.bind(KEY_W, true)],
		[124, _key.bind(KEY_W, false)],
		[132, _shot.bind("04_stage_moved")],
		[133, _shot_when_telegraph.bind("04b_fight")],
		[334, _key.bind(KEY_ESCAPE, true)],
		[335, _key.bind(KEY_ESCAPE, false)],
		[342, _shot.bind("05_pause")],
		[344, _key.bind(KEY_DOWN, true)],
		[345, _key.bind(KEY_DOWN, false)],
		[346, _key.bind(KEY_ENTER, true)],
		[347, _key.bind(KEY_ENTER, false)],
		[354, _key.bind(KEY_DOWN, true)],
		[355, _key.bind(KEY_DOWN, false)],
		[356, _key.bind(KEY_ENTER, true)],
		[357, _key.bind(KEY_ENTER, false)],
		[364, _shot.bind("06_options")],
		[366, quit.bind(0)],
	]


func _process(_delta: float) -> bool:
	_frame += 1
	for step: Array in _script.duplicate():
		if step[0] == _frame:
			(step[1] as Callable).call()
	return false


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Waits (up to frame 320) until an enemy telegraph is on screen, then takes the shot.
func _shot_when_telegraph(name: String) -> void:
	if _main.view != null and _main.view.telegraphs.count() > 0:
		_shot(name)
	elif _frame < 320:
		_script.append([_frame + 1, _shot_when_telegraph.bind(name)])


func _shot(name: String) -> void:
	var path := _dir + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("tour: ", path)
