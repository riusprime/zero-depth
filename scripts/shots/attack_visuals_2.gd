extends SceneTree
## v0.8.0 AV part 2 (owner O7): renders each boss ground attack's styled marker and 3D strike for the owner, in the
## real game view (WorldViewRoot on the Ruins stage, the iso camera, its effects layer) of a real World. Needs a
## renderer (one at a time on a shared machine: software renders are memory-hungry):
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_visuals_2.gd [-- from=N to=M]
## Writes build/shots/<version>/av2/<n>_<label>.jpg and prints each path with the tick it was taken on. A shot is
## taken a number of ticks after the strike (BossStrikeViews raised it), or, when that number is negative, that many
## ticks into the attack (the marker before the strike).

## [boss, attack, ticks after the strike (or -ticks into the attack), label, camera size (m), focus (0 the player
## .. 1 the boss), and optionally where the player stands (else PLAYER_AT)].
const PLAN := [
	[&"gatekeeper", &"fist_slam", -80, "gatekeeper_fist_slam_locked", 10.0, 0.2],
	[&"gatekeeper", &"fist_slam", 5, "gatekeeper_fist_slam_crater", 10.0, 0.2],
	[&"gatekeeper", &"sweep", 4, "gatekeeper_sweep_dust_arc", 11.0, 0.7],
	[&"warlord", &"spear_lines", 8, "warlord_spear_lines", 14.0, 0.5],
	[&"warlord", &"lunge_dash", 12, "warlord_lunge_skid", 13.0, 0.5, Vector2(-8.0, -3.0)],
	[&"warlord", &"shield_bash", 3, "warlord_shield_bash", 10.0, 0.7],
	[&"warlord", &"javelin_rain", 5, "warlord_javelin_rain", 12.0, 0.3],
	[&"brood_mother", &"egg_storm", -88, "brood_egg_shadows", 11.0, 0.2],
	[&"brood_mother", &"egg_storm", 4, "brood_acid_splat", 11.0, 0.2],
	[&"brood_mother", &"leap", 3, "brood_leap_impact", 11.0, 0.3],
	[&"brood_mother", &"burrow", 6, "brood_burrow_eruption", 11.0, 0.2],
	[&"hive_lens", &"focus_beam", -80, "hive_focus_beam_locked", 14.0, 0.5],
	[&"hive_lens", &"focus_beam", 5, "hive_focus_beam", 14.0, 0.5],
	[&"hive_lens", &"lens_flare", 4, "hive_lens_flare", 11.0, 0.8],
	[&"siege_engine", &"mortar_grid", -80, "siege_mortar_grid_locked", 12.0, 0.2],
	[&"siege_engine", &"mortar_grid", 4, "siege_mortar_shells", 12.0, 0.2],
	[&"siege_engine", &"barrage", 4, "siege_barrage_shells", 12.0, 0.2],
	[&"siege_engine", &"rail", 2, "siege_rail_streak", 14.0, 0.5],
	[&"siege_engine", &"shockwave", 10, "siege_shockwave", 16.0, 0.8],
	[&"foundry", &"molten_flood", -80, "foundry_molten_flood_locked", 14.0, 0.5],
	[&"foundry", &"molten_flood", 16, "foundry_molten_flood_pouring", 14.0, 0.5],
	[&"foundry", &"molten_flood", 160, "foundry_molten_flood_cooling", 14.0, 0.5],
	[&"foundry", &"vent_blast", 5, "foundry_vent_blast", 11.0, 0.8],
	[&"foundry", &"firestorm", 16, "foundry_firestorm", 16.0, 0.5],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(6.5, -4.0)
const BOSS_AT := Vector2(-1.0, 1.0)
const LIMIT := 900

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _last := -1
var _step := 0
var _after := -1
var _settle := 0
var _dir := ""
var _focus := Vector3.ZERO
var _player := PLAYER_AT


func _initialize() -> void:
	_dir = "res://build/shots/%s/av2/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_last = PLAN.size() - 1
	for a in OS.get_cmdline_user_args():  # `-- from=5 to=9`: a part of the plan (software rendering is slow)
		if a.begins_with("from="):
			_k = clampi(int(a.trim_prefix("from=")) - 1, 0, PLAN.size() - 1)
		if a.begins_with("to="):
			_last = clampi(int(a.trim_prefix("to=")) - 1, 0, PLAN.size() - 1)
	_build(_k)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.set_boss_tables(ContentCompiler.compile_bosses(_repo))
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == spec[0]:
			bk = j
	_player = spec[6] if spec.size() > 6 else PLAYER_AT
	_world.actors.set_pos(0, _player)
	var id := _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(id)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(spec[1]))
	_world.bosses.chained[BossAi.entry_of(_world, i)] = 1
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the game's lit look (and its effects layer), as main.gd sets it
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = spec[4]
	_view.rig.camera.size = spec[4]
	_focus = SimPlane.to_3d(_player.lerp(BOSS_AT, float(spec[5])))
	_view.rig.snap_to(_focus)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0
	_after = -1
	_settle = 0


func _tick_once() -> void:
	var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
	_world.step(InputFrame.make(Vector2i.ZERO, aim, 0, 0, 0))
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_view.sync()


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var at := int(spec[2])
	_view.rig.snap_to(_focus)  # the shot's own framing, not the hero-following camera
	var due := false
	if at < 0:
		due = _step >= -at
	else:
		due = _after >= at
	if not due and _step < LIMIT:
		_world.actors.set_pos(0, _player)
		_tick_once()
		_step += 1
		if _after >= 0:
			_after += 1
		elif _view.strikes.strike_count() > 0:
			_after = 0
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[3]]
	img.save_jpg(path, 0.88)
	print(
		"attack_visuals_2: ",
		path,
		" (tick ",
		_step,
		", ",
		_after,
		" after the strike, ",
		_view.strikes.strike_count(),
		" strikes)"
	)
	_k += 1
	if _k > _last:
		return true
	_build(_k)
	return false
