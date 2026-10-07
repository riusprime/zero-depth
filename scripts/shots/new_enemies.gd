extends SceneTree
## Renders the v0.3.5 AI enemies for the owner: the Arc Caster and the Bomb Drone in the real game view (WorldViewRoot:
## the Ruins stage, the iso camera, ActorViews, TelegraphViews) of a real World, each mid-spell with its telegraph.
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/new_enemies.gd
## Writes build/shots/<version>/enemies/new_enemies.png (a 2 x 2 sheet) and prints its path. Frames are grabbed in
## _process. Cells: the Arc Caster's bolt line, its 3-bolt spread, its rune, and the Bomb Drone's filling circle.

const CELL := Vector2i(640, 440)
## [label, kind, spell (EnemyAi.Spell, -1 = any)].
const PLAN := [
	["arc caster: bolt", ActorStore.Kind.ARC_CASTER, EnemyAi.Spell.BOLT],
	["arc caster: spread", ActorStore.Kind.ARC_CASTER, EnemyAi.Spell.SPREAD],
	["arc caster: rune", ActorStore.Kind.ARC_CASTER, EnemyAi.Spell.RUNE],
	["bomb drone: bomb", ActorStore.Kind.BOMB_DRONE, -1],
]
const PLAYER_AT := Vector2(2.0, -1.5)

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _settle := -1
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
	_id = _world.add_enemy(spec[1], Vector2(-2.5, 3.0))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.rig.view_size = 11.0
	_view.rig.camera.size = 11.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.5, -0.5)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_settle = -1


## Steps the sim one tick per frame until the wanted spell is about two thirds through its windup, then lets the
## frame-time animation settle and grabs the cell.
func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_cells.size()]
	if _settle < 0:
		var i := _world.actors.index_of(_id)
		var a := _world.actors
		var ready: bool = (
			i >= 0
			and a.state[i] == EnemyAi.State.WINDUP
			and (spec[2] < 0 or a.pick[i] == spec[2])
			and a.state_t[i] >= a.windup[i] * 2 / 3
		)
		if ready:
			_settle = 12
			return false
		_world.actors.set_pos(0, PLAYER_AT)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		var aim := Kin.angle_of(a.pos(maxi(i, 0)) - PLAYER_AT)
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
	var out := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for k in _cells.size():
		out.blit_rect(
			_cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i(k % 2 * CELL.x, k / 2 * CELL.y)
		)
	var path := _dir + "new_enemies.png"
	out.save_png(path)
	print("new_enemies: ", path)
