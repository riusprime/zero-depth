extends SceneTree
## v0.10.5 W3-O7 (owner F6, F16; docs/roadmap/v0.10.5/W3_O7_VFX_G2.md): the G2 candidate looks, from the game camera,
## in the real game view (WorldViewRoot, the Ruins stage, the effects layer) of a real World at Effects density High.
## - bolt_<c>.png: the Twin Wardens' violet embers (the purple bolts) in flight beside the amber twin's fireball (the
##   reference look), held on their path by this tool. <c>: now (today's look), a, b, c (CandidateLooks.bolt).
## - lance_<c>.png: the plain Lance (the data's Gun and gun_lance) at full charge (left) and its ball 12 ticks after the
##   release (right). <c>: now, a, b, c (CandidateLooks.lance).
## A tool, not a test. Needs a renderer (no --headless), off screen:
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 \
##     -s scripts/shots/w3o7_shots.gd
## Writes build/shots/v0.10.5/w3o7/ and prints each path.

const CANDIDATES: Array[StringName] = [&"", &"a", &"b", &"c"]
const SIZE := Vector2i(1280, 720)
## The Crossfire's shots (data/bullet_patterns/twin_wardens_crossfire: 0.2 m, 3 m/s): violet ones, amber ones.
const BOLTS: Array[StringName] = [
	&"warden_violet_ember",
	&"warden_violet_ember",
	&"warden_violet_ember",
	&"warden_amber_ember",
	&"warden_amber_ember",
]
const BOLT_AT: Array[Vector2] = [
	Vector2(-1.2, 1.6),
	Vector2(-2.6, 0.6),
	Vector2(-1.6, -0.5),
	Vector2(-3.0, -1.6),
	Vector2(-1.4, -2.4)
]
const BOLT_RADIUS := 0.2
const BOLT_SPEED := 3.0
const BOLT_FRAMES := 60
## The Lance: ticks of Shoot held (full charge), then ticks after the release.
const LANCE_HOLD := 80
const LANCE_AFTER := 12

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _dir := "res://build/shots/v0.10.5/w3o7/"
var _phase := 0  # 0 bolts, 1 the Lance
var _k := 0
var _frame := 0
var _charged: Image


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build()


static func _name(c: StringName) -> String:
	return "now" if c == &"" else String(c)


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	return -1


func _build() -> void:
	if _view != null:
		_view.queue_free()
	CandidateLooks.bolt = CANDIDATES[_k] if _phase == 0 else CandidateLooks.BOLT
	CandidateLooks.lance = CANDIDATES[_k] if _phase == 1 else CandidateLooks.LANCE
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	if _phase == 0:
		_world = World.new(9, t)  # an open floor: no wall stops the held shots
		_world.set_enemy_tables(ContentCompiler.compile_enemies(_repo))
	else:
		_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	if _phase == 0:
		for n in BOLTS.size():
			_world.projectiles.add(
				5000 + n, 0, 0, BOLT_AT[n], Vector2(0.001, 0), BOLT_RADIUS, 1 << 20
			)
			_world.projectiles.set_look(n, BOLTS[n])
	else:
		_world.add_item(_item(&"gun_lance"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 6.5
	_view.rig.camera.size = 6.5
	_view.rig.snap_to(SimPlane.to_3d(Vector2(-0.5, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_frame = 0


func _process(_delta: float) -> bool:
	if _phase == 0:
		return _bolts()
	return _lance()


func _bolts() -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	for n in mini(BOLTS.size(), _world.projectiles.ids.size()):
		var at := BOLT_AT[n] + Vector2(BOLT_SPEED * float(_frame - BOLT_FRAMES) / 60.0, 0.0)
		_world.projectiles.pos_x[n] = at.x
		_world.projectiles.pos_y[n] = at.y
	_view.sync()
	_frame += 1
	if _frame < BOLT_FRAMES:
		return false
	_save(_vp.get_texture().get_image(), "bolt_%s.png" % _name(CANDIDATES[_k]))
	return _next()


func _lance() -> bool:
	var held := InputFrame.SHOOT if _frame < LANCE_HOLD else 0
	var pressed := InputFrame.SHOOT if _frame == 0 else 0
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, held, pressed))
	_view.sync()
	_frame += 1
	if _frame == LANCE_HOLD:
		_charged = _vp.get_texture().get_image()
	if _frame < LANCE_HOLD + LANCE_AFTER:
		return false
	var flight := _vp.get_texture().get_image()
	var sheet := Image.create(SIZE.x * 2, SIZE.y, false, Image.FORMAT_RGB8)
	_charged.convert(Image.FORMAT_RGB8)
	flight.convert(Image.FORMAT_RGB8)
	sheet.blit_rect(_charged, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	sheet.blit_rect(flight, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x, 0))
	_save(sheet, "lance_%s.png" % _name(CANDIDATES[_k]))
	return _next()


func _save(img: Image, file: String) -> void:
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_dir + file)
	print("w3o7_shots: ", _dir + file)


func _next() -> bool:
	_k += 1
	if _k >= CANDIDATES.size():
		_k = 0
		_phase += 1
		if _phase > 1:
			CandidateLooks.bolt = CandidateLooks.BOLT
			CandidateLooks.lance = CandidateLooks.LANCE
			return true
	_build()
	return false
