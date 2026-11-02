extends SceneTree
## v0.10.5 O7b (owner P6, "make the shards stay on the floor instead of flying around"): renders the shards a fight
## leaves lying on the floor, in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World:
## a ring of held enemies round the hero is killed one every KILL_EVERY ticks (a staged hit through Damage.hit, the
## sim's own kill path; staged so the shot doesn't hang on aim); their shards lie where each fell, out of pickup
## range. Needs a renderer (not --headless):
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000 \
##     -s scripts/shots/shard_pickups.gd
## Writes build/shots/<version>/o7b/shards_on_the_floor.jpg and prints its path. Frames are grabbed in _process.

const K := ActorStore.Kind
const RING := [
	[K.CHARGER, Vector2(4.2, 0.8)],
	[K.WARDEN, Vector2(3.2, -3.0)],
	[K.SWARMER, Vector2(-3.8, 2.0)],
	[K.CHARGER, Vector2(-1.0, 4.4)],
	[K.NEEDLE, Vector2(-4.0, -2.2)],
	[K.SWARMER, Vector2(1.6, 4.0)],
	[K.WARDEN, Vector2(0.4, -4.4)],
]
const SIZE := Vector2i(1280, 720)
const KILL_EVERY := 12
const AFTER := 30

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _ticks := 0
var _after := -1
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/o7b/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	var enemies := ContentCompiler.compile_enemies(_repo)
	for e in enemies:
		e.speed = 0.0
	_world = StageScenario.build(9, t, enemies)
	_world.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	for r: Array in RING:
		var i := _world.actors.index_of(_world.add_enemy(r[0], r[1]))
		_world.actors.state[i] = EnemyAi.State.MOVE
		_world.actors.cd[i] = 1 << 30
		_world.actors.invuln[i] = 0
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the game's lit look (and its effects layer), as main.gd sets it
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 9.0
	_view.rig.camera.size = 9.0
	_view.rig.snap_to(Vector3.ZERO)
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _kill_one() -> bool:
	var i := _nearest_enemy()
	if i < 0:
		return false
	var at := _world.actors.pos(i)
	_world.actors.invuln[i] = 0
	Damage.hit(_world, i, 999999, 0, 0, _world.take_root(), 0, at, at)
	return true


func _nearest_enemy() -> int:
	var best := -1
	var best_d := INF
	var a := _world.actors
	for i in range(1, a.size()):
		if a.dead[i] == 1 or not EnemyAi.is_enemy_kind(a.kinds[i]):
			continue
		var d := a.pos(i).distance_to(_world.player_pos())
		if d < best_d:
			best = i
			best_d = d
	return best


func _process(_delta: float) -> bool:
	if _after < AFTER:
		if _after < 0 and _ticks % KILL_EVERY == KILL_EVERY - 1 and not _kill_one():
			_after = 0
		_world.step(InputFrame.new())
		_view.sync()
		_ticks += 1
		if _after >= 0:
			_after += 1
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "shards_on_the_floor.jpg"
	img.save_jpg(path, 0.88)
	print(
		"shard_pickups: ",
		path,
		" (tick ",
		_ticks,
		", kills ",
		_world.kills,
		", drops ",
		_world.shard_drops.size(),
		" holding ",
		_world.shard_drops.total(),
		", shards taken ",
		_world.shards,
		", view clusters ",
		_view.shards.drop_count(),
		")"
	)
	return true
