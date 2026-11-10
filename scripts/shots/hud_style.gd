extends SceneTree
## HUD shots (v0.3.0 UI, L21, L23, L24; the calm HUD of v0.3.5 F15 and the straight heat bar of F2; v0.11.1 Step 12:
## the HUD has one style, Astral): the real main.tscn on a run, posed by a script (a tool, not a test: it sets the run
## clock, HP, shards, items and Overclock heat directly). The game's own HUD in play: full HP mid-tier, then low HP
## (the warning on) with floor 1's title card on screen.
## Needs a renderer (off screen):
##   godot --path . --position -10000,-10000 -s scripts/shots/hud_style.gd -- lang=en
## Writes each shot and hud_style.png (the 2 frames side by side) to build/shots/<config/version>/hud_style/<lang>/.
## Evidence copies are made by hand.

## Overclock heat in the shots: Hot, past its tick (the bar's colour and the VENT prompt show).
const HEAT := 58
const SETTLE := 50
## The shots wait for the hero to land (the HUD is hidden until then, Hud._landing), up to this many frames.
const LAND_MAX := 1200

var main: Main
var _lang := "en"
var _out := ""
var _step := 0
var _frames := 0
## The frame the HUD showed (the hero landed) in step 1; -1 before.
var _shown_at := -1
var _play_shots: Array[Image] = []


func _initialize() -> void:
	_lang = ScriptArgs.parse().get("lang", _lang)
	_out = "res://build/shots/%s/hud_style/%s/" % [GameVersion.label(), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print(
		(
			"hud_style: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _world() -> World:
	return main.driver.world


func _game_hud() -> Hud:
	return main.get_node("UI/Hud") as Hud


## A posed run: some shards, three items and Hot heat, at `hp` and `run_ticks`.
func _pose(hp: int, run_ticks: int) -> void:
	var w := _world()
	w.actors.invuln[0] = 1 << 24
	w.actors.hp[0] = hp
	w.run_ticks = run_ticks
	w.shards = 147
	if w.heat == null:
		var repo := ContentRepository.load_all()
		Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.heat.milli = HEAT * HeatTable.MILLI
	w.heat.idle = 0
	Heat.advance(w)
	if w.items_owned.is_empty():
		for k in 3:
			w.add_item(k)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_pose(100, 1 * 1800 + 1100)
				_next()
		1:
			var landed := _frames > 10 and _game_hud().visible and not main.driver.reader.arriving()
			if _shown_at < 0 and (landed or _frames >= LAND_MAX):
				_shown_at = _frames
				if not landed:
					push_error("hud_style: the HUD never showed (the hero did not land)")
			if _shown_at >= 0:
				_pose(100, 1 * 1800 + 1100)
			if _shown_at >= 0 and _frames == _shown_at + SETTLE:
				_play_shots.append(_shot("play_full_hp"))
				_pose(22, 1 * 1800 + 1300)
				_game_hud().show_floor(main.run.floor_index, String(_biome_key()))
				_next()
		2:
			_pose(22, 1 * 1800 + 1300)
			if _frames == 30:
				_play_shots.append(_shot("play_low_hp"))
				_save_sheet()
				quit(0)
	if _frames > 4000:
		push_error("hud_style: stuck at step %d" % _step)
		quit(1)
	return false


func _biome_key() -> StringName:
	var b: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", main.run_biome_id())
	return b.name_key


func _next() -> void:
	_step += 1
	_frames = 0


func _shot(shot_name: String) -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out + shot_name + ".png")
	print("hud_style: ", _out + shot_name + ".png")
	return img


func _save_sheet() -> void:
	var w := _play_shots[0].get_width()
	var h := _play_shots[0].get_height()
	var pw := 960
	var ph := int(h * float(pw) / w)
	var play := Image.create(pw * 2, ph, false, Image.FORMAT_RGB8)
	for i in _play_shots.size():
		var img := _play_shots[i].duplicate() as Image
		img.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
		play.blit_rect(img, Rect2i(0, 0, pw, ph), Vector2i(i * pw, 0))
	play.save_png(_out + "hud_style.png")
	print("hud_style: sheet ", play.get_size())
