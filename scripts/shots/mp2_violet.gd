extends SceneTree
## v0.9.0 MP2 (owner, 2026-10-24: "the black one should also modify the attack color to a purle violet kind of
## attack"): the Gun's plain pulses in flight in the real game view (WorldViewRoot on the Ruins stage, the iso camera)
## of a real World with the data's Gun build, Shoot held at a dummy: the hero in The Fallen's robe (violet), then in
## Cream (today's blue) to compare, then The Fallen's robe with Cinder Shot (an element keeps its own colour). A tool,
## not a test (gun_feel.gd's set-up). Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mp2_violet.gd
## Writes build/shots/v0.9.0/mp2/en_4_attack_<label>.png and prints each path.

## [label, robe, cards].
const PLAN := [
	["fallen_violet", &"fallen", []],
	["cream_blue", &"cream", []],
	["fallen_cinder", &"fallen", [&"cinder_shot"]],
]
const SIZE := Vector2i(1600, 900)
const DUMMY_AT := Vector2(6.0, 0.0)
const OUT := "res://build/shots/v0.9.0/mp2/"
const TICKS := 40

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _ticks := 0
var _settle := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	for id: StringName in spec[2]:
		_world.add_item(_item(id))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.add_dummy(DUMMY_AT, 0.35, 1 << 20)
	_view = WorldViewRoot.new()
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_vp.add_child(_view)
	_view.actors.hero_look = Wardrobe.look(_repo, _repo.get_def(&"robe", spec[1]), &"none")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 7.0
	_view.rig.camera.size = 7.0
	_view.rig.snap_to(SimPlane.to_3d(DUMMY_AT * 0.4))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	if _settle < 0:
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 600, InputFrame.SHOOT, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= TICKS:
			_settle = 0
		return false
	_settle += 1
	if _settle < 4:
		return false
	var img := _vp.get_texture().get_image()
	var path := OUT + "en_4_attack_%s.png" % PLAN[_k][0]
	img.save_png(path)
	print("mp2_violet: ", path, " (", _view.pulses.count(), " pulses)")
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
