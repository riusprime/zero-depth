extends SceneTree
## v0.9.5 MM screenshot (needs a renderer, not --headless): the main menu with no save (Play focused), saved to
## build/shots/v0.9.5/mm/<lang>.png, with the draw calls and primitives of the frame printed:
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mm.gd -- lang=es [blade=1]

var _main: Main
var _frame := 0
var _lang := "en"


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_lang = args.get("lang", _lang)
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	if args.get("blade", "") == "1":
		SwordLock.grant(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 120:
		var dir := "res://build/shots/v0.9.5/mm/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var suffix := "_blade" if SwordLock.is_unlocked(ProfileStore.shared()) else ""
		var path := dir + _lang + suffix + ".png"
		root.get_texture().get_image().save_png(path)
		print("mm: ", path)
		print(
			"mm: draw calls ",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" objects ",
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			" primitives ",
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			" fps ",
			Performance.get_monitor(Performance.TIME_FPS)
		)
		quit(0)
	return false
