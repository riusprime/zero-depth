extends SceneTree
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): renders each new signature mechanic for the owner, in the real
## game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World: the Hive Lens's Gaze winding up (its
## eye brightening, the thin aim line) and sweeping (the beam, its impact light and scorch), the Siege Engine's Turret
## Cross embers coming back off the walls (the ricochet sparks), the Foundry's lava left by its Molten Flood, its
## meltdown's ring glowing through the roar, and the room's outer ring melted with fresh lava inside. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_signatures_2.gd
## Writes build/shots/v0.8.0/bs2/<n>_<label>.jpg (numbered after BS1's 1-6) and prints each path.

## [boss, [[attack, ticks after it starts] ...] run in turn, label, where the player stands]. The Gaze winds up aimed
## away from the player: from (-5, 6.5) its aim line runs toward the camera, in front of the eye.
const PLAN := [
	[&"hive_lens", [[&"gaze", 36]], "hive_gaze_windup_aim_line", Vector2(-5.0, 6.5)],
	[&"hive_lens", [[&"gaze", 48 + 215]], "hive_gaze_beam_sweeping", Vector2(4.0, -2.0)],
	[
		&"siege_engine",
		[[&"turret_cross", 275]],
		"siege_ricochet_embers_coming_back",
		Vector2(4.0, -2.0)
	],
	[
		&"foundry",
		[[&"molten_flood", 96 + 96 + 40]],
		"foundry_lava_left_by_the_flood",
		Vector2(-2.0, -6.5)
	],
	[&"foundry", [[&"meltdown", 100]], "foundry_meltdown_ring_glowing", Vector2(4.0, -2.0)],
	[
		&"foundry",
		[[&"meltdown", 200], [&"molten_flood", 96 + 96 + 30]],
		"foundry_outer_ring_melted",
		Vector2(1.0, -5.5)
	],
]
const FIRST := 7
const TICKS_PER_FRAME := 6
const SIZE := Vector2i(1280, 720)
const BOSS_AT := Vector2(-1.5, 1.0)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _step := 0
var _stage := 0
var _stage_t := 0
var _boss := -1
var _dir := ""
var _only := -1
var _player_at := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():  # `-- 12` renders shot 12 alone
		if a.is_valid_int():
			_only = int(a) - FIRST
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/bs2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(_k)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.set_boss_tables(ContentCompiler.compile_bosses(_repo))
	var half := StageScenario.ARENA_HALF - 0.9  # to the walls' inner faces
	_world.bosses.arena = Rect2(-half, -half, half * 2.0, half * 2.0)  # the room the melt rings
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == spec[0]:
			bk = j
	var t := _world.boss_tables[bk]
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()  # only the attacks shown
	t.punish_ticks = 0
	t.gap_ticks = 0
	_player_at = spec[3]
	_world.actors.set_pos(0, _player_at)
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_stage = 0
	_stage_t = 0
	_start(spec[1][0][0])
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 21.0
	_view.rig.camera.size = 21.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(1.0, -0.5)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0


func _start(attack_id: StringName) -> void:
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(attack_id))
	_world.bosses.chained[BossAi.entry_of(_world, i)] = 1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var stages: Array = spec[1]
	if _stage < stages.size():
		# Up to TICKS_PER_FRAME sim ticks a frame (the view synced after each), the last 12 one a frame: llvmpipe draws
		# a frame slowly, and the shot's own frame-time animation settles over the last ones.
		var n := TICKS_PER_FRAME if int(stages[_stage][1]) - _stage_t > 12 else 1
		for k in n:
			_world.actors.set_pos(0, _player_at)
			var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
			_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
			_view.sync()
			_stage_t += 1
			if _stage_t >= int(stages[_stage][1]):
				_stage += 1
				_stage_t = 0
				if _stage < stages.size():
					_start(stages[_stage][0])
				break
		return false
	_step += 1
	if _step < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + FIRST, spec[2]]
	img.save_jpg(path, 0.85)
	print("boss_signatures_2: ", path)
	_k += 1
	if _k >= PLAN.size() or _only >= 0:
		return true
	_build(_k)
	return false
