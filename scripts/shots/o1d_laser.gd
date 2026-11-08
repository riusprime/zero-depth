extends SceneTree
## v0.11.0 O1d (owner, 2026-11-08): the Laser with Homing and Twin from the game camera (WorldViewRoot with its mood,
## the
## pack on): one enemy (the lens), and a pack of 8 (the rays spread over it). Needs a renderer (no --headless):
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/o1d_laser.gd
## Writes build/shots/o1d/<n>_<label>.png and prints what it drew.

## [label, dummies (hero's frame: x ahead, y left), Twin's level, element card or &""].
const PLAN := [
	["lens_one_enemy", [Vector2(6.0, 0.0)], 1, &""],
	[
		"pack_of_8",
		[
			Vector2(3.0, 2.0),
			Vector2(4.2, -1.3),
			Vector2(5.5, 1.2),
			Vector2(6.0, -2.4),
			Vector2(7.2, 2.7),
			Vector2(7.5, 0.0),
			Vector2(8.0, -3.2),
			Vector2(5.0, 3.6),
		],
		1,
		&"ember_core"
	],
]
const SIZE := Vector2i(1280, 720)
## Grabbed this many ticks after the shot: the lance fully drawn, still bright.
const AFTER := 11

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _world: World
var _view: WorldViewRoot
var _k := 0
var _idle := 0
var _ticks := 0
var _aim := 0
var _fired := -1
var _dir := "res://build/shots/o1d/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	_build(0)


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	return -1


func _build(n: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[n]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	for id: StringName in [&"gun_laser", &"gun_homing", &"gun_twin"]:
		_world.add_item(_item(id))
	if spec[3] != &"":
		_world.add_item(_item(spec[3]))
	CardLevels.set_level(_world, _item(&"gun_twin"), int(spec[2]))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	var fwd := _clear_way(_world, spec[1])
	var left := fwd.orthogonal()
	var mid := Vector2.ZERO
	for a: Vector2 in spec[1]:
		var at: Vector2 = _world.player_pos() + fwd * a.x + left * a.y
		_world.add_dummy(at, 0.35, 1 << 20)
		mid += at
	mid /= float(spec[1].size())
	_aim = Kin.angle_of(mid - _world.player_pos())
	_view = WorldViewRoot.new()
	root.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 10.0
	_view.rig.camera.size = 10.0
	_view.rig.snap_to(SimPlane.to_3d(mid * 0.55))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.sync()
	_idle = 30
	_ticks = 0
	_fired = -1


## The way ahead (a unit vector) with no wall near the spots.
func _clear_way(w: World, spots: Array) -> Vector2:
	for k in 24:
		var fwd := Vector2.from_angle(TAU * k / 24.0)
		var left := fwd.orthogonal()
		var ok := true
		for a: Vector2 in spots:
			var at: Vector2 = w.player_pos() + fwd * a.x + left * a.y
			var mid: Vector2 = w.player_pos() + fwd * a.x * 0.5
			var side: Vector2 = left * maxf(2.0, a.x * 0.4)
			for i in w.walls.size():
				for p: Vector2 in [at, mid + side, mid - side]:
					if Collide.circle_vs_obb(p, 1.4, w.walls[i]) != Vector2.ZERO:
						ok = false
		if ok:
			return fwd
	return Vector2.RIGHT


func _process(_delta: float) -> bool:
	if _idle > 0:
		_idle -= 1
		return false
	var pressed := InputFrame.SHOOT if _ticks == 0 else 0
	_world.step(InputFrame.make(Vector2i.ZERO, _aim, 500, InputFrame.SHOOT, pressed))
	_view.sync()
	_ticks += 1
	if _fired < 0 and _world.mx.lz_shot_tick >= 0:
		_fired = _ticks
	if _fired < 0 or _ticks < _fired + AFTER:
		return false
	var spec: Array = PLAN[_k]
	var img := get_root().get_texture().get_image()
	var path := _dir + "%d_%s.png" % [_k + 1, spec[0]]
	img.save_png(path)
	print(
		"o1d_laser: ",
		path,
		" beams ",
		_view.laser.shown,
		" tubes ",
		_view.laser.tubes_shown,
		" points ",
		_view.laser.points_shown
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
