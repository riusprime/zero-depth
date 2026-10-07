extends SceneTree
## Renders the fight in one outline style (PLAN v0.1.0 Step 7c) for the owner's pick. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/outlines.gd -- style=sketch
## Writes build/shots/<version>/outlines/<style>.png. The fight is driven by real input events, a fixed number of
## physics ticks in, so every style shows the same moment.

const SHOT_TICK := 260

var _main: Main
var _style := "sketch"
var _frame := 0
var _ticks := 0
var _dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("style="):
			_style = arg.trim_prefix("style=")
	_dir = "res://build/shots/%s/outlines/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var profile := ProfileStore.new("")
	profile.section("settings")["outline"] = _style
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	if _main.driver != null:
		_ticks += 1
		if _ticks == 20:
			_key(KEY_D, true)
		if _ticks == 70:
			_key(KEY_D, false)
		if _ticks == SHOT_TICK:
			var path := _dir + _style + ".png"
			root.get_texture().get_image().save_png(path)
			print("outlines: ", path)
			quit(0)
	return false


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame in [8, 14]:
		_key(KEY_ENTER, true)
	if _frame in [9, 15]:
		_key(KEY_ENTER, false)
	return false


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
