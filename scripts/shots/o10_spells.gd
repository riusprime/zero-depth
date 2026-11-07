extends SceneTree
## v0.11.0 O10: pictures of the first spells for the owner, in English, in the real game (main.tscn, the dev stage run)
## with the world's fields posed for the shot: the Fire, Frost and Storm cards and their three spells held (Frost Nova,
## Fireball, Sky Strike), a standing pack in reach. cast.png: the tick after they cast (the nova's snowflake, the three
## bolts, the Fireball in flight, the HUD squares flashing); burst.png: the Fireball's burst on the pack, a sweep
## running. A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/o10_spells.gd
## Writes build/shots/v0.11.0/o10/{cast,burst}.png.

const OUT := "res://build/shots/v0.11.0/o10/"
const MAX_FRAMES := 4000
const CAST_STEPS := 6
const BURST_STEPS := 44

var _frame := 0
var _stage := 0
var _wait := 0
var _steps := 0
var _main: Main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	ViewPrefs.effects_density = "high"


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("o10: gave up at stage %d" % _stage)
		quit(1)
		return true
	if _main != null and _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
		if _main.hints != null:
			_main.hints.visible = false
	if _wait > 0:
		_wait -= 1
		return false
	if not _advance():
		return false
	if _stage == 7:
		print("o10: done")
		quit(0)
		return true
	return false


## One stage's work; false while it must run again next frame, true when the next stage is due (and taken).
func _advance() -> bool:
	match _stage:
		0:
			ProfileStore.use_shared(ProfileStore.new(""))
			_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
			root.add_child(_main)
		1:
			if _main.driver == null:
				_main.start_stage()
			if _main.driver == null or _main.driver.reader.arriving():
				return false
			_wait = 600
		2:
			_main.driver.paused = true  # from here the shot steps the sim by hand
			_pose(_main.driver.world)
			_steps = CAST_STEPS
		3, 5:
			if _steps > 0:
				_steps -= 1
				_main.driver.step_once()
				return false
			_wait = 3
		4:
			_shot("cast")
			_main.driver.world.spell_cd[0] = 360  # a pose: Frost Nova half cooled, so its sweep shows
			_steps = BURST_STEPS - CAST_STEPS
		6:
			_shot("burst")
	_stage += 1
	return true


## Shot setup: the three element cards and their spells, the enemies cleared from the hero's reach, and a standing pack:
## three close (the nova's), four 6 m off (the Fireball's densest pack).
func _pose(w: World) -> void:
	for id: StringName in [&"ember_core", &"frost_core", &"storm_core"]:
		w.add_item(AttackScenario.item_index(w.item_tables, id))  # past the 2 Element slots: a pose
	var me := w.player_pos()
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] != ActorStore.TEAM_PLAYER and w.actors.pos(i).distance_to(me) < 14.0:
			w.actors.set_pos(i, me + Vector2(40, 40))
	var at := me + Vector2(4.5, 3.5)
	for s: Vector2 in [Vector2(2.0, -1.0), Vector2(-1.5, 1.8), Vector2(1.0, 2.2)]:
		w.add_dummy(me + s, 0.4, 100000)
	for s: Vector2 in [Vector2.ZERO, Vector2(1.0, 0.4), Vector2(-0.6, 1.0), Vector2(0.5, -0.9)]:
		w.add_dummy(at + s, 0.4, 100000)
	w.dummy_speed = 0.0
	for k in [Spells.FROST_NOVA, Spells.FIREBALL, Spells.SKY_STRIKE]:
		Offers.apply(w, Offers.spell_code(k))


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("o10: shot ", path)
