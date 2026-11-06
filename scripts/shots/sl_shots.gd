extends SceneTree
## v0.9.5 SL screenshot (needs a renderer, not --headless): the real build picker of a new profile (the Blade padlocked
## with its condition, the Gun focused), settled. `-- --lang=en` or `--lang=es`. A tool, not a test.
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/sl_shots.gd -- --lang=en
## Writes build/shots/v0.9.5/sl/<lang>.png.

const OUT := "res://build/shots/v0.9.5/sl/"

var _lang := "en"
var _frame := 0
var _main: Main


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	TranslationServer.set_locale(_lang)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		_main.show_build_picker()
	elif _frame == 14:
		var p := _main.get_node_or_null("UI/BuildPicker") as BuildPicker
		if p != null:
			p.settle()
			p.focus_first()
	elif _frame == 30:
		var img := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path(OUT + "%s.png" % _lang)
		print("sl: saved %s (%s)" % [path, img.save_png(path)])
		quit()
	return false
