extends SceneTree
## v0.10.0 VX4 (VFX_PACK R31-R35): the 17 hostile shot looks (the nemesis_crescent keeps its old look) before (the
## MultiMesh core and trail) and after (the held pack effect over the same dark edge), from the game camera. Two sheets,
## each 9 (then 8) looks in a grid, all flying along +x (to the right of the sim plane); the old pass on top, the pack's
## below. The real game view (WorldViewRoot, the Ruins palette, the effects layer) of a real World at Effects density
## High; the shots are held on their path by this tool (their positions are written each tick) so they stay in frame.
## A tool, not a test. Needs a renderer (no --headless) and a fixed frame time:
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx4_shots.gd
## Writes build/shots/v0.10.0/vx4/sheet_<n>.png and prints each path.

const SHEETS := [
	[
		&"ember_stone",
		&"cannon_ember",
		&"molten_drop",
		&"bomb_cinder",
		&"warden_amber_ember",
		&"spear_ember",
		&"crown_bolt",
		&"nemesis_bolt",
		&"arc_plasma",
	],
	[
		&"gear_spark",
		&"lens_orb",
		&"prism_orb",
		&"crown_orb",
		&"tide_bubble",
		&"acid_glob",
		&"shade_wisp",
		&"warden_violet_ember",
	],
]
const COLS := 4
const CELL := Vector2(3.4, 2.6)
const START := Vector2(-6.0, -3.0)
const SPEED := 2.5
const GRAB := 120
const RENDER := Vector2i(1280, 720)
const SEED := 4242

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _sheet_k := 0
var _after := false
var _frame := 0
var _sheet: Image
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx4/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = RENDER
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_new_sheet()
	_build()


func _new_sheet() -> void:
	_sheet = Image.create(RENDER.x, RENDER.y * 2, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _spot(n: int) -> Vector2:
	return START + Vector2((n % COLS) * CELL.x, (n / COLS) * CELL.y)


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	_world = World.new(9, t)
	_world.set_enemy_tables(ContentCompiler.compile_enemies(_repo))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, START + Vector2(CELL.x * 1.5, CELL.y))
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	var looks: Array = SHEETS[_sheet_k]
	for n in looks.size():
		_world.projectiles.add(5000 + n, 0, 0, _spot(n), Vector2(0.001, 0), 0.18, 1 << 20)
		_world.projectiles.set_look(n, looks[n])
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 9.0
	_view.rig.camera.size = 9.0
	_view.rig.snap_to(SimPlane.to_3d(START + Vector2(CELL.x * 1.5, CELL.y)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	if not _after:
		_view.attack_forms.vfx.pack_fx = null  # the old MultiMesh look
		_view.fireballs.pack_fx = null
	_frame = 0


func _process(_delta: float) -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	# the tool holds the shots on their path (the sim would carry them out of frame)
	var looks: Array = SHEETS[_sheet_k]
	for n in mini(looks.size(), _world.projectiles.ids.size()):
		var at := _spot(n) + Vector2(SPEED * float(_frame - GRAB) / 60.0, 0.0)
		_world.projectiles.pos_x[n] = at.x
		_world.projectiles.pos_y[n] = at.y
	_view.sync()
	_frame += 1
	if _frame < GRAB:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, RENDER), Vector2i(0, RENDER.y if _after else 0))
	if not _after:
		_after = true
	else:
		var path := _dir + "sheet_%d.png" % (_sheet_k + 1)
		_sheet.save_png(path)
		print("vx4_shots: ", path, "  looks: ", looks)
		_after = false
		_sheet_k += 1
		if _sheet_k >= SHEETS.size():
			return true
		_new_sheet()
	_build()
	return false
