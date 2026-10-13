extends SceneTree
## v0.7.5 BF1: renders the dodge-first boss fights for the owner (BOSS_FIGHTS.md): the Gatekeeper's and the Warlord's
## patterns in flight (v0.7.5 BF2: and the Brood Mother's and the Hive Lens's; BF3: the Siege Engine's and the
## Foundry's), the tracked circles and lanes (dull while tracking, flashing once locked) and the crystal shield,
## in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_fights.gd
## Writes build/shots/<version>/boss_fights/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [boss, attack, ticks into the attack, label, the player's walk per tick (m)].
const PLAN := [
	[&"gatekeeper", &"rock_rings", 110, "gatekeeper_rock_rings_shielded", Vector2.ZERO],
	[&"gatekeeper", &"cross_quake_fast", 140, "gatekeeper_cross_quake", Vector2.ZERO],
	[&"gatekeeper", &"fist_slam_3", 70, "gatekeeper_fist_slam_tracking", Vector2(0.0, 0.05)],
	[&"gatekeeper", &"fist_slam", 84, "gatekeeper_fist_slam_locked", Vector2.ZERO],
	[&"gatekeeper", &"shock_lanes", 80, "gatekeeper_shock_lanes_locked", Vector2.ZERO],
	# v0.7.5 BF2: the Brood Mother and the Hive Lens.
	[&"brood_mother", &"egg_storm", 125, "brood_egg_storm_shielded", Vector2(0.0, 0.05)],
	[&"brood_mother", &"egg_storm_5", 160, "brood_egg_storm_5", Vector2(0.04, 0.03)],
	[&"brood_mother", &"web_spiral", 150, "brood_web_spiral", Vector2.ZERO],
	[&"brood_mother", &"leap", 84, "brood_leap_locked", Vector2.ZERO],
	[&"brood_mother", &"burrow", 176, "brood_burrow_locked", Vector2.ZERO],
	[&"brood_mother", &"burrow", 214, "brood_burrow_eruption_ring", Vector2.ZERO],
	[&"hive_lens", &"prism_spiral", 164, "hive_prism_spiral_shielded", Vector2.ZERO],
	[&"hive_lens", &"petal_bloom", 112, "hive_petal_bloom", Vector2.ZERO],
	[&"hive_lens", &"glare_ring_fast", 122, "hive_glare_ring_fast", Vector2.ZERO],
	[&"hive_lens", &"focus_beam_3", 84, "hive_focus_beam_locked", Vector2.ZERO],
	[&"warlord", &"shield_wall", 150, "warlord_shield_wall_shielded", Vector2.ZERO],
	[&"warlord", &"shield_wall_cross", 160, "warlord_crossing_walls", Vector2.ZERO],
	[&"warlord", &"javelin_fan", 90, "warlord_javelin_fan", Vector2.ZERO],
	[&"warlord", &"spear_lines", 70, "warlord_spear_lines_locked", Vector2.ZERO],
	# v0.7.5 BF3: the Siege Engine and the Foundry.
	[&"siege_engine", &"turret_cross", 150, "siege_turret_cross_shielded", Vector2.ZERO],
	[&"siege_engine", &"mortar_grid", 30, "siege_mortar_grid_tracking", Vector2(0.03, 0.04)],
	[&"siege_engine", &"mortar_grid", 80, "siege_mortar_grid_locked", Vector2.ZERO],
	[&"siege_engine", &"mortar_grid", 140, "siege_mortar_grid_second_colour", Vector2.ZERO],
	[&"siege_engine", &"barrage", 75, "siege_barrage_in_turn", Vector2(0.0, 0.05)],
	[&"siege_engine", &"rail", 75, "siege_rail_locked", Vector2.ZERO],
	[&"foundry", &"slag_fountain", 80, "foundry_slag_fountain_raining", Vector2.ZERO],
	[&"foundry", &"slag_fountain", 170, "foundry_slag_fountain_flower", Vector2.ZERO],
	[&"foundry", &"furnace_waves", 160, "foundry_furnace_waves", Vector2.ZERO],
	[&"foundry", &"molten_flood", 70, "foundry_molten_flood_locked", Vector2.ZERO],
	[&"foundry", &"molten_flood", 120, "foundry_molten_flood_burning", Vector2.ZERO],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(6.5, -4.0)
const BOSS_AT := Vector2(-1.0, 1.0)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _step := 0
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/boss_fights/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
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
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d((PLAYER_AT + BOSS_AT) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var want: int = spec[2]
	if _step < want:
		var walk: Vector2 = spec[4]
		_world.actors.set_pos(0, PLAYER_AT + walk * _step)
		var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		_step += 1
		return false
	_step += 1
	if _step < want + 10:  # frame-time animation and the shell's rise settle
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[3]]
	img.save_jpg(path, 0.85)
	print("boss_fights: ", path)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
