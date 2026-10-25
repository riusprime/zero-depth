extends SceneTree
## v0.9.0 NB3: renders the Clockwork Judge's echo replaying for the owner, in the real game view (WorldViewRoot on the
## Ruins stage, the iso camera) of a real World: the owner's model, shielded, its clock racing; the hero walked an S
## through the room for the 3 s it recorded, then stepped aside; the echo is part way through its replay: the first
## ghosts have struck (golden afterimages rising, rings, filings), the rest of the path still showing as clock-gear
## markers joined by the gold ribbon. Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_clockwork_judge.gd
## Writes build/shots/v0.9.0/nb3/1_clockwork_judge_echo_replay.jpg and prints its path and the echo's state.

const SIZE := Vector2i(1280, 720)
const JUDGE_AT := Vector2(0.0, 3.2)
const ASIDE := Vector2(5.0, -3.5)
const WALK_TICKS := 200
## The echo's windup (48 ticks) and this far into its replay (the fifth ghost just struck).
const SHOT_TICKS := 48 + 62

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0
var _ticks := 0
var _boss := -1
var _dir := "res://build/shots/v0.9.0/nb3/"


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
		if _world.boss_tables[j].id == &"clockwork_judge":
			bk = j
	var t := _world.boss_tables[bk]
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.speed = 0.0
	_world.actors.set_pos(0, _walk(0))
	_boss = _world.spawn_boss(bk, JUDGE_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	for k in WALK_TICKS:  # the hero walks an S through the room while it records
		_world.actors.set_pos(0, _walk(k))
		_world.step(InputFrame.new())
	_world.actors.set_pos(0, ASIDE)
	BossAi.start_attack(_world, _world.actors.index_of(_boss), t.attack_index(&"the_echo"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 11.0
	_view.rig.camera.size = 11.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


## The S the hero walks (3 m/s along x, swinging in y).
static func _walk(k: int) -> Vector2:
	return Vector2(-5.0 + 0.05 * k, -0.5 + 2.2 * sin(float(k) / 32.0))


func _process(_delta: float) -> bool:
	if _ticks < SHOT_TICKS:
		var n := 6 if SHOT_TICKS - _ticks > 12 else 1
		for k in n:
			_world.actors.set_pos(0, ASIDE)  # the hero waits off the path
			_world.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(Vector2(-1, 1)), 300, 0, 0))
			_view.sync()
			_ticks += 1
		return false
	_frames += 1
	if _frames < 10:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "1_clockwork_judge_echo_replay.jpg"
	img.save_jpg(path, 0.88)
	var r := _view.reader
	var e := r.boss_echo(r.boss_index())
	var struck := 0
	for p: Dictionary in e.get("path", []):
		struck += 1 if bool(p["struck"]) else 0
	print("nb_clockwork_judge: ", path)
	print(
		"nb_clockwork_judge: tick ",
		_world.tick,
		" phase ",
		e.get("phase"),
		" echo t ",
		e.get("t"),
		" path ",
		e.get("path", []).size(),
		" struck ",
		struck,
		" markers ",
		_view.judges.markers_shown(),
		" ribbon ",
		_view.judges.ribbon_segments(),
		" ghosts ",
		_view.judges.ghosts_shown(),
		" shielded ",
		r.boss_shielded(r.boss_index()),
		" hero hp lost ",
		(1 << 20) - _world.actors.hp[0]
	)
	return true
