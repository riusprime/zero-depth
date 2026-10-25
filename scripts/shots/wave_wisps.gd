extends SceneTree
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F9, F10; docs/roadmap/v0.9.0/evidence/WAVE_WISPS.md): renders the Wave and the
## Wisps in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World with the data's Gun
## and cards, among standing dummies: a Frost Wave rolling through the dummies; the Fire Wisps circling the hero a
## little after their first shots (SHOOT never held). Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/wave_wisps.gd
## Writes build/shots/<version>/af3/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [label, cards (wand order), camera size, ticks of Shoot held, ticks let go after, frames to settle].
const PLAN := [
	["wave_band", [&"gun_wave", &"frost_core"], 9.0, 1, 34, 2],
	["wisps_ring", [&"gun_wisps", &"ember_core"], 7.0, 0, 44, 2],
]
const SIZE := Vector2i(1280, 720)
## A row on the aim's line and two beside it.
const DUMMIES: Array[Vector2] = [
	Vector2(2.5, 0.2),
	Vector2(4.5, -0.2),
	Vector2(6.5, 0.1),
	Vector2(3.5, 1.8),
	Vector2(5.5, -1.9),
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
	_dir = "res://build/shots/%s/af3/" % GameVersion.label()
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
	_view.rig.snap_to(SimPlane.to_3d(Vector2(3.5, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var held_n := int(spec[3])
	if _settle < 0:
		var held := InputFrame.SHOOT if _ticks < held_n else 0
		var pressed := InputFrame.SHOOT if _ticks == 0 and held_n > 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, held, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= held_n + int(spec[4]):
			_settle = 0
		return false
	_settle += 1
	if _settle < int(spec[5]):
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	print(
		"wave_wisps: ",
		path,
		" (tick ",
		_ticks,
		", waves ",
		_view.waves.waves,
		" widths ",
		_view.waves.widths,
		", wisps ",
		_view.wisps.wisps,
		")"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
