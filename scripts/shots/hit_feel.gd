extends SceneTree
## v0.8.0 GF2 (owner O20, O21): renders the hit feel for the owner in the real game view (WorldViewRoot on the Ruins
## stage, the iso camera) of a real World: the Gun's bolts landing on a held enemy (the impact and its spray out of the
## far side), the enemy's flinch, the damage numbers thrown up and out, and a crit's number (the shot's player has
## the crit chance raised to the cap so crits show up; nothing else is staged). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/hit_feel.gd
## Optional: after `--`, the shot numbers to render (1-based), e.g. `-- 4 5 6`; none: all of them.
## Writes build/shots/<version>/gf2/<n>_<label>.jpg and prints each path. Frames are grabbed in _process.

const K := ActorStore.Kind
## [label, enemy kind, where it stands, crit chance raised, the moment (see _ready_to_grab), ticks after it].
const PLAN := [
	["bolt_impact_spray", K.WARDEN, Vector2(4.0, 0.6), false, &"impact", 2],
	["bolt_impact_spray_b", K.CHARGER, Vector2(3.6, -1.2), false, &"impact", 4],
	["flinch_charger", K.CHARGER, Vector2(3.6, 0.0), false, &"flinch", 0],
	["flinch_swarmer", K.SWARMER, Vector2(3.6, 0.0), false, &"flinch", 0],
	["thrown_numbers", K.WARDEN, Vector2(4.0, 0.0), false, &"numbers", 0],
	["crit_number", K.WARDEN, Vector2(4.0, 0.0), true, &"crit", 3],
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
var _dir := ""
## The plan entries to render (indices into PLAN).
var _todo: Array[int] = []


func _initialize() -> void:
	_dir = "res://build/shots/%s/gf2/" % GameVersion.label()
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
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	if spec[3]:
		t.crit_chance_permille = 1000  # capped by the sim (Stats.crit_chance)
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
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the game's lit look (and its effects layer), as main.gd sets it
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 8.0
	_view.rig.camera.size = 8.0
	_view.rig.snap_to(SimPlane.to_3d((spec[2] as Vector2) * 0.6))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_after = -1
	_settle = 0
	_ticks = 0


func _ready_to_grab(moment: StringName) -> bool:
	var feel := _view.hit_feel
	match moment:
		&"impact":
			return feel.impacts.added > 0
		&"flinch":
			var node := _view.actors.actor_node(_id)
			var av := node.get_meta(&"enemy_avatar") as AvatarBase if node != null else null
			return av != null and av.flinch_amount() > 0.6
		&"numbers":
			return _view.damage_numbers.showing() >= 3
		&"crit":
			for s: Array in _view.damage_numbers.shown():
				if s[1]:
					return true
	return false


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _after < 0 or _after < int(spec[5]):
		if _after < 0 and _ready_to_grab(spec[4]) and int(spec[5]) == 0:
			_after = 0
		else:
			var aim := Kin.angle_of((spec[2] as Vector2) - _world.player_pos())
			_world.step(InputFrame.make(Vector2i.ZERO, aim, 400, InputFrame.SHOOT, 0))
			_view.sync()
			_ticks += 1
			if _after >= 0:
				_after += 1
			elif _ready_to_grab(spec[4]) or _ticks >= LIMIT:
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
		"hit_feel: ",
		path,
		" (tick ",
		_ticks,
		", impacts ",
		_view.hit_feel.impacts.added,
		", flinches ",
		_view.hit_feel.flinches,
		", numbers ",
		_view.damage_numbers.showing(),
		")"
	)
	if _todo.is_empty():
		return true
	_k = _todo.pop_front()
	_build(_k)
	return false
