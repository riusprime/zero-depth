extends SceneTree
## v0.9.0 LZ / BM (owner C §6.2, §6.3; docs/roadmap/v0.9.0/evidence/LASER_BOMB.md): renders the Laser's beam once per
## element look (default energy, Fire, Lightning, Frost, Venom, Bleed) held at a dummy, and a bomb in flight and its
## blast (default, Fire), in the real game view
## (WorldViewRoot on the Ruins stage, the iso camera) of a real World with the data's Gun and cards, Shoot held. Needs a
## renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/laser_bomb.gd
## Writes build/shots/<version>/lzbm/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [label, cards (wand order), camera size, ticks of Shoot before the grab, frames to settle].
const PLAN := [
	["laser_default", [&"gun_laser"], 9.0, 20, 3],
	["laser_fire", [&"gun_laser", &"ember_core"], 9.0, 20, 3],
	["laser_lightning", [&"gun_laser", &"storm_core"], 9.0, 20, 3],
	["laser_frost", [&"gun_laser", &"frost_core"], 9.0, 20, 3],
	["laser_venom", [&"gun_laser", &"venom_core"], 9.0, 20, 3],
	["laser_bleed", [&"gun_laser", &"shared_bleed"], 9.0, 20, 3],
	["bomb_flight", [&"gun_bomb"], 9.0, 10, 3],
	["bomb_blast", [&"gun_bomb"], 9.0, 24, 3],
	["bomb_blast_fire", [&"gun_bomb", &"ember_core"], 9.0, 24, 3],
]
const SIZE := Vector2i(1280, 720)
## The target ahead on the aim, and a few to the sides.
const DUMMIES: Array[Vector2] = [
	Vector2(5.0, 0.0),
	Vector2(3.5, 2.5),
	Vector2(6.0, -2.0),
]

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
	_dir = "res://build/shots/%s/lzbm/" % GameVersion.label()
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
	for at in DUMMIES:
		_world.add_dummy(at, 0.35, 1 << 20)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = spec[2]
	_view.rig.camera.size = spec[2]
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.5, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0:
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, InputFrame.SHOOT, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= int(spec[3]):
			_settle = 0
		return false
	_settle += 1
	if _settle < int(spec[4]):
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	print(
		"laser_bomb: ",
		path,
		" (tick ",
		_ticks,
		", beams ",
		_view.laser.shown,
		", bombs ",
		_view.bombs.bombs,
		", blasts ",
		_view.bombs.blasts,
		")"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
