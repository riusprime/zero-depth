extends SceneTree
## Renders the v0.4.0 EN horde kinds for the owner, each acting in the real game view (WorldViewRoot: the Ruins stage,
## the iso camera, ActorViews, TelegraphViews, HordeVisuals) of a real World. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/horde_enemies.gd
## Writes build/shots/<version>/enemies/horde_enemies.png (a 3 x 2 sheet) and prints its path. Cells: a Swarmer pack
## with one winding up its bite, a Splitter's swipe beside two Splitlings, a Shield Bearer's bash, a Mender's beam on
## a hurt Shield Bearer, a mine armed under the player, and a Sniper's line.

const CELL := Vector2i(640, 440)
const K := ActorStore.Kind
## [label, kind, where it starts, camera view size].
const PLAN := [
	["swarmer pack", K.SWARMER, Vector2(-2.5, 2.5), 10.0],
	["splitter and splitlings", K.SPLITTER, Vector2(-2.0, 2.0), 10.0],
	["shield bearer: bash", K.SHIELD_BEARER, Vector2(-1.5, 1.0), 9.0],
	["mender: heal beam", K.MENDER, Vector2(-4.0, 4.0), 11.0],
	["mine layer: armed mine", K.MINE_LAYER, Vector2(-4.0, 3.0), 10.0],
	["sniper: line", K.SNIPER, Vector2(-6.3, -4.9), 12.0],
]
const PLAYER_AT := Vector2(2.0, -1.5)

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _ally := -1
var _settle := -1
var _ticks := 0
var _player := PLAYER_AT
var _cells: Array[Image] = []


func _initialize() -> void:
	_dir = "res://build/shots/%s/enemies/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
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
		9 + k, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_player = PLAYER_AT
	_world.actors.set_pos(0, _player)
	_id = _world.add_enemy(spec[1], spec[2])
	_ally = -1
	match spec[1]:
		K.SWARMER:
			for n in 4:
				_world.add_enemy(K.SWARMER, spec[2] + Kin.dir(n * 1024 + 512) * 0.9)
		K.SPLITTER:
			_world.add_enemy(K.SPLITLING, spec[2] + Vector2(1.6, 1.4))
			_world.add_enemy(K.SPLITLING, spec[2] + Vector2(-1.2, -1.0))
		K.MENDER:
			_ally = _world.add_enemy(K.SHIELD_BEARER, Vector2(0.0, 1.5))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.rig.view_size = spec[3]
	_view.rig.camera.size = spec[3]
	_view.rig.snap_to(SimPlane.to_3d((PLAYER_AT + spec[2]) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_settle = -1
	_ticks = 0


## The cell's moment: the attack about two thirds through its windup; the Mender healing; the mine two thirds armed.
func _ready_to_grab() -> bool:
	var a := _world.actors
	var i := a.index_of(_id)
	if i < 0:
		return false
	match a.kinds[i]:
		K.MENDER:
			return a.pick[i] > 0 and _ticks > 90
		K.MINE_LAYER:
			if _world.mines.size() > 0:
				_player = _world.mines.pos(0) + Vector2(0.3, 0.0)
				var m := _world.mines
				return m.fuse[0] >= 0 and m.fuse[0] >= m.fuse_total[0] * 2 / 3
			return false
	return a.state[i] == EnemyAi.State.WINDUP and a.state_t[i] >= a.windup[i] * 2 / 3


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_cells.size()]
	if _settle < 0:
		if _ready_to_grab():
			_settle = 12
			return false
		_ticks += 1
		_world.actors.set_pos(0, _player)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		var j := _world.actors.index_of(_ally)
		if j >= 0:
			_world.actors.hp[j] = 30  # hurt, so the Mender heals it
		var i := maxi(_world.actors.index_of(_id), 0)
		var aim := Kin.angle_of(_world.actors.pos(i) - _player)
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		return false
	_settle -= 1
	if _settle > 0:
		return false
	_cells.append(_grab())
	print("cell: ", spec[0])
	if _cells.size() == PLAN.size():
		_write()
		return true
	_build(_cells.size())
	return false


func _grab() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _write() -> void:
	var out := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for k in _cells.size():
		out.blit_rect(
			_cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i(k % 3 * CELL.x, k / 3 * CELL.y)
		)
	var path := _dir + "horde_enemies.png"
	out.save_png(path)
	print("horde_enemies: ", path)
