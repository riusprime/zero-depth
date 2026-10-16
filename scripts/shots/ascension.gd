extends SceneTree
## v0.7.5 AP shots: the Ascension portal on a real run's last floor (floor 3), drawn by the game's own WorldViewRoot
## with the floor's biome: dormant while the boss lives, open (the column risen), and floor 1's blue gate open for
## comparison. v0.8.0 P2 (owner O28, O24): the choice panel is gone; the open shot frames the Ascension portal and the
## Loop device beside it, a close shot the Loop device, and two shots Void's black holes (three set standing, with
## enemies round them). The world is never stepped: the portal's state and the holes are set for the view (the sim's
## own paths are tests/unit/sim/test_ascension.gd, test_black_holes.gd and the e2e tests).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/ascension.gd -- lang=en
## Options after `--`: seed=<run seed> (default 20261013), lang=<en|es> (default en), holes (only the black-hole shots).
## Writes build/shots/<version>/ascension/<lang>/. Quits on every path.

const SETTLE := 20
const RISE_FRAMES := 60

var _seed := 20261013
var _lang := "en"
var _dir := ""
var _view: WorldViewRoot
var _world: World
var _reader: WorldReader
var _layer: CanvasLayer
var _frame := 0
var _wait := 0
var _step := -1
var _holes_only := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("lang="):
			_lang = a.trim_prefix("lang=")
		elif a == "holes":
			_holes_only = true
	TranslationServer.set_locale(_lang)
	_dir = "res://build/shots/%s/ascension/%s/" % [GameVersion.label(), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print(
		(
			"ascension: renderer=%s device=%s seed=%d lang=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				_seed,
				_lang
			]
		)
	)
	_floor(3)


## Builds run floor `f`'s view as Main does (its biome's mood and look) and points the camera at its portal.
func _floor(f: int) -> void:
	if _view != null:
		_view.queue_free()
	if _layer != null:
		_layer.queue_free()
		_layer = null
	var run := SaveLab.run_state(_seed, f)
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", SaveLab.RUN_ID)
	var biome: BiomeDefinition = repo.get_def(&"biomes", run_def.biomes[run.biome_of()])
	_world = SaveLab.build_floor(run)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var b := _reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	_view.setup(_reader, biome.palette, half + 4.0)
	_view.rig.view_size = 13.0
	var facing := Kin.dir(_reader.portal_angle())
	_view.rig.snap_to(SimPlane.to_3d(_reader.portal_pos() + facing * 3.0))
	print("ascension: floor %d biome %s portal %s" % [f, biome.id, str(_reader.portal_pos())])


## Saves the frame as `shot_name`; on failure quits with 1 and returns false.
func _shot(shot_name: String) -> bool:
	var path := _dir + "%s.png" % shot_name
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("ascension: could not save %s" % path)
		_view = null
		quit(1)
		return false
	print("ascension: ", path)
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	if _view == null or _frame > 1500:
		quit(1)
	elif _wait > 0:
		_wait -= 1
	else:
		_step += 1
		_advance()
	return false


## The next shot: dormant, open (after the rise; both devices), the Loop device close, the black holes, then floor 1's
## blue gate.
func _advance() -> void:
	match _step:
		0:
			_wait = SETTLE
			if _holes_only:
				_world.boss_flow.state = BossFlow.State.OPEN
				_holes()
				_step = 3
		1:
			if _shot("1_dormant"):
				_world.boss_flow.state = BossFlow.State.OPEN  # the view's state only: the boss is dead
				_frame_devices(13.0)
				_view.sync()
				_wait = RISE_FRAMES
		2:
			if _shot("2_open_both_devices"):
				_view.rig.view_size = 7.0
				_view.rig.snap_to(SimPlane.to_3d(_reader.loop_device_pos()))
				_wait = SETTLE
		3:
			if _shot("3_loop_device_close"):
				_holes()
				_wait = SETTLE
		4:
			if _shot("4_black_holes"):
				_view.rig.view_size = 6.0
				_view.rig.snap_to(SimPlane.to_3d(_world.mx.hole_pos[1]))
				_wait = SETTLE
		5:
			if _shot("5_black_hole_close"):
				_floor(1)
				_world.boss_flow.state = BossFlow.State.OPEN
				_view.sync()
				_wait = SETTLE * 3
		6:
			if _shot("6_blue_gate_floor1"):
				quit(0)


## v0.8.0 P2: the camera between the Ascension portal and the Loop device.
func _frame_devices(size: float) -> void:
	var mid := (_reader.portal_pos() + _reader.loop_device_pos()) * 0.5
	mid += Kin.dir(_reader.portal_angle()) * 1.5
	_view.rig.view_size = size
	_view.rig.snap_to(SimPlane.to_3d(mid))
	print("ascension: portal %s loop device %s" % [_reader.portal_pos(), _reader.loop_device_pos()])


## v0.8.0 P2: three black holes set standing in the boss room's middle (ages 30, 60 and 90 ticks of 120), with standing
## enemies round them (state set for the view only).
func _holes() -> void:
	var c := _world.floor_layout.boss_spawn
	var at: Array[Vector2] = [c + Vector2(-3.0, 1.0), c + Vector2(0.0, -1.0), c + Vector2(3.0, 1.5)]
	for k in 3:
		BlackHoles.open(_world, at[k], 1)
		_world.mx.hole_from[k] = _world.tick - 30 * (k + 1)
	for q: Vector2 in [
		Vector2(1.2, 0.8), Vector2(-1.4, 0.3), Vector2(0.4, -1.6), Vector2(2.0, -0.6)
	]:
		_world.add_dummy(at[1] + q, 0.35, 100)
	_view.rig.view_size = 11.0
	_view.rig.snap_to(SimPlane.to_3d(c))
	_view.sync()
