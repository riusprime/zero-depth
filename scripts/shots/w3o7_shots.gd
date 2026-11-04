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
## v0.10.5 W3-O7b (round 2; the owner: "comparisons with new assets from the premade pack"): with `-- --round2`, only
## the purple bolts, every candidate (now, a-g), into build/shots/v0.10.5/w3o7b/, then bolt_compare.png: each shot's
## middle (COMPARE_CROP) in a labelled grid.

const CANDIDATES: Array[StringName] = [&"", &"a", &"b", &"c"]
const ROUND2: Array[StringName] = [&"", &"a", &"b", &"c", &"d", &"e", &"f", &"g"]
## The part of a bolt shot the contact sheet keeps (the five shots and the floor round them), and its grid.
const COMPARE_CROP := Rect2i(100, 30, 840, 500)
const COMPARE_COLS := 4
const COMPARE_LABEL_H := 44
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
var _cands: Array[StringName] = CANDIDATES
var _round2 := false
var _shots: Array[Image] = []
var _sheet: SubViewport


func _initialize() -> void:
	_round2 = OS.get_cmdline_user_args().has("--round2")
	if _round2:
		_cands = ROUND2
		_dir = "res://build/shots/v0.10.5/w3o7b/"
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
	CandidateLooks.bolt = _cands[_k] if _phase == 0 else CandidateLooks.BOLT
	CandidateLooks.lance = _cands[_k] if _phase == 1 else CandidateLooks.LANCE
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
	if _sheet != null:
		return _save_sheet()
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
	var img := _vp.get_texture().get_image()
	_save(img, "bolt_%s.png" % _name(_cands[_k]))
	_shots.append(img)
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
	_save(sheet, "lance_%s.png" % _name(_cands[_k]))
	return _next()


func _save(img: Image, file: String) -> void:
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_dir + file)
	print("w3o7_shots: ", _dir + file)


func _next() -> bool:
	_k += 1
	if _k >= _cands.size():
		_k = 0
		_phase += 1
		if _round2 and _phase == 1:
			_view.queue_free()
			_view = null
			_build_sheet()
			return false
		if _phase > 1:
			CandidateLooks.bolt = CandidateLooks.BOLT
			CandidateLooks.lance = CandidateLooks.LANCE
			return true
	_build()
	return false


## Round 2's contact sheet: each bolt shot's middle, labelled with its candidate, in a grid (a viewport of
## TextureRects and Labels, saved two frames later by _save_sheet).
func _build_sheet() -> void:
	var cell := COMPARE_CROP.size + Vector2i(0, COMPARE_LABEL_H)
	var rows := ceili(float(_shots.size()) / COMPARE_COLS)
	_sheet = SubViewport.new()
	_sheet.size = Vector2i(cell.x * COMPARE_COLS, cell.y * rows)
	_sheet.transparent_bg = false
	_sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sheet)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.size = Vector2(_sheet.size)
	_sheet.add_child(bg)
	for n in _shots.size():
		var at := Vector2i((n % COMPARE_COLS) * cell.x, (n / COMPARE_COLS) * cell.y)
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(_shots[n].get_region(COMPARE_CROP))
		rect.position = Vector2(at + Vector2i(0, COMPARE_LABEL_H))
		_sheet.add_child(rect)
		var label := Label.new()
		label.text = "  %s" % _label(_cands[n])
		label.position = Vector2(at)
		label.size = Vector2(cell.x, COMPARE_LABEL_H)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color.WHITE)
		_sheet.add_child(label)
	_frame = 0


static func _label(c: StringName) -> String:
	const NAMES := {
		&"": "now: mprojectile_basic_vfx_03",
		&"a": "A: violet fireball (tinted fire_ball_04)",
		&"b": "B: javelin (mprojectile_javelin_vfx_03)",
		&"c": "C: flare orb (magic_orb_flare_vfx_03)",
		&"d": "D: ice shard (ice_shard_vfx_02)",
		&"e": "E: ice ball (ice_ball_vfx_01)",
		&"f": "F: wave (mprojectile_wave_vfx_03)",
		&"g": "G: poison bubble (poison_bubble_vfx_01)",
	}
	return NAMES.get(c, String(c))


func _save_sheet() -> bool:
	_frame += 1
	if _frame < 3:
		return false
	_save(_sheet.get_texture().get_image(), "bolt_compare.png")
	CandidateLooks.bolt = CandidateLooks.BOLT
	CandidateLooks.lance = CandidateLooks.LANCE
	return true
