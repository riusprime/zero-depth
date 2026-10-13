extends SceneTree
## v0.7.5 AC screenshots (needs a renderer, not --headless): the Codex's Achievements page from the main menu (its
## top, then scrolled), and a run's first floor with the toast its biome's achievement raises, in one language. Shot
## setup only: a memory-only profile with a few achievements and counters (as a few runs would leave it); the menus
## are reached by key presses and the run is started by Main.start_stage (the build picker skipped). The real input
## path is tests/e2e/test_e2e_achievements.gd.
##   godot --path . --fixed-fps 60 --resolution 1920x1080 -s scripts/shots/achievements.gd -- lang=es size=1280x720
##   -> build/shots/v0.7.5/achievements/<lang>_<size>_<shot>.png

const OUT := "res://build/shots/v0.7.5/achievements/"

var _main: Main
var _frame := 0
var _step := 0
var _wait := 0
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
			"achievements: renderer=%s lang=%s size=%s"
			% [RenderingServer.get_current_rendering_method(), _lang, _size]
		)
	)
	var dims := _size.split("x")
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	profile.section("loadout")["build"] = "gun"
	var codex := CodexStore.new(profile)
	codex.add(&"enemies", &"charger", &"kills", 64)
	codex.add(&"bosses", &"warlord", &"kills")
	var store := AchievementStore.new(profile)
	for id: StringName in [&"clear_floor_1", &"kills_1", &"boss_warlord", &"no_hit_room"]:
		store.unlock(id)
	store.add_stat(&"floors:cleared_1", 2)
	store.add_stat(&"rooms:sealed_cleared", 4)
	store.add_stat(&"shards:spent", 185)
	store.raise_stat(&"wand:cards_max", 5)
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10 or _frame % 2 == 1:
		return false
	var focus := root.gui_get_focus_owner()
	var codex := _main.get_node_or_null("UI/CodexView") as CodexView
	match _step:
		0:  # down the main menu to its Codex row, then in
			if focus != null and focus.name == &"Codex":
				_tap(KEY_ENTER)
				_step = 1
			else:
				_tap(KEY_DOWN)
		1:  # E to the Achievements page
			if codex != null and codex.page == CodexView.ACHIEVEMENTS:
				_step = 2
				_wait = _frame + 10
			elif codex != null:
				_tap(KEY_E)
		2:
			if _frame >= _wait:
				_shot("page")
				_step = 3
				_wait = _frame + 16
		3:  # down the rows, so the list scrolls
			if _frame < _wait:
				_tap(KEY_DOWN)
			else:
				_shot("page_scrolled")
				_tap(KEY_ESCAPE)
				_step = 4
				_wait = _frame + 6
		4:
			if _frame >= _wait:
				_main.start_stage()
				_step = 5
				_wait = _frame + 40
		5:
			if _frame >= _wait:
				_shot("toast")
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


func _shot(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "%s_%s_%s.png" % [_lang, _size, shot])
	img.save_png(path)
	print("achievements: shot ", path, " ", img.get_size())
