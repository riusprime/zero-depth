extends SceneTree
## v0.8.0 GF1 (owner O18, O19): renders the Gun's blue pulse in flight and the hero's cast flourish (the spark and
## the swirl at the muzzle, the body's accent) in the real game view (WorldViewRoot on the Ruins stage, the iso camera)
## of a real World with the data's Gun (data/player/runner.tres + the Gun build), Shoot held at a dummy. Needs a
## renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/gun_feel.gd
## Writes build/shots/<version>/gf1/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [label, cards, camera size, ticks of Shoot before the grab (at least), grab on a shot's tick, frames to settle].
const PLAN := [
	["pulses_in_flight", [], 11.0, 40, false, 4],
	["cast_flourish_closeup", [], 5.0, 30, true, 2],
	["cast_flourish_swirl", [], 5.0, 30, true, 6],
	["big_shot_pulses", [&"gun_big_shot"], 11.0, 40, false, 4],
	["cinder_shot_pulses", [&"cinder_shot"], 11.0, 40, false, 4],
	["rapid_fire_pulses", [&"gun_rapid_fire"], 11.0, 40, false, 4],
]
const SIZE := Vector2i(1280, 720)
const DUMMY_AT := Vector2(6.0, 0.0)

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _reader: WorldReader
var _k := 0
var _ticks := 0
var _settle := -1
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/gf1/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	return -1


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	for id: StringName in spec[1]:
		_world.add_item(_item(id))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.add_dummy(DUMMY_AT, 0.35, 1 << 20)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = spec[2]
	_view.rig.camera.size = spec[2]
	var focus := Vector2(1.2, 0.0) if spec[2] < 8.0 else DUMMY_AT * 0.5
	_view.rig.snap_to(SimPlane.to_3d(focus))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0:
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 600, InputFrame.SHOOT, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= int(spec[3]) and (not bool(spec[4]) or _reader.shot_fired()):
			_settle = 0
		return false
	_settle += 1
	if _settle < int(spec[5]):  # frame-time animation (the flourish, the swell) runs these frames
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	print(
		"gun_feel: ",
		path,
		" (tick ",
		_ticks,
		", ",
		_view.pulses.count(),
		" pulses, ",
		_view.cast_fx.live_count(),
		" casts live of ",
		_view.cast_fx.started,
		")"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
