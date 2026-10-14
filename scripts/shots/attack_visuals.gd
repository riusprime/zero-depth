extends SceneTree
## v0.8.0 AV (owner O7, O8): renders the 3D attack visuals for the owner: the bosses' and enemies' fireballs as lit 3D
## bodies (close up), and the Gatekeeper's shock lanes from cracked ground (tracking, locked) to the stone spikes'
## strike and sink, in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World. Needs
## a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_visuals.gd [-- from=N]
## Writes build/shots/<version>/av/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

const K := ActorStore.Kind
## Bosses: [boss, attack, ticks into the attack, label, camera size (m), focus (0 the player .. 1 the boss)].
## Enemies: [&"enemy", kind, ticks after its first shot, label, camera size, where it starts].
const PLAN := [
	[&"gatekeeper", &"rock_rings", 110, "gatekeeper_ember_stones", 9.0, 0.5],
	[&"warlord", &"javelin_fan", 90, "warlord_spear_embers", 9.0, 0.45],
	[&"brood_mother", &"web_spiral", 150, "brood_acid_globs", 9.0, 0.5],
	[&"hive_lens", &"prism_spiral", 164, "hive_prism_orbs", 9.0, 0.5],
	[&"siege_engine", &"turret_cross", 150, "siege_cannon_embers", 10.0, 0.5],
	[&"foundry", &"slag_fountain", 80, "foundry_molten_drops_raining", 11.0, 0.5],
	[&"foundry", &"furnace_waves", 160, "foundry_molten_drops", 9.0, 0.5],
	[&"enemy", K.ARC_CASTER, 16, "arc_caster_plasma", 8.0, Vector2(5.0, -3.0)],
	[&"enemy", K.LENS_DRONE, 26, "lens_drone_orbs", 8.0, Vector2(-5.0, 1.5)],
	[&"enemy", K.BOMB_DRONE, 18, "bomb_drone_cinders", 8.0, Vector2(-5.0, 1.5)],
	[&"gatekeeper", &"shock_lanes", 40, "gatekeeper_lanes_tracking", 16.0, 0.3],
	[&"gatekeeper", &"shock_lanes", 85, "gatekeeper_lanes_locked", 16.0, 0.3],
	[&"gatekeeper", &"shock_lanes", 99, "gatekeeper_spikes_erupting", 12.0, 0.15],
	[&"gatekeeper", &"shock_lanes", 106, "gatekeeper_spikes_standing", 12.0, 0.15],
	[&"gatekeeper", &"shock_lanes", 106, "gatekeeper_spikes_close", 7.0, 0.0],
	[&"gatekeeper", &"shock_lanes", 124, "gatekeeper_spikes_sinking", 12.0, 0.15],
	[&"gatekeeper", &"shock_lanes", 140, "gatekeeper_cracks_left", 12.0, 0.15],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(6.5, -4.0)
const BOSS_AT := Vector2(-1.0, 1.0)
const ENEMY_PLAYER_AT := Vector2.ZERO
const LIMIT := 1200

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _k := 0
var _step := 0
var _id := -1
var _after := -1
var _settle := 0
var _dir := ""
var _focus := Vector3.ZERO


func _initialize() -> void:
	_dir = "res://build/shots/%s/av/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	for a in OS.get_cmdline_user_args():  # `-- from=13`: resume at shot 13 (software rendering is slow)
		if a.begins_with("from="):
			_k = clampi(int(a.trim_prefix("from=")) - 1, 0, PLAN.size() - 1)
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
	var focus := Vector2.ZERO
	if spec[0] == &"enemy":
		_world.actors.set_pos(0, ENEMY_PLAYER_AT)
		_id = _world.add_enemy(spec[1], spec[5])
		focus = (ENEMY_PLAYER_AT + (spec[5] as Vector2)) * 0.5
	else:
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
		BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(spec[1]))
		_world.bosses.chained[BossAi.entry_of(_world, i)] = 1
		focus = PLAYER_AT.lerp(BOSS_AT, float(spec[5]))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the game's lit look (and its effects layer), as main.gd sets it
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = spec[4]
	_view.rig.camera.size = spec[4]
	_focus = SimPlane.to_3d(focus)
	_view.rig.snap_to(_focus)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0
	_after = -1
	_settle = 0


## The enemy's shots are out.
func _fired() -> bool:
	for j in _world.projectiles.size():
		if _world.projectiles.owner[j] == _id:
			return true
	return false


func _tick_once(aim_at: Vector2) -> void:
	var aim := Kin.angle_of(aim_at - _world.player_pos())
	_world.step(InputFrame.make(Vector2i.ZERO, aim, 0, 0, 0))
	_view.sync()


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	_view.rig.snap_to(_focus)  # the shot's own framing, not the hero-following camera
	if spec[0] == &"enemy":
		if _after < int(spec[2]):
			var i := _world.actors.index_of(_id)
			if (
				i >= 0
				and spec[1] == K.BOMB_DRONE
				and _world.actors.state[i] == EnemyAi.State.ACTIVE
			):
				var to := Vector2(_world.actors.lock_x[i], _world.actors.lock_y[i])
				_world.actors.set_pos(0, to + Vector2(1.6, 1.6))
			_tick_once(spec[5])
			_step += 1
			if _after >= 0:
				_after += 1
			elif _fired() or _step >= LIMIT:
				_after = 0
			return false
	elif _step < int(spec[2]):
		_world.actors.set_pos(0, PLAYER_AT)
		_tick_once(BOSS_AT)
		_step += 1
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[3]]
	img.save_jpg(path, 0.88)
	print("attack_visuals: ", path, " (tick ", _step, ")")
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
