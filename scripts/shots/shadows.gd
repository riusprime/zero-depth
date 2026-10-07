extends SceneTree
## Renders the arena standing still, for the shadow-edge evidence (v0.2.0 PLAN L2). Needs a renderer:
##   xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/shadows.gd -- tag=after
## Writes build/shadows/<tag>.png and prints the shadow settings it rendered with. --fixed-fps 60 makes one
## drawn frame per physics tick, so every run shows the same moment.

const SHOT_TICK := 40

var _main: Main
var _frame := 0
var _ticks := 0
var _tag := "shot"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tag="):
			_tag = arg.trim_prefix("tag=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shadows"))
	var profile := ProfileStore.new("")
	profile.section("settings")["outline"] = "ink"
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	if _main.driver == null:
		return false
	_ticks += 1
	if _ticks == SHOT_TICK:
		var path := "res://build/shadows/%s.png" % _tag
		root.get_texture().get_image().save_png(path)
		var light: DirectionalLight3D = (
			_main.find_children("*", "DirectionalLight3D", true, false)[0]
		)
		print("shadows: ", path)
		print(
			(
				"atlas=%s soft_quality=%s blur=%s mode=%s camera_far=%s"
				% [
					ProjectSettings.get_setting(
						"rendering/lights_and_shadows/directional_shadow/size"
					),
					ProjectSettings.get_setting(
						"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
					),
					light.shadow_blur,
					light.directional_shadow_mode,
					_main.view.rig.camera.far,
				]
			)
		)
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
