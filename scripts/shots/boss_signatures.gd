extends SceneTree
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S1-S3): renders each boss's signature mechanic for the owner, in the real
## game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World: the Gatekeeper's pillars standing
## after its shock lanes and its Rock Rings breaking on them, the Warlord's javelins stuck in the floor and flying
## back, the Brood Mother's eggs sitting (one hit, its pip down) and bursting in phase 3. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_signatures.gd
## Writes build/shots/v0.8.0/bs1/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

## [boss, [[attack, ticks after it starts] ...] run in turn, label, the boss's phase index, hit an egg].
const PLAN := [
	[&"gatekeeper", [[&"shock_lanes", 150]], "gatekeeper_pillars_standing", 0, false],
	[
		&"gatekeeper",
		[[&"shock_lanes", 100], [&"rock_rings", 110]],
		"gatekeeper_rock_rings_break_on_pillars",
		0,
		false
	],
	[&"warlord", [[&"javelin_fan", 220]], "warlord_javelins_stuck", 0, false],
	[&"warlord", [[&"javelin_fan", 345]], "warlord_javelins_recalled", 0, false],
	[&"brood_mother", [[&"egg_storm", 190]], "brood_eggs_sitting", 0, true],
	[&"brood_mother", [[&"egg_storm", 290]], "brood_eggs_burst_phase_3", 2, false],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(6.0, -1.0)  # clear of the stage's inner walls, so the lanes run
const BOSS_AT := Vector2(-1.0, 1.0)

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


func _initialize() -> void:
	_dir = "res://build/shots/v0.8.0/bs1/"
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
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.bosses.phase[BossAi.entry_of(_world, i)] = spec[3]
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
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d((PLAYER_AT + BOSS_AT) * 0.5))
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
		_world.actors.set_pos(0, PLAYER_AT)
		var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		_stage_t += 1
		if spec[4] and _stage_t == 150:
			_hit_an_egg()
		if _stage_t >= int(stages[_stage][1]):
			_stage += 1
			_stage_t = 0
			if _stage < stages.size():
				_start(stages[_stage][0])
		return false
	_step += 1
	if _step < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[2]]
	img.save_jpg(path, 0.85)
	print("boss_signatures: ", path)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false


## Hits the first egg once (its pip shows the damage).
func _hit_an_egg() -> void:
	for i in _world.actors.size():
		if BossSignatures.is_egg(_world, i):
			Damage.hit(
				_world,
				i,
				8,
				_world.actors.ids[0],
				_world.actors.ids[0],
				_world.take_root(),
				SimEvent.TAG_MELEE,
				_world.player_pos(),
				_world.actors.pos(i)
			)
			return
