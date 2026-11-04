extends SceneTree
## v0.10.5 W3-O8 (owner F11, F12, F14): renders the three looks this step fixes, in the real game view
## (WorldViewRoot on the Ruins stage, the iso camera) of a real World with the data's cards, Shoot held:
## Void with Split (its minis opened, tick 60), Void with Mine (the mine held), the Wave aimed up the screen (away from
## the camera) and down it, the Laser on a pack. Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 --position -10000,-10000 -s scripts/shots/w3o8_forms.gd \
##     -- --tag=after
## Writes build/shots/v0.10.5/w3o8/<tag>_<label>.jpg and prints each path.

## Sim aim angles (1/4096 turn) for the iso camera (yaw 45 deg): up the screen (away), down it (toward the camera).
const AWAY := 1536
const TOWARD := 3584
## [label, cards, camera size, aim, ticks of Shoot before the grab, aim distance (cm), dummies].
const PLAN := [
	["void_split", [&"gun_void", &"split_shot"], 9.0, 0, 60, 500, "line"],
	["void_mine", [&"gun_void", &"gun_mine"], 9.0, 0, 100, 450, "line"],
	["wave_away", [&"gun_wave"], 9.0, AWAY, 22, 500, "away"],
	["wave_toward", [&"gun_wave"], 9.0, TOWARD, 22, 500, "toward"],
	["laser_pack", [&"gun_laser"], 9.0, 0, 30, 500, "pack"],
]
const SIZE := Vector2i(1280, 720)

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
var _tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.substr(6)
	_dir = "res://build/shots/v0.10.5/w3o8/"
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


func _dummies(kind: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var d := Vector2.RIGHT
	if kind == "away":
		d = Vector2.from_angle(TAU * AWAY / 4096.0)
	elif kind == "toward":
		d = Vector2.from_angle(TAU * TOWARD / 4096.0)
	if kind == "pack":
		for p in [Vector2(5.0, 0.0), Vector2(5.6, 0.6), Vector2(5.6, -0.6), Vector2(6.3, 0.0)]:
			out.append(p)
		return out
	var side := Vector2(-d.y, d.x)
	for p in [Vector2(5.5, 0.0), Vector2(3.0, 1.7), Vector2(4.2, -1.9), Vector2(7.2, -1.3)]:
		out.append(d * p.x + side * p.y)
	return out


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
	for at in _dummies(spec[6]):
		_world.add_dummy(at, 0.35, 1 << 20)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the effects layer and the pack, as in a run
	_view.stage.prop_style = biome.id
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = spec[2]
	_view.rig.camera.size = spec[2]
	var aim := Vector2.from_angle(TAU * int(spec[3]) / 4096.0)
	_view.rig.snap_to(SimPlane.to_3d(aim * 2.0))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0:
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(
			InputFrame.make(Vector2i.ZERO, int(spec[3]), int(spec[5]), InputFrame.SHOOT, pressed)
		)
		_view.sync()
		_ticks += 1
		if _ticks >= int(spec[4]):
			_settle = 0
		return false
	_settle += 1
	if _settle < 3:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%s_%s.jpg" % [_tag, spec[0]]
	img.save_jpg(path, 0.88)
	print(
		"w3o8_forms: ",
		path,
		" (tick ",
		_ticks,
		", voids ",
		_view.voids.voids,
		", waves ",
		_view.waves.waves,
		", beams ",
		_reader.beams().size(),
		")"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
