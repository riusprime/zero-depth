extends SceneTree
## v0.10.5 O5a + O5b shots (needs a renderer, not --headless): the hub Codex's Achievements page with its Records
## block (a memory-only profile holding a few records, as some runs would leave it), then loop 2's first floor card
## announcing the loop's new rule. Shot setup only: the run is moved into loop 2 the way RunState.finish_floor moves
## it through the Loop device (the real path is tests/e2e/test_e2e_ascension.gd), then Main loads that floor.
##   godot --path . --fixed-fps 60 --resolution 1600x900 --position -10000,-10000 -s scripts/shots/loops_o5.gd
##   -- lang=en  -> build/shots/v0.10.5/loops/<lang>_<shot>.png

const OUT := "res://build/shots/v0.10.5/loops/"

var _main: Main
var _frame := 0
var _step := 0
var _wait := 0
var _lang := "en"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			_lang = arg.trim_prefix("lang=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("loops: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	root.size = Vector2i(1600, 900)
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	profile.section("loadout")["build"] = "gun"
	RunRecords.note_loop(profile, &"gun", 3, 1)
	RunRecords.note_loop(profile, &"blade", 2, 2)
	RunRecords.note_win(profile, &"gun", 60 * (25 * 60 + 40), 3)
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		quit(1)
	if _frame < 10 or _frame % 2 == 1:
		return false
	match _step:
		0:  # SHOT SETUP: the Codex on its Achievements page, as the hub's Trophy Area opens it
			_main.show_codex(CodexView.ACHIEVEMENTS)
			_step = 2
			_wait = _frame + 20
		2:
			if _frame >= _wait:
				_shot("hub_records")
				_step = 3
				_wait = _frame + 6
		3:
			if _frame >= _wait:
				_main.start_stage()
				_step = 4
				_wait = _frame + 60
		4:
			if _frame >= _wait and _main.run != null and _main.driver != null:
				_into_loop_two()
				_step = 5
				_wait = _frame + 150
		5:
			var hud := _main.get_node_or_null("UI/Hud") as Hud
			if (
				_frame >= _wait
				and hud != null
				and hud.floor_card_showing()
				and hud.visible
				and _uncovered()
			):
				_shot("loop2_floor_card")
				print("loops: card ", hud.floor_card_text())
				print(
					"loops: dbg ",
					hud.is_visible_in_tree(),
					" ",
					hud.get_path(),
					" ",
					_main.get_node("UI").get_children().map(
						func(c): return "%s:%s" % [c.name, c.get(&"visible")]
					)
				)
				quit(0)
	return false


## SHOT SETUP: the run moved into loop 2's floor 1 as finish_floor does (the Loop device), then Main loads it.
func _into_loop_two() -> void:
	var run := _main.run
	run.loop_floors += run.table.floors
	run.loop = 2
	run.floor_index = 1
	run.call("_draw_loop_biomes")
	print("loops: rule ", LoopRules.draw(run))
	_main.call("_end_floor")
	_main.call("_load_plan", FloorPlan.next_floor(run, _main.get("_run_biomes"), {}, false))


## The loading cover has opened on the new floor (and the hero landed: the card fades from then).
func _uncovered() -> bool:
	if _main.loads.cover.showing():
		_wait = _frame + 30
		return false
	return _frame >= _wait


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
	var path := ProjectSettings.globalize_path(OUT + "%s_%s.png" % [_lang, shot])
	img.save_png(path)
	print("loops: shot ", path, " ", img.get_size())
