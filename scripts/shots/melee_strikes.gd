extends SceneTree
## v0.8.0 P1 (owner O25, O26): the Warden's red circle and overhead slam, and the melee kinds' raised-and-held wind-ups
## and strikes, each in the real game view (WorldViewRoot: the Ruins stage, the iso camera, ActorViews,
## TelegraphViews) of a real World. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/melee_strikes.gd
## Writes build/shots/<version>/enemies/melee_strikes.png (a 3 x 2 sheet) and one PNG per cell, and prints the paths.

const CELL := Vector2i(640, 440)
const K := ActorStore.Kind
## [file, kind, where it starts, camera view size, moment]: "windup" two thirds into the windup (the pose held),
## "strike" once the strike is out (the Warden: once its dust ring is a third of the way out).
const PLAN := [
	["warden_windup", K.WARDEN, Vector2(-1.2, 1.0), 7.0, "windup"],
	["warden_slam", K.WARDEN, Vector2(-1.2, 1.0), 7.0, "strike"],
	["splitter_windup", K.SPLITTER, Vector2(-1.0, 0.8), 4.5, "windup"],
	["splitter_strike", K.SPLITTER, Vector2(-1.0, 0.8), 4.5, "strike"],
	["shield_bearer_windup", K.SHIELD_BEARER, Vector2(-1.4, 1.0), 5.0, "windup"],
	["charger_windup", K.CHARGER, Vector2(-3.5, 2.5), 8.0, "windup"],
]
const PLAYER_AT := Vector2(1.0, -0.6)

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _settle := -1
var _struck := false
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
	_world.actors.set_pos(0, PLAYER_AT)
	_id = _world.add_enemy(spec[1], spec[2])
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
	_struck = false


func _avatar() -> AvatarBase:
	var node := _view.actors.actor_node(_id)
	return node.get_meta(&"enemy_avatar") as AvatarBase if node != null else null


func _ready_to_grab(moment: String) -> bool:
	var a := _world.actors
	var i := a.index_of(_id)
	if i < 0:
		return false
	if moment == "windup":
		return a.state[i] == EnemyAi.State.WINDUP and a.state_t[i] >= a.windup[i] * 2 / 3
	if a.state[i] == EnemyAi.State.ACTIVE:
		_struck = true
	if not _struck:
		return false
	var av := _avatar()
	if av is WardenAvatar:
		return (av as WardenAvatar).dust_amount() >= 0.3
	return av != null and av.strike_swing() >= 0.99


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_cells.size()]
	if _settle < 0:
		if _ready_to_grab(spec[4]):
			# A windup holds its pose (nothing steps the sim); a strike is grabbed at once, mid-motion.
			_settle = 10 if spec[4] == "windup" else 1
			return false
		if not (_struck and spec[4] == "strike"):
			_world.actors.set_pos(0, PLAYER_AT)
			_world.actors.hp[0] = _world.actors.max_hp[0]
			var i := maxi(_world.actors.index_of(_id), 0)
			var aim := Kin.angle_of(_world.actors.pos(i) - PLAYER_AT)
			_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
			_view.sync()
		return false
	_settle -= 1
	if _settle > 0:
		return false
	var img := _grab()
	_cells.append(img)
	var one := _dir + "%s.png" % spec[0]
	img.save_png(one)
	print("cell: ", one)
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
	var path := _dir + "melee_strikes.png"
	out.save_png(path)
	print("melee_strikes: ", path)
