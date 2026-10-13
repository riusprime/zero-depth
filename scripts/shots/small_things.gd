extends SceneTree
## v0.7.5 SM screenshots (needs a renderer, not --headless), in one language and size: a first run's opening with the
## move hint; an altar's pick with a held wand card ("Lv 2 → 3"), a new one ("Lv 1") and the HUD's wand pips with
## their levels; Options → Accessibility (interface size, Show hints, Reset hints); the credits with the generated
## licence list; and the pick again at the 125 % interface size. Shot setup only: a memory-only profile, the run started
## by Main.start_stage, the wand cards and the altar's offer written into the world directly (the real input paths
## are tests/e2e/test_e2e_hints.gd and test_e2e_card_levels.gd).
##   godot --path . --fixed-fps 60 --resolution 1280x720 -s scripts/shots/small_things.gd -- lang=es size=1280x720
##   -> build/shots/v0.7.5/small_things/<lang>_<size>_<shot>.png

const OUT := "res://build/shots/v0.7.5/small_things/"

var _main: Main
var _profile: ProfileStore
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
			"small_things: renderer=%s lang=%s size=%s"
			% [RenderingServer.get_current_rendering_method(), _lang, _size]
		)
	)
	var dims := _size.split("x")
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	_profile = ProfileStore.new("")
	_profile.section("settings")["language"] = _lang
	_profile.section("loadout")["build"] = "blade"
	ProfileStore.use_shared(_profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 30 == 0:
		print("small_things: frame %d step %d" % [_frame, _step])
	if _frame < 10:
		return false
	match _step:
		0:
			_main.start_stage()
			_step = 1
			_wait = _frame + 50
		1:
			if _frame >= _wait:
				_shot("move_hint")
				_open_pick()
				_step = 2
				_wait = _frame + 30
		2:
			if _frame >= _wait:
				_shot("pick_levels")
				_main.hints.store.mark(&"pick")
				_step = 3
				_main.show_options()
				_wait = _frame + 6
		3:
			if _frame >= _wait:
				var o := _main.get_node("UI/OptionsMenu") as OptionsMenu
				(o.tabs[&"accessibility"] as Button).grab_focus()
				_step = 4
				_wait = _frame + 10
		4:
			if _frame >= _wait:
				_shot("options_accessibility")
				_main.show_credits()
				_step = 5
				_wait = _frame + 10
		5:
			if _frame >= _wait:
				_shot("credits")
				GameSettings.set_value(_profile, "ui_scale", "125")
				_main.start_stage()
				_step = 6
				_wait = _frame + 50
		6:
			if _frame >= _wait:
				_open_pick()
				_step = 7
				_wait = _frame + 30
		7:
			if _frame >= _wait:
				_shot("pick_levels_ui125")
				_main.show_options()
				_step = 8
				_wait = _frame + 10
		8:
			if _frame >= _wait:
				_shot("options_ui125")
				_main.show_codex()
				_step = 9
				_wait = _frame + 10
		9:
			if _frame >= _wait:
				_shot("codex_ui125")
				_main.start_stage()
				_step = 10
				_wait = _frame + 50
		10:
			if _frame >= _wait:
				var w := _main.driver.world
				var arc := _code(w, &"wide_arc")
				BuildSlots.take(w, arc)
				CardLevels.set_level(w, arc, 2)
				BuildSlots.take(w, _code(w, &"double_slash"))
				_main.open_pause()
				_main.call("_open_pause_build")
				_step = 11
				_wait = _frame + 20
		11:
			if _frame >= _wait:
				_shot("build_page_ui125")
				quit(0)
	return false


## Shot setup: the hero holds Wide Arc at level 2; the nearest altar offers Wide Arc, Double Slash and a stat
## card, open.
func _open_pick() -> void:
	var w := _main.driver.world
	var arc := _code(w, &"wide_arc")
	if not w.items_owned.has(arc):
		BuildSlots.take(w, arc)
		CardLevels.set_level(w, arc, 2)
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
			best = i if best < 0 else best
	if best < 0:
		push_error("no altar")
		return
	w.rewards.set_offer(
		best, PackedInt32Array([arc, _code(w, &"double_slash"), Offers.STAT_BASE + 1])
	)
	w.choosing = w.rewards.ids[best]


func _code(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _shot(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "%s_%s_%s.png" % [_lang, _size, shot])
	img.save_png(path)
	print("small_things: shot ", path, " ", img.get_size())
