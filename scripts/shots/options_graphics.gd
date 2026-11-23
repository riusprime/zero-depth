extends SceneTree
## The Options screen's Display and Graphics pages, one shot each, from the real main.tscn. Needs a renderer (off
## screen):
##   godot --path . --position -10000,-10000 -s scripts/shots/options_graphics.gd -- lang=en
## Writes build/shots/<config/version>/options_graphics/<lang>/{display,graphics}.png.

const SETTLE := 40

var _main: Main
var _lang := "en"
var _out := ""
var _frames := 0
var _step := 0


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_lang = args.get("lang", _lang)
	_out = "res://build/shots/%s/options_graphics/%s/" % [GameVersion.label(), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE:
		return false
	match _step:
		0:
			_main.show_options()
			_open(&"display")
		2:
			_shot("display")
			_open(&"graphics")
		4:
			_shot("graphics")
			quit()
	_step += 1
	_frames = SETTLE - 20 if _step < 5 else _frames
	return false


func _open(id: StringName) -> void:
	var o := _main.get_node("UI/OptionsMenu") as OptionsMenu
	o._open(id)


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out + shot_name + ".png"))
	print("shot ", shot_name)
