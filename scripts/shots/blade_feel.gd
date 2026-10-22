extends SceneTree
## v0.8.0 GF3 (owner O22): renders the Blade's feel for the owner in the real game view (WorldViewRoot on the Ruins
## stage, the iso camera) of a real World with the Blade build: a swing with its slash edge and the edge spark, a
## slash's impact (the cut along the swing and its sparks), the struck enemy's flinch (held by the hit-stop), and the
## finisher's spin landing. The enemy is held (speed 0, no attacks); the hero swings by its own input frames
## (PRIMARY pressed when no swing runs or the combo window is open). Nothing else is staged. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 -s scripts/shots/blade_feel.gd
## Optional: after `--`, the shot numbers to render (1-based); none: all of them.
## Writes build/shots/v0.8.0/gf3/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

const K := ActorStore.Kind
## [label, enemy kind, where it stands, the moment (see _ready_to_grab), ticks after it, combo step it waits for].
const PLAN := [
	["swing_trail", K.CHARGER, Vector2(3.2, 2.4), &"sweep", 0, 0],
	["blade_impact", K.WARDEN, Vector2(1.45, 0.0), &"impact", 3, 0],
	["flinch_held", K.CHARGER, Vector2(1.35, 0.0), &"held", 0, 0],
	["finisher", K.WARDEN, Vector2(1.6, 0.0), &"impact", 3, 3],
	["thrust_impact", K.CHARGER, Vector2(2.0, 0.0), &"impact", 2, 2],
]
const SIZE := Vector2i(1280, 720)
const LIMIT := 400

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _id := -1
var _k := 0
var _after := -1
var _settle := 0
var _ticks := 0
var _seen := 0
var _dir := ""
var _todo: Array[int] = []


func _initialize() -> void:
	_dir = "res://build/shots/v0.8.0/gf3/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int() and int(a) >= 1 and int(a) <= PLAN.size():
			_todo.append(int(a) - 1)
	if _todo.is_empty():
		for k in PLAN.size():
			_todo.append(k)
	_k = _todo.pop_front()
	_build(_k)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	t.crit_chance_permille = 0
	var enemies := ContentCompiler.compile_enemies(_repo)
	for e in enemies:
		e.speed = 0.0
	_world = StageScenario.build(9, t, enemies)
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_id = _world.add_enemy(spec[1], spec[2])
	var i := _world.actors.index_of(_id)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.cd[i] = 1 << 30
	_world.actors.invuln[i] = 0
	_world.actors.hp[i] = 1 << 22
	_world.actors.max_hp[i] = 1 << 22
	_world.actors.facing[i] = 0  # its back to the blade (a Warden's armoured front would deflect)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 6.0
	_view.rig.camera.size = 6.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.8, 0.2)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_after = -1
	_settle = 0
	_ticks = 0
	_seen = 0


func _ready_to_grab(moment: StringName, step: int) -> bool:
	var feel := _view.hit_feel
	var r := _view.reader
	if r.combo_step() != step or r.swing_tick() <= 0:
		_seen = feel.impacts.added
		return false
	match moment:
		&"sweep":
			return r.swing_tick() == 4
		&"impact":
			return feel.impacts.added > _seen
		&"held":
			return feel.hit_stop.holding()
	return false


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _after < 0 or _after < int(spec[4]):
		if _after < 0 and _ready_to_grab(spec[3], spec[5]) and int(spec[4]) == 0:
			_after = 0
		else:
			var aim := Kin.angle_of((spec[2] as Vector2) - _world.player_pos())
			var press := _world.swing_t == 0 or _world.combo_window > 0
			var b := InputFrame.PRIMARY if press else 0
			_world.step(InputFrame.make(Vector2i.ZERO, aim, 140, b, b))
			_view.sync()
			_ticks += 1
			if _after >= 0:
				_after += 1
			elif _ready_to_grab(spec[3], spec[5]) or _ticks >= LIMIT:
				_after = 0
		return false
	_settle += 1
	if _settle < 2:  # one frame for the view to draw what was synced
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	print(
		"blade_feel: ",
		path,
		" (tick ",
		_ticks,
		", step ",
		_view.reader.combo_step(),
		", swing tick ",
		_view.reader.swing_tick(),
		", impacts ",
		_view.hit_feel.impacts.added,
		", flinches ",
		_view.hit_feel.flinches,
		", pieces ",
		_view.hit_feel.impacts.last_pieces,
		", freezes ",
		_view.hit_feel.hit_stop.freezes,
		", held ",
		_view.hit_feel.hit_stop.holding(),
		")"
	)
	if _todo.is_empty():
		return true
	_k = _todo.pop_front()
	_build(_k)
	return false
