extends SceneTree
## v0.10.5 W3-O17: the in-run HUD in the Astral style, shot on the real game (main.tscn, the dev stage run, floor 1):
## normal play, low HP, the heat near the vent, the danger bar full, a boss fight with its bar, and an achievement
## toast. The world's fields are posed for each shot (shot setup: HP, heat, floor time, shards, a boss spawned by the
## hero); everything drawn is the real HUD reading the real WorldReader. A tool, not a test; it quits on every path.
## Needs a renderer (not --headless); open it off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3o17_astral_hud.gd
##   (-- 720 writes the *_720.png set; run it with --resolution 1280x720)
## Writes build/shots/v0.10.5/w3o17/{normal,low_hp,heat,danger_full,boss,toast}[_720].png.

const OUT := "res://build/shots/v0.10.5/w3o17/"
const MAX_FRAMES := 6000

var _main: Main
var _frame := 0
var _step := 0
var _wait := 0
var _suffix := ""
## The heat share held each frame while it is >= 0 (the sim cools it between frames).
var _heat_share := -1.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if OS.get_cmdline_user_args().has("720"):
		_suffix = "_720"
	TranslationServer.set_locale("es" if OS.get_cmdline_user_args().has("es") else "en")
	if OS.get_cmdline_user_args().has("es"):
		_suffix += "_es"
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("w3o17: gave up at step %d" % _step)
		quit(1)
		return false
	var dr := _main.driver
	if dr == null:
		if _frame == 3:
			_main.start_stage()
		return false
	var w := dr.world
	w.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	if _heat_share >= 0.0 and w.heat != null:
		w.heat.milli = int(w.heat.table.max_heat * HeatTable.MILLI * _heat_share)
	_wait -= 1
	if _wait > 0:
		return false
	match _step:
		0:
			if dr.reader.arriving():
				return false
			_next(90)
		1:
			w.shards = 120
			w.kills = 37
			w.actors.hp[0] = w.actors.max_hp[0] * 72 / 100
			w.run_ticks = SimTick.seconds_to_ticks(194.0)
			_heat(w, 0.3)
			_next(40)
		2:
			_shot("normal")
			w.actors.hp[0] = w.actors.max_hp[0] * 18 / 100
			_next(37)
		3:
			_shot("low_hp")
			w.actors.hp[0] = w.actors.max_hp[0] * 64 / 100
			_heat(w, 0.86)
			_next(30)
		4:
			_shot("heat")
			_heat(w, 0.2)
			w.run_ticks = SimTick.seconds_to_ticks(601.0)
			_next(40)
		5:
			_shot("danger_full")
			w.run_ticks = SimTick.seconds_to_ticks(250.0)
			_spawn_boss(w)
			_next(200)
		6:
			_shot("boss")
			var book := _main._achievements_book(_main._content())
			_main.toast.push(book.all()[0])
			_next(30)
		7:
			_shot("toast")
			print("w3o17: done")
			quit(0)
	return false


func _next(frames: int) -> void:
	_step += 1
	_wait = frames


## Shot setup: the heat at `share` of its max (none without heat).
func _heat(w: World, share: float) -> void:
	if w.heat == null:
		print("w3o17: this world has no heat")
	_heat_share = share


## Shot setup: the floor's first boss, a little away from the hero.
func _spawn_boss(w: World) -> void:
	if w.boss_tables.is_empty():
		print("w3o17: no boss tables")
		return
	w.spawn_boss(0, w.actors.pos(0) + Vector2(5.0, 0.0))


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT + shot_name + _suffix + ".png")
	img.save_png(path)
	print("w3o17: shot ", path)
