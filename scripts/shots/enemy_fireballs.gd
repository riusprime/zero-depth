extends SceneTree
## v0.7.5 EF (owner N16): renders the three fireball enemies for the owner: the Arc Caster's fan of plasma balls, the
## Lens Drone's ring of red orbs, the Bomb Drone's fireball in the air and its X of cinders, and the Needle keeping its
## lines, in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/enemy_fireballs.gd
## Writes build/shots/<version>/enemy_fireballs/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

const K := ActorStore.Kind
const S := EnemyAi.State
## [kind, label, the moment to grab (see _ready_to_grab), ticks after it, where the enemy starts].
const PLAN := [
	[K.ARC_CASTER, "arc_caster_plasma_fan", &"fired", 16, Vector2(6.0, -3.0)],
	[K.ARC_CASTER, "arc_caster_plasma_fan_b", &"fired", 16, Vector2(0.0, -7.0)],
	[K.ARC_CASTER, "arc_caster_plasma_fan_c", &"fired", 16, Vector2(5.0, 5.0)],
	[K.LENS_DRONE, "lens_drone_orb_ring", &"fired", 26, Vector2(-6.5, 1.5)],
	[K.BOMB_DRONE, "bomb_drone_fireball_in_the_air", &"lob_half", 0, Vector2(-6.5, 1.5)],
	[K.BOMB_DRONE, "bomb_drone_x_of_cinders", &"fired", 18, Vector2(-6.5, 1.5)],
	[K.NEEDLE, "needle_keeps_its_lines", &"windup_late", 0, Vector2(-6.5, 1.5)],
]
const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(0.0, 0.0)
const LIMIT := 1200

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _id := -1
var _k := 0
var _after := -1
var _settle := 0
var _ticks := 0
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/enemy_fireballs/" % GameVersion.label()
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
	_world.actors.set_pos(0, PLAYER_AT)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_id = _world.add_enemy(spec[0], spec[4])
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 15.0
	_view.rig.camera.size = 15.0
	_view.rig.snap_to(SimPlane.to_3d((PLAYER_AT + (spec[4] as Vector2)) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_after = -1
	_settle = 0
	_ticks = 0


## True on the tick the plan's moment comes: "fired" (the enemy's shots are out), "lob_half" (the Bomb Drone's
## fireball half way), "windup_late" (a windup three quarters through).
func _ready_to_grab(moment: StringName) -> bool:
	var i := _world.actors.index_of(_id)
	if i < 0:
		return false
	var tg := EnemyAi.telegraph(_world, i)
	match moment:
		&"fired":
			for j in _world.projectiles.size():
				if _world.projectiles.owner[j] == _id:
					return true
		&"lob_half":
			return tg.get("shape", &"") == &"lob" and int(tg["progress"]) >= 500
		&"windup_late":
			return _world.actors.state[i] == S.WINDUP and int(tg.get("progress", 0)) >= 750
	return false


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _after < 0 or _after < int(spec[3]):
		var i := _world.actors.index_of(_id)
		if i >= 0 and spec[0] == K.BOMB_DRONE and _world.actors.state[i] == S.ACTIVE:
			# step out of the landing after the lock, so the X bursts beside the hero
			var to := Vector2(_world.actors.lock_x[i], _world.actors.lock_y[i])
			_world.actors.set_pos(0, to + Vector2(1.6, 1.6))
		var aim := Kin.angle_of((spec[4] as Vector2) - _world.player_pos())
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 0, 0, 0))
		_view.sync()
		_ticks += 1
		if _after >= 0:
			_after += 1
		elif _ready_to_grab(spec[2]) or _ticks >= LIMIT:
			_after = 0
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[1]]
	img.save_jpg(path, 0.85)
	print("enemy_fireballs: ", path, " (tick ", _ticks, ")")
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false
