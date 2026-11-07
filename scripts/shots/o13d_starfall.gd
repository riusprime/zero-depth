extends SceneTree
## v0.11.0 O13d: the two Starfall signatures for the owner (ENEMIES.md R9, R10), each in the real game view
## (WorldViewRoot with Starfall's mood, look and enemy cast; ActorViews, StarfallViews, FireballViews) of a real World,
## at its tell.
## Run on a renderer, off screen:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/o13d_starfall.gd
## Writes build/shots/<version>/o13d/<id>.png (one per enemy) and prints each path. Cells:
## - star_warper: two thirds into its windup: the star beside the hero, its ring and the strike's filling disc;
## - gravity_node: a Needle's burst bending round the Node, its swirl.

const CELL := Vector2i(800, 560)
const HERO_AT := Vector2(0.0, -6.0)
## [id, kind, at, extra kind (-1 none), extra at, wait].
const PLAN := [
	["star_warper", ActorStore.Kind.STAR_WARPER, Vector2(0.0, -1.5), -1, Vector2.ZERO, &"star"],
	[
		"gravity_node",
		ActorStore.Kind.GRAVITY_NODE,
		Vector2(1.6, -1.0),
		ActorStore.Kind.NEEDLE,
		Vector2(0.0, 4.5),
		&"shots"
	],
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
var _seen := -1


func _initialize() -> void:
	_dir = "res://build/shots/%s/o13d/" % GameVersion.label()
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
	_id = _world.add_enemy(spec[1], spec[2])
	if int(spec[3]) >= 0:
		_world.add_enemy(spec[3], spec[4])
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"starfall")
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null  # (the off-screen rig never marks the bodies seen: animate them by distance)
	_view.rig.view_size = 11.0
	_view.rig.camera.size = 11.0
	_view.rig.snap_to(SimPlane.to_3d((HERO_AT + (spec[2] as Vector2)) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_settle = -1.0
	_t = 0
	_seen = -1


func _ready_now(wait: StringName) -> bool:
	var i := _world.actors.index_of(_id)
	var a := _world.actors
	match wait:
		&"star":
			return (
				i >= 0
				and a.state[i] == EnemyAi.State.WINDUP
				and a.state_t[i] * 3 >= a.windup[i] * 2
			)
		&"shots":
			for j in _world.projectiles.size():
				if _world.projectiles.team[j] == ActorStore.TEAM_ENEMY:
					_seen = _t if _seen < 0 else _seen
			return _seen >= 0 and _t - _seen >= 40
	return false


func _process(delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0.0:
		if _ready_now(spec[5]):
			_settle = 0.05
			return false
		_acc += delta  # one sim tick per 1/60 s of real time, so the frame-time animation keeps up
		if _acc < 1.0 / 60.0:
			return false
		_acc -= 1.0 / 60.0
		_world.actors.set_pos(0, HERO_AT)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
		_t += 1
		_view.sync()
		if _t > 1200:
			print("o13d: %s never got ready" % spec[0])
			_settle = 0.01
		return false
	_settle -= delta
	if _settle > 0.0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path: String = _dir + "%s.png" % spec[0]
	img.save_png(path)
	print("o13d: ", ProjectSettings.globalize_path(path))
	_k += 1
	if _k == PLAN.size():
		return true
	_build(_k)
	return false
