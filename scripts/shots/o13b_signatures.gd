extends SceneTree
## v0.11.0 O13b: the Ruins' and the Night Rocks' signature enemies for the owner (ENEMIES.md R1-R4), each in the real
## game view (WorldViewRoot with its biome's mood, look and enemy cast; ActorViews, RuinsRocksViews) of a real World,
## at the moment its tell shows. Run on a renderer, off screen:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/o13b_signatures.gd
## Writes build/shots/<version>/o13b/<id>.png (one per enemy) and prints each path. Cells:
## - wire_weaver: marking a cable (its line on the ground, the posts' spots sparking, its arms up);
## - scrap_hound: turning in behind the attacking hero (its eyes flashing, its dart's line);
## - rock_lurker: waiting as a boulder with the hero near (its cracks glowing, the rumble's dust);
## - stone_thrower: lifting its rock overhead (the ring on the ground where the hero stands).

const CELL := Vector2i(800, 560)
const HERO_AT := Vector2(0.0, -4.0)
## [id, biome, kind, enemy at, the windup share to wait for (-1: ticks instead)].
const PLAN := [
	["wire_weaver", &"ruins", ActorStore.Kind.WIRE_WEAVER, Vector2(0.0, 2.0), 0.7],
	["scrap_hound", &"ruins", ActorStore.Kind.SCRAP_HOUND, Vector2(0.0, 1.0), 0.85],
	["rock_lurker", &"night_rocks", ActorStore.Kind.ROCK_LURKER, Vector2(0.0, -0.6), -1.0],
	["stone_thrower", &"night_rocks", ActorStore.Kind.STONE_THROWER, Vector2(0.0, 3.0), 0.8],
]

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _settle := -1.0
var _acc := 0.0
var _k := 0
var _t := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/o13b/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		41 + k, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	_id = _world.add_enemy(spec[2], spec[3])
	var biome: BiomeDefinition = _repo.get_def(&"biomes", spec[1])
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null  # (the off-screen rig never marks the bodies seen: animate them by distance)
	_view.rig.view_size = 9.0
	_view.rig.camera.size = 9.0
	_view.rig.snap_to(SimPlane.to_3d((HERO_AT + (spec[3] as Vector2)) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_settle = -1.0
	_t = 0


func _ready_now(share: float) -> bool:
	var i := _world.actors.index_of(_id)
	if i < 0:
		return false
	if share < 0.0:
		return _t >= 150
	var a := _world.actors
	return a.state[i] == EnemyAi.State.WINDUP and a.state_t[i] >= int(a.windup[i] * share)


## The hero's input: still; for the Hound, attacking with its back to it (so it turns in).
func _frame() -> InputFrame:
	var f := InputFrame.new()
	var spec: Array = PLAN[_k]
	var i := _world.actors.index_of(_id)
	if spec[2] == ActorStore.Kind.SCRAP_HOUND and i >= 0:
		f.held = InputFrame.PRIMARY
		f.aim_angle = (Kin.angle_of(_world.actors.pos(i) - HERO_AT) + 2048) & 4095
	elif i >= 0:
		f.aim_angle = Kin.angle_of(_world.actors.pos(i) - HERO_AT)
	return f


func _process(delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0.0:
		if _ready_now(spec[4]):
			_settle = 0.05 if spec[4] >= 0.0 else 0.6  # (real seconds: the bodies' frame-time poses)
			return false
		_acc += delta  # one sim tick per 1/60 s of real time, so the frame-time animation keeps up
		if _acc < 1.0 / 60.0:
			return false
		_acc -= 1.0 / 60.0
		_world.actors.set_pos(0, HERO_AT)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(_frame())
		_t += 1
		_view.sync()
		if _t > 1500:
			print("o13b: %s never got ready" % spec[0])
			_settle = 0.01
		return false
	_settle -= delta
	if _settle > 0.0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path: String = _dir + "%s.png" % spec[0]
	img.save_png(path)
	print("o13b: ", ProjectSettings.globalize_path(path))
	_k += 1
	if _k == PLAN.size():
		return true
	_build(_k)
	return false
