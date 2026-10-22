extends SceneTree
## v0.7.5 AP shots: the Ascension portal on a real run's last floor (floor 3), drawn by the game's own WorldViewRoot
## with the floor's biome: dormant while the boss lives, open (the column risen), and floor 1's blue gate open for
## comparison. v0.8.0 P2 (owner O28, O24): the choice panel is gone; the open shot frames the Ascension portal and the
## Loop device beside it, a close shot the Loop device (v0.9.0 VP: the black-hole shots went with the floor black hole).
## The world is never stepped: the portal's state is set for the view (the sim's own paths are
## tests/unit/sim/test_ascension.gd and the e2e tests).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/ascension.gd -- lang=en
## Options after `--`: seed=<run seed> (default 20261013), lang=<en|es> (default en).
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


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("lang="):
			_lang = a.trim_prefix("lang=")
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


## The next shot: dormant, open (after the rise; both devices), the Loop device close, then floor 1's blue gate.
func _advance() -> void:
	match _step:
		0:
			_wait = SETTLE
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
				# v0.8.0 MI (owner O81): the owner's Ascension portal and its beam, close.
				_view.rig.view_size = 8.0
				_view.rig.snap_to(
					SimPlane.to_3d(_reader.portal_pos() + Kin.dir(_reader.portal_angle()) * 1.0)
				)
				_wait = SETTLE
		4:
			if _shot("3b_ascension_portal_close"):
				_floor(1)
				_world.boss_flow.state = BossFlow.State.OPEN
				_view.sync()
				_wait = SETTLE * 3
		5:
			if _shot("6_blue_gate_floor1"):
				quit(0)


## v0.8.0 P2: the camera between the Ascension portal and the Loop device.
func _frame_devices(size: float) -> void:
	var mid := (_reader.portal_pos() + _reader.loop_device_pos()) * 0.5
	mid += Kin.dir(_reader.portal_angle()) * 1.5
	_view.rig.view_size = size
	_view.rig.snap_to(SimPlane.to_3d(mid))
	print("ascension: portal %s loop device %s" % [_reader.portal_pos(), _reader.loop_device_pos()])
