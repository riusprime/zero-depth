extends SceneTree
## v0.9.0 NB2: renders the Twin Wardens mid-fight for the owner, in the real game view (WorldViewRoot on the Ruins
## stage, the iso camera) of a real World: both owner models with the burning chain between them, Crossfire firing
## (both shielded, their amber and violet embers in the air, the two gap lanes crossing at the safe spot, where the hero
## stands). Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_twin_wardens.gd
## Writes build/shots/v0.9.0/nb2/1_twin_wardens_crossfire_chain.jpg and prints its path and the fight's state.

const SIZE := Vector2i(1280, 720)
const AMBER_AT := Vector2(-2.8, 1.2)
const VIOLET_AT := Vector2(2.0, 1.2)
const PLAYER_AT := Vector2(0.5, -3.5)
## Crossfire's windup (72 ticks) and this far into its firing.
const SHOT_TICKS := 72 + 50

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0
var _ticks := 0
var _boss := -1
var _dir := "res://build/shots/v0.9.0/nb2/"


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
		if _world.boss_tables[j].id == &"twin_wardens":
			bk = j
	var t := _world.boss_tables[bk]
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.speed = 0.0
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, AMBER_AT)
	var i := _world.actors.index_of(_boss)
	var j := BossTwin.partner_of(_world, i)
	_world.actors.set_pos(j, VIOLET_AT)
	for k in [i, j]:
		_world.actors.state[k] = EnemyAi.State.MOVE
		_world.actors.invuln[k] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.step(InputFrame.new())
	BossAi.start_attack(_world, _world.actors.index_of(_boss), t.attack_index(&"crossfire"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 10.0
	_view.rig.camera.size = 10.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(-0.4, 0.2)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _process(_delta: float) -> bool:
	if _ticks < SHOT_TICKS:
		var n := 6 if SHOT_TICKS - _ticks > 12 else 1
		for k in n:
			var i := _world.actors.index_of(_boss)
			var safe := _world.bosses.pt(BossAi.entry_of(_world, i), 0)
			_world.actors.set_pos(0, safe)  # the hero waits on the safe spot
			_world.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(Vector2(0, 1)), 300, 0, 0))
			_view.sync()
			_ticks += 1
		return false
	_frames += 1
	if _frames < 12:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "1_twin_wardens_crossfire_chain.jpg"
	img.save_jpg(path, 0.88)
	var r := _view.reader
	var bi := r.boss_index()
	var tw := r.boss_twin(bi)
	print("nb_twin_wardens: ", path)
	print(
		"nb_twin_wardens: tick ",
		_world.tick,
		" hero ",
		_world.player_pos(),
		" hero hp lost ",
		(1 << 20) - _world.actors.hp[0],
		" chain ",
		tw.get("chain"),
		" hot ",
		tw.get("hot"),
		" safe ",
		tw.get("safe"),
		" links ",
		_view.twins.links_drawn(),
		" shots ",
		_world.projectiles.size()
	)
	return true
