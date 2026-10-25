extends SceneTree
## v0.9.0 VX V52 (VFX_AUDIT.md: "judged from the game camera", C84): one contact sheet per Gun form, its six element
## looks tiled (no element, Fire, Lightning / Frost, Venom, Bleed, left to right and top to bottom; a swatch of the
## element's colour in each tile's corner), plus one sheet of the patterns on the Orbs (Twin, Halo, Ring / Backfire,
## Spiral, Swirl, all with Fire), and the Wave's and the Wisps' sheets. Each tile is the real game view (WorldViewRoot
## on the Ruins stage with its biome mood, the iso camera, the effects layer) of a real World with the data's Gun and
## cards, Shoot held among standing dummies, at Effects density Medium. Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx_shots.gd [-- --only=<sheet>]
##   [-- --cam=<size>]   (inspection: one sheet, a closer camera)
## Writes build/shots/<version>/vx/<n>_<sheet>.jpg (1280 x 720) and prints each path and each tile's effect-pool counts.
## Frames are grabbed in _process.

const ELEMENTS: Array[StringName] = [
	&"", &"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]
const SWATCH := [&"", &"ember", &"storm", &"frost", &"venom", &"bleed"]
## [sheet, the form's cards, ticks of Shoot before the grab, the tick Shoot is let go (-1: held), camera size].
const SHEETS := [
	["orbs", [], 20, -1, 7.0],
	["laser", [&"gun_laser"], 20, -1, 7.0],
	["bomb", [&"gun_bomb"], 25, -1, 7.5],
	["void", [&"gun_void"], 34, -1, 7.5],
	["lance", [&"gun_lance"], 80, 74, 7.0],
	["scatter", [&"gun_scatter"], 5, -1, 6.0],
	["glaive", [&"gun_glaive"], 16, -1, 7.0],
	["seekers", [&"gun_seekers"], 16, -1, 7.0],
	["patterns", [], 18, -1, 8.0],
	["wave", [&"gun_wave"], 22, -1, 7.5],
	["wisps", [&"gun_wisps"], 46, -1, 6.5],
]
## The patterns sheet's tiles (each with Fire): its cards in place of the element.
const PATTERNS := [
	[&"gun_twin"], [&"halo_shot"], [&"gun_ring"], [&"gun_backfire"], [&"gun_spiral"], [&"gun_swirl"]
]
const SHEET := Vector2i(1280, 720)
const TILE := Vector2i(426, 360)
## Each tile renders at twice its size, then halves.
const RENDER := Vector2i(852, 720)
const DUMMIES: Array[Vector2] = [
	Vector2(4.5, 0.0), Vector2(3.2, 1.4), Vector2(3.6, -1.6), Vector2(6.0, 1.2), Vector2(6.5, -1.0)
]

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _reader: WorldReader
var _sheet_k := 0
var _tile_k := 0
var _ticks := 0
var _settle := -1
var _dir := ""
## Inspection (-- --only=<sheet> --cam=<size>): one sheet only, the camera this close (default: every sheet, its size).
var _only := ""
var _cam := 0.0
var _sheet: Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.trim_prefix("--only=")
		elif a.begins_with("--cam="):
			_cam = float(a.trim_prefix("--cam="))
	while _only != "" and SHEETS[_sheet_k][0] != _only:
		_sheet_k += 1
	_dir = "res://build/shots/%s/vx/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "medium"
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	_vp = SubViewport.new()
	_vp.size = RENDER
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_new_sheet()
	_build()


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	return -1


func _new_sheet() -> void:
	_sheet = Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _cards() -> Array:
	var spec: Array = SHEETS[_sheet_k]
	var out: Array = (spec[1] as Array).duplicate()
	if spec[0] == "patterns":
		out.append_array(PATTERNS[_tile_k])
		out.append(&"ember_core")
	elif ELEMENTS[_tile_k] != &"":
		out.append(ELEMENTS[_tile_k])
	return out


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = SHEETS[_sheet_k]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	for id: StringName in _cards():
		_world.add_item(_item(id))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	for at in DUMMIES:
		_world.add_dummy(at, 0.35, 1 << 20)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the game's lit look and its effects layer, as main.gd sets it
	_view.setup(_reader, biome.palette, 14.0)
	var cam: float = _cam if _cam > 0.0 else spec[4]
	_view.rig.view_size = cam
	_view.rig.camera.size = cam
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.8, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = SHEETS[_sheet_k]
	if _settle < 0:
		var held := InputFrame.SHOOT
		if int(spec[3]) >= 0 and _ticks >= int(spec[3]):
			held = 0  # the Lance fires on the release
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, held, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= int(spec[2]):
			_settle = 0
		return false
	_settle += 1
	if _settle < 3:
		return false
	_grab()
	_tile_k += 1
	if _tile_k >= 6:
		var path := _dir + "%d_%s.jpg" % [_sheet_k + 1, spec[0]]
		_sheet.save_jpg(path, 0.9)
		print("vx_shots: ", path)
		_sheet_k += 1
		_tile_k = 0
		if _sheet_k >= SHEETS.size() or _only != "":
			return true
		_new_sheet()
	_build()
	return false


## The frame, halved into its tile, with its element's swatch in the corner.
func _grab() -> void:
	var fx := _view.attack_forms.vfx
	if fx != null:
		print(
			(
				"vx_shots: tile %s %d: glow %d ember %d flame %d splash %d ice %d bubble %d, live %d"
				% [
					SHEETS[_sheet_k][0],
					_tile_k,
					fx.used(&"glow"),
					fx.used(&"ember"),
					fx.used(&"flame"),
					fx.used(&"splash"),
					fx.used(&"ice"),
					fx.used(&"bubble"),
					_view.attack_forms.live_count()
				]
			)
		)
	else:
		print("vx_shots: no effects layer")
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	var at := Vector2i((_tile_k % 3) * (TILE.x + 1), (_tile_k / 3) * TILE.y)
	_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), at)
	var e: StringName = SWATCH[_tile_k] if SHEETS[_sheet_k][0] != "patterns" else &"ember"
	var c := ElementLooks.core(e) if e != &"" else ElementLooks.DEFAULT_CORE
	_sheet.fill_rect(Rect2i(at + Vector2i(6, 6), Vector2i(36, 8)), c)
	_sheet.fill_rect(Rect2i(at + Vector2i(6, 14), Vector2i(36, 4)), ElementLooks.hot(e))
