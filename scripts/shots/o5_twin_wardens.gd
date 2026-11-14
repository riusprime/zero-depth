extends SceneTree
## v0.11.0 O5 (owner L7, Q11 a, Q29): renders the Twin Wardens in their phase 3 for the owner, in the real game view
## (WorldViewRoot on the Ruins stage, the iso camera) of a real World, with the boss bar over it: both owner models on
## their chain, the amber Warden exposed (its light up, the hint's target) while the violet fires its Orb Volley; the
## bar on its third full bar ("Phase 3 / 3 · Both Wardens fight", "AMBER EXPOSED"). Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 --position -10000,-10000
##     -s scripts/shots/o5_twin_wardens.gd
## Writes build/shots/v0.11.0/o5/1_twin_wardens_phase3.jpg and prints its path and the fight's state.

const SIZE := Vector2i(1280, 720)
const AMBER_AT := Vector2(-2.8, 1.2)
const VIOLET_AT := Vector2(2.4, 1.6)
const PLAYER_AT := Vector2(0.0, -3.2)
## The Orb Volley's windup (48 ticks) and this far into its firing.
const SHOT_TICKS := 48 + 16

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _bar: BossBar
var _frames := 0
var _ticks := 0
var _boss := -1
var _dir := "res://build/shots/v0.11.0/o5/"


func _initialize() -> void:
	TranslationServer.set_locale("en")
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
	t.twin_bolt = -1
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, AMBER_AT)
	var i := _world.actors.index_of(_boss)
	for k in [i, BossTwin.partner_of(_world, i)]:
		_world.actors.state[k] = EnemyAi.State.MOVE
		_world.actors.invuln[k] = 0
	for p in [1, 2]:  # down to phase 3 through both gates, as the fight does
		i = _world.actors.index_of(_boss)
		var hp := t.phase_threshold[p] * _world.actors.max_hp[i] / 1000
		_world.actors.hp[i] = hp
		_world.actors.hp[BossTwin.partner_of(_world, i)] = hp
		for k in BossGates.GATE_TICKS + 3:
			_world.step(InputFrame.new())
	i = _world.actors.index_of(_boss)
	var j := BossTwin.partner_of(_world, i)
	_world.actors.set_pos(i, AMBER_AT)
	_world.actors.set_pos(j, VIOLET_AT)
	_world.actors.set_pos(0, PLAYER_AT)
	_world.step(InputFrame.new())
	BossAi.start_attack(_world, j, t.attack_index(&"orb_volley"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 10.0
	_view.rig.camera.size = 10.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(-0.2, 1.4)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var hud := CanvasLayer.new()
	_vp.add_child(hud)
	_bar = BossBar.new()
	hud.add_child(_bar)


func _process(_delta: float) -> bool:
	if _ticks < SHOT_TICKS:
		var n := 6 if SHOT_TICKS - _ticks > 12 else 1
		for k in n:
			_world.actors.set_pos(0, PLAYER_AT)
			_world.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(Vector2(0, 1)), 300, 0, 0))
			_view.sync()
			_bar.sync(_view.reader)
			_ticks += 1
		return false
	_frames += 1
	if _frames < 12:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "1_twin_wardens_phase3.jpg"
	img.save_jpg(path, 0.88)
	var r := _view.reader
	var bi := r.boss_index()
	var tw := r.boss_twin(bi)
	print("o5_twin_wardens: ", path)
	print(
		"o5_twin_wardens: tick ",
		_world.tick,
		" phase ",
		tw.get("phase"),
		" amber exposed ",
		tw.get("exposed"),
		" bar ",
		r.boss_phase_permille(bi),
		" shots ",
		_world.projectiles.size(),
		" hint ",
		r.objectives()
	)
	return true
