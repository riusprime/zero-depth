extends SceneTree
## v0.8.0 TX1: renders the bosses' shots for the owner's texture swap (docs/roadmap/v0.8.0/evidence/TEXTURES_1.md):
## each boss's orbs and trails in flight (the owner's orb cores and trails, or the code look when the textures are
## missing) and the Hive Lens's Focus Beam, in the real game view (WorldViewRoot on the Ruins stage, the iso camera)
## of a real World, closer than boss_fights.gd so the cores read. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tx1_attacks.gd [-- <n>]
## `-- <n>` renders shot n alone. Writes build/shots/v0.8.0/tx1/<n>_<label>.jpg and prints each path.

## [boss, attack, ticks into the attack, label].
const PLAN := [
	[&"gatekeeper", &"rock_rings", 110, "gatekeeper_ember_stones"],
	[&"brood_mother", &"web_spiral", 150, "brood_acid_globs"],
	[&"hive_lens", &"prism_spiral", 164, "hive_prism_orbs"],
	[&"warlord", &"shield_wall", 150, "warlord_spear_embers"],
	[&"siege_engine", &"turret_cross", 150, "siege_cannon_embers"],
	[&"foundry", &"furnace_waves", 160, "foundry_molten_drops"],
	[&"hive_lens", &"focus_beam_3", 74, "hive_focus_beam"],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(5.0, -3.0)
const BOSS_AT := Vector2(-1.0, 1.0)
const VIEW := 13.0

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _only := -1
var _step := 0
var _dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/tx1/"
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
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == spec[0]:
			bk = j
	_world.actors.set_pos(0, PLAYER_AT)
	var id := _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(id)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(spec[1]))
	_world.bosses.chained[BossAi.entry_of(_world, i)] = 1
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = VIEW
	_view.rig.camera.size = VIEW
	_view.rig.snap_to(SimPlane.to_3d((PLAYER_AT + BOSS_AT) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var want: int = spec[2]
	if _step < want:
		_world.actors.set_pos(0, PLAYER_AT)
		var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		_step += 1
		return false
	_step += 1
	if _step < want + 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[3]]
	img.save_jpg(path, 0.85)
	print("tx1_attacks: ", path)
	_k += 1
	if _only >= 0 or _k >= PLAN.size():
		return true
	_build(_k)
	return false
