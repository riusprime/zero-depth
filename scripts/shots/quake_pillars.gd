extends SceneTree
## v0.11.0 O3 (owner L5, Q9 a): one shot of the Gatekeeper's phase 2 with its three quake pillars standing, their rings
## growing toward a pulse, in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World, as
## scripts/shots/boss_signatures.gd does. Needs a renderer (off screen on the owner's PC):
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/quake_pillars.gd
## Writes build/shots/v0.11.0/o3/quake_pillars_phase2.jpg and prints its path. Frames are grabbed in _process.

const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(6.0, -1.0)
const BOSS_AT := Vector2(-1.0, 1.0)
## Ticks after phase 2 begins: the rings are most of the way through their warning (the pulse comes at 180).
const RUN_TICKS := 168

var _world: World
var _view: WorldViewRoot
var _vp: SubViewport
var _boss := -1
var _t := 0
var _settle := 0
var _dir := "res://build/shots/v0.11.0/o3/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(repo)
	)
	_world.set_boss_tables(ContentCompiler.compile_bosses(repo))
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == &"gatekeeper":
			bk = j
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[i] = _world.actors.max_hp[i] * 650 / 1000  # just under phase 2's threshold
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d(BOSS_AT))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _process(_delta: float) -> bool:
	if _t < RUN_TICKS:
		_world.actors.set_pos(0, PLAYER_AT)
		var aim := Kin.angle_of(_world.actors.pos(_world.actors.index_of(_boss)) - PLAYER_AT)
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		_t += 1
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "quake_pillars_phase2.jpg"
	img.save_jpg(path, 0.85)
	print("quake_pillars: ", path, " pillars=", WorldReader.new(_world).boss_quake_pillars().size())
	return true
