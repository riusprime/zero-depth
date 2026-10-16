extends SceneTree
## v0.8.0 AO (owner O37: "make the order of the attacks be more important"; docs/roadmap/v0.8.0/evidence/
## ATTACK_ORDER.md): renders what each order of Ring, Spread and Swirl does to the Gun's shot, in the real game view
## (WorldViewRoot on the Ruins stage, the iso camera) of a real World with the data's Gun, Shoot held toward a loose
## crowd of dummies: Ring alone, Ring · Spread, Spread · Ring, Ring · Spread · Swirl, Swirl · Ring · Spread (and the
## plain shot to compare). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_order.gd
## Writes build/shots/<version>/ao/<n>_<label>.jpg and prints each path with the rings alive. Frames are grabbed in
## _process.

## [label, cards (wand order), camera size, ticks of Shoot before the grab, frames to settle].
const PLAN := [
	["plain_shot", [], 12.0, 24, 2],
	["ring", [&"gun_ring"], 12.0, 24, 2],
	["ring_spread", [&"gun_ring", &"gun_spread"], 12.0, 24, 2],
	["spread_ring", [&"gun_spread", &"gun_ring"], 12.0, 24, 2],
	["ring_spread_swirl", [&"gun_ring", &"gun_spread", &"gun_swirl"], 14.0, 40, 2],
	["swirl_ring_spread", [&"gun_swirl", &"gun_ring", &"gun_spread"], 14.0, 31, 2],
]
const SIZE := Vector2i(1280, 720)
## A loose crowd ahead of and round the hero.
const DUMMIES: Array[Vector2] = [
	Vector2(3.0, 0.0),
	Vector2(4.5, 1.5),
	Vector2(4.0, -2.0),
	Vector2(6.0, 0.5),
	Vector2(1.5, 3.5),
	Vector2(-2.5, 2.5),
	Vector2(-3.0, -2.0),
	Vector2(1.0, -4.0),
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
	_dir = "res://build/shots/%s/ao/" % GameVersion.label()
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
	_view.rig.snap_to(SimPlane.to_3d(Vector2(1.5, 0.0)))
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
		"attack_order: ",
		path,
		" (tick ",
		_ticks,
		", ",
		_world.ab.ring_pos.size(),
		" rings alive, ",
		_view.attack_forms.ring_arcs_drawn,
		" arcs laid)"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
