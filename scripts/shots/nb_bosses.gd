extends SceneTree
## v0.9.0 NB1: renders the new bosses for the owner. Shot 1: the five installed models (assets/models/bosses/boss_*.glb,
## nb_prep.py) side by side as delivered and prepared, front (+Z) to the camera, the static ones' parts tinted apart
## faintly by a rim so the cuts read. Shot 2: The Tidecaller mid-Pull in the real game view (WorldViewRoot on the
## Ruins stage, the iso camera) of a real World: the bell's windup over, the room pulling the hero in, its Tide Rings
## bending, the water drawn round it (TideViews). Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_bosses.gd
## Writes build/shots/v0.9.0/nb1/<n>_<label>.jpg and prints each path.

const IDS := [
	"boss_tidecaller",
	"boss_twin_warden_amber",
	"boss_twin_warden_violet",
	"boss_clockwork_judge",
	"boss_lantern_shade",
]
const SIZE := Vector2i(1280, 720)
## Shot 2: the Pull's windup (60 ticks) and this far into the pull.
const PULL_TICKS := 60 + 75
const BOSS_AT := Vector2(-1.0, 1.0)
const PLAYER_AT := Vector2(-6.5, 4.5)

var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _shot := 0
var _frames := 0
var _ticks := 0
var _boss := -1
var _dir := "res://build/shots/v0.9.0/nb1/"
var _lineup: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build_lineup()


func _build_lineup() -> void:
	_lineup = Node3D.new()
	_vp.add_child(_lineup)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#20222A")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8890A0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_lineup.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_lineup.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 12)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#3A3C44")
	floor_mesh.material_override = fm
	_lineup.add_child(floor_mesh)
	var x := -8.4
	for id: String in IDS:
		var scene := load("res://assets/models/bosses/%s.glb" % id) as PackedScene
		var inst: Node3D = scene.instantiate()
		inst.position = Vector3(x, 0, 0)
		_lineup.add_child(inst)
		var label := Label3D.new()
		label.text = id.trim_prefix("boss_")
		label.font_size = 48
		label.pixel_size = 0.006
		label.position = Vector3(x, -0.05, 1.6)
		label.rotation = Vector3(-PI * 0.5, 0, 0)
		_lineup.add_child(label)
		x += 4.2
	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(0, 5.8, 19.0)
	_lineup.add_child(cam)
	cam.transform = cam.transform.looking_at(Vector3(0, 1.4, 0))
	cam.current = true


func _build_pull() -> void:
	_lineup.queue_free()
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.set_boss_tables(ContentCompiler.compile_bosses(_repo))
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == &"tidecaller":
			bk = j
	var t := _world.boss_tables[bk]
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()
	t.punish_ticks = 0
	t.sig_every_ticks = 0
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	BossAi.start_attack(_world, i, t.attack_index(&"the_pull"))
	_world.bosses.chained[BossAi.entry_of(_world, i)] = 1
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(-2.5, 2.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _process(_delta: float) -> bool:
	if _shot == 1 and _ticks < PULL_TICKS:
		var n := 6 if PULL_TICKS - _ticks > 12 else 1
		for k in n:
			var aim := Kin.angle_of(BOSS_AT - _world.player_pos())
			_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
			_view.sync()
			_ticks += 1
		return false
	_frames += 1
	if _frames < 12:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var label := "five_boss_models_side_by_side" if _shot == 0 else "tidecaller_mid_pull"
	var path := _dir + "%d_%s.jpg" % [_shot + 1, label]
	img.save_jpg(path, 0.88)
	print("nb_bosses: ", path)
	if _shot == 0:
		print("nb_bosses: player at the pull's start ", PLAYER_AT)
	else:
		print(
			"nb_bosses: player now ",
			_world.player_pos(),
			" tide ",
			_view.reader.boss_tide(_view.reader.boss_index())
		)
	_shot += 1
	_frames = 0
	if _shot >= 2:
		return true
	_build_pull()
	return false
