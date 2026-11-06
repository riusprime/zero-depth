extends SceneTree
## v0.10.0 VX2 (VFX_PACK R1-R13): the hero's shots and forms before (the old looks: the views' pack handed back) and
## after (the pack's effects), side by side. Each tile pair is the real game view (WorldViewRoot on the Ruins stage with
## its mood, the iso camera, the effects layer) of a real World with the data's Gun and cards, Shoot held among standing
## dummies, at Effects density High; the old tile is on the left of each pair, the new one on its right, with the
## element's swatch in the corner. Three sheets of eight pairs (1920 x 1080): the Orbs per element and the Seekers, the
## Seekers, Wisps and Laser, and the Lance, Void, Rune Explosion and the spec forms (a Ring, the orbit blades, a bomb,
## a trigger's cast). A tool, not a test. Needs a renderer (no --headless) and a fixed frame time:
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx2_forms.gd
##   [-- --only=<sheet 1-3>] [-- --cam=<size>]  (inspection: one sheet, a closer camera)
## Writes build/shots/v0.10.0/vx2/<n>_<name>.png and prints each path and each new tile's pack counts.

const ELEMENT_CARDS := {
	&"": &"",
	&"ember": &"ember_core",
	&"storm": &"storm_core",
	&"frost": &"frost_core",
	&"venom": &"venom_core",
	&"bleed": &"shared_bleed",
}
## [sheet name, form cards, element, ticks of Shoot before the grab, the tick Shoot is let go (-1: held), camera size].
const TILES := [
	["orbs", [], &"", 20, -1, 5.0],
	["orbs", [], &"ember", 20, -1, 5.0],
	["orbs", [], &"storm", 20, -1, 5.0],
	["orbs", [], &"frost", 20, -1, 5.0],
	["orbs", [], &"venom", 20, -1, 5.0],
	["orbs", [], &"bleed", 20, -1, 5.0],
	["seekers", [&"gun_seekers"], &"", 16, -1, 5.0],
	["seekers", [&"gun_seekers"], &"ember", 16, -1, 5.0],
	["seekers", [&"gun_seekers"], &"venom", 16, -1, 5.0],
	["wisps", [&"gun_wisps"], &"", 46, -1, 4.5],
	["wisps", [&"gun_wisps"], &"ember", 46, -1, 4.5],
	["wisps", [&"gun_wisps"], &"frost", 46, -1, 4.5],
	["laser", [&"gun_laser"], &"", 20, -1, 6.0],
	["laser", [&"gun_laser"], &"ember", 20, -1, 6.0],
	["laser", [&"gun_laser"], &"venom", 20, -1, 6.0],
	["laser", [&"gun_laser"], &"frost", 20, -1, 6.0],
	["lance", [&"gun_lance"], &"", 80, 74, 6.0],
	["lance", [&"gun_lance"], &"ember", 80, 74, 6.0],
	["void", [&"gun_void"], &"", 34, -1, 6.0],
	["rune", [&"gun_rune_explosion"], &"", 22, -1, 6.0],
	["ring", [&"gun_ring"], &"", 22, -1, 6.0],
	["orbiter", [&"blade_orbit"], &"", 30, -1, 6.0],
	["bomb", [&"bomb_rounds"], &"", 26, -1, 6.0],
	["trigger", [&"trigger_on_hit"], &"", 30, -1, 6.0],
]
const NAMES := ["orbs_seekers", "seekers_wisps_laser", "lance_void_rune_forms"]
const PAIRS_PER_SHEET := 8
const SHEET := Vector2i(1920, 1080)
const TILE := Vector2i(480, 270)
## Each tile renders at twice its size, then halves.
const RENDER := Vector2i(960, 540)
const DUMMIES: Array[Vector2] = [
	Vector2(4.5, 0.0), Vector2(3.2, 1.4), Vector2(3.6, -1.6), Vector2(6.0, 1.2), Vector2(6.5, -1.0)
]

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _tile_k := 0
var _after := false
var _ticks := 0
var _settle := -1
var _dir := ""
var _only := 0
var _cam := 0.0
var _sheet: Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = int(a.trim_prefix("--only="))
		elif a.begins_with("--cam="):
			_cam = float(a.trim_prefix("--cam="))
	if _only > 0:
		_tile_k = (_only - 1) * PAIRS_PER_SHEET
	_dir = "res://build/shots/v0.10.0/vx2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
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


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = TILES[_tile_k]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	var cards: Array = (spec[1] as Array).duplicate()
	if ELEMENT_CARDS[spec[2]] != &"":
		cards.append(ELEMENT_CARDS[spec[2]])
	for id: StringName in cards:
		_world.add_item(_item(id))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	for at in DUMMIES:
		_world.add_dummy(at, 0.35, 1 << 20)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	if not _after:  # the old looks: the views are handed no pack
		for v: Object in [
			_view.pulses,
			_view.attack_forms,
			_view.laser,
			_view.lances,
			_view.voids,
			_view.runes,
			_view.seekers,
		]:
			v.set("pack_fx", null)
		_view.attack_forms.pulse_hold = null
	var cam: float = _cam if _cam > 0.0 else float(spec[5])
	_view.rig.view_size = cam
	_view.rig.camera.size = cam
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.6, 0.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


func _process(_delta: float) -> bool:
	var spec: Array = TILES[_tile_k]
	if _settle < 0:
		var held := InputFrame.SHOOT
		if int(spec[4]) >= 0 and _ticks >= int(spec[4]):
			held = 0  # the Lance fires on the release
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, held, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= int(spec[3]):
			_settle = 0
		return false
	_settle += 1
	if _settle < 3:
		return false
	_grab()
	if not _after:
		_after = true
		_build()
		return false
	_after = false
	_tile_k += 1
	var in_sheet := _tile_k % PAIRS_PER_SHEET
	if in_sheet == 0 or _tile_k >= TILES.size():
		var n := (_tile_k - 1) / PAIRS_PER_SHEET
		var path := _dir + "%d_%s.png" % [n + 1, NAMES[n]]
		_sheet.save_png(path)
		print("vx2_forms: ", path)
		if _tile_k >= TILES.size() or _only > 0:
			return true
		_new_sheet()
	_build()
	return false


## The frame, halved into its tile, the element's swatch in the corner.
func _grab() -> void:
	var spec: Array = TILES[_tile_k]
	if _after and _view.pulses.pack_fx != null:
		var pf: PackFx = _view.pulses.pack_fx
		print(
			(
				"vx2_forms: %s %s live %d (projectile %d beam %d area %d hit %d) spawned %d"
				% [
					spec[0],
					spec[2],
					pf.live_count(),
					pf.live_count(&"projectile"),
					pf.live_count(&"beam"),
					pf.live_count(&"area"),
					pf.live_count(&"hit"),
					pf.spawned
				]
			)
		)
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	var p := _tile_k % PAIRS_PER_SHEET
	var at := Vector2i((p % 2) * 2 * TILE.x + (TILE.x if _after else 0), (p / 2) * TILE.y)
	_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), at)
	var e: StringName = spec[2]
	var c := ElementLooks.core(e) if e != &"" else ElementLooks.DEFAULT_CORE
	_sheet.fill_rect(Rect2i(at + Vector2i(6, 6), Vector2i(36, 8)), c)
	_sheet.fill_rect(Rect2i(at + Vector2i(6, 14), Vector2i(36, 4)), ElementLooks.hot(e))
