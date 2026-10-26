extends SceneTree
## v0.9.5 FC1 (owner: "homing + laser ... with pierce it would make a smooth curve trying to hit the closest 5"):
## renders the Laser with Homing and Pierce threading five dummies laid on a curve, and with Halo, Ring, Echo and Mine,
## in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World with the data's Gun and
## cards, Shoot held. Adapted from scripts/shots/laser_bomb.gd. Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/laser_fc1.gd
## Writes build/shots/<version>/fc1/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [label, cards (wand order), camera size, ticks of Shoot before the grab, frames to settle].
const PLAN := [
	["homing_pierce", [&"gun_laser", &"gun_homing", &"gun_pierce"], 12.0, 90, 3],
	["halo_ring", [&"gun_laser", &"halo_shot", &"gun_ring"], 12.0, 40, 3],
	["echo_mine", [&"gun_laser", &"gun_echo", &"gun_mine"], 12.0, 100, 3],
]
const SIZE := Vector2i(1280, 720)
## The target ahead on the aim, and a few to the sides.
const DUMMIES: Array[Vector2] = [
	Vector2(2.0, 0.3), Vector2(3.5, 1.2), Vector2(4.5, 2.6), Vector2(5.0, 4.2), Vector2(4.8, 5.8)
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
	_dir = "res://build/shots/%s/fc1/" % GameVersion.label()
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
	var arc := _clear_arc(_world)
	for at in arc:
		_world.add_dummy(at, 0.35, 1 << 20)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = spec[2]
	_view.rig.camera.size = spec[2]
	_view.rig.snap_to(SimPlane.to_3d(arc[2] * 0.5))
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
		"laser_fc1: ",
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


## DUMMIES laid out from the hero, turned (and mirrored) until the path hero -> 1 -> ... -> 5 crosses no wall.
func _clear_arc(w: World) -> Array[Vector2]:
	var p := w.player_pos()
	for mirror: float in [1.0, -1.0]:
		for k in 48:
			var fwd := Vector2.from_angle(TAU * k / 48.0)
			var left := fwd.orthogonal() * mirror
			var out: Array[Vector2] = []
			var ok := true
			var prev := p
			for a in DUMMIES:
				var at: Vector2 = p + fwd * a.x + left * a.y
				for i in w.walls_along(prev, at, 0.7):
					if Collide.sweep_vs_obb(prev, at, 0.7, w.walls[i]) >= 0.0:
						ok = false
				for i in w.walls.size():
					if Collide.circle_vs_obb(at, 0.8, w.walls[i]) != Vector2.ZERO:
						ok = false
				prev = at
				out.append(at)
			if ok:
				return out
	return DUMMIES.duplicate()
