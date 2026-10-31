extends SceneTree
## v0.10.0 VX7 (VFX_PACK "Gaps built in the pack's style"): the bleed status, the void rift, the void shot's sparks, the
## Glaive disc, the Wave, the Nemesis crescent, the Tidecaller's water and the lasting floor marks, old on the left and
## in the pack's style on the right. Each tile is the real game view (WorldViewRoot, the Ruins palette) of a real World
## at Effects density High, 640 x 360. Four sheets (rows of old | new): bleed_void, forms, water, marks. A tool, not a
## test. Needs a renderer (no --headless) and a fixed frame time:
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720
##     -s scripts/shots/vx7_gaps.gd
## Writes build/shots/v0.10.0/vx7/<sheet>.png and prints each path.

const W := preload("res://tests/support/mx4_world.gd")
const TILE := Vector2i(640, 360)
const SHEETS := [
	{"name": "bleed_void", "rows": [&"bleed", &"void_patch", &"void_shot"]},
	{"name": "forms", "rows": [&"glaive", &"wave", &"crescent"]},
	{"name": "water", "rows": [&"tide_pull", &"tide_push"]},
	{"name": "marks", "rows": [&"marks_fresh", &"marks_fade"]},
]
const GRAB := 64
## Frames the sim waits at the start: PackFx's warm-up fills its pools for a few frames (behind the loading cover in the
## game), and a held effect asked for then would be refused.
const WARM := 10
const BIOME := &"ruins"

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _sheet_k := 0
var _row_k := 0
var _new := false
var _frame := 0
var _sheet: Image
var _dir := ""
var _tile := &""
var _boss := -1


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx7/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_new_sheet()
	_build()


func _new_sheet() -> void:
	var rows: Array = SHEETS[_sheet_k]["rows"]
	_sheet = Image.create(TILE.x * 2, TILE.y * rows.size(), false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _stage_world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	var w := StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	w.dummy_speed = 0.0
	return w


## The world a tile plays in, and the camera (centre on the floor, ortho size).
func _make_world() -> Array:
	_boss = -1
	match _tile:
		&"glaive":
			return [
				W.world(&"gun", [&"gun_glaive"], [[Vector2(7.0, 0.0), 1000000]]),
				Vector2(2.5, 0.0),
				6.0
			]
		&"wave":
			return [
				W.world(&"gun", [&"gun_wave"], [[Vector2(7.0, 0.0), 1000000]]),
				Vector2(2.5, 0.0),
				6.0
			]
		&"void_shot":
			return [
				W.world(&"gun", [&"gun_void"], [[Vector2(9.0, 0.0), 1000000]]),
				Vector2(3.0, 0.0),
				6.0
			]
		&"crescent":
			return [CombatLab.world(), Vector2(2.0, 0.0), 5.0]
		&"tide_pull", &"tide_push":
			var w := BossLab.world()
			_boss = BossLab.ready_boss(w, &"tidecaller")
			var t := BossAi.table_of(w, _boss)
			for k in t.phase_attacks.size():
				t.phase_attacks[k] = PackedInt32Array()
			t.sig_every_ticks = 0
			t.punish_ticks = 0
			w.actors.set_pos(0, Vector2(-9, 0))
			return [w, Vector2(0.0, 0.0), 15.0]
	return [_stage_world(), Vector2(0.0, 0.0), 5.0]


func _build() -> void:
	if _view != null:
		_view.queue_free()
	_tile = SHEETS[_sheet_k]["rows"][_row_k]
	var made := _make_world()
	_world = made[0]
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", BIOME)
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	var size: float = made[2]
	_view.rig.view_size = size
	_view.rig.camera.size = size
	_view.rig.snap_to(SimPlane.to_3d(made[1]))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := _view.attack_forms.vfx
	if not _new:
		layer.pack_fx = null
		_view.pack_fx = null  # (the views find the pack through their parent)
		_unpack_views()
		if _tile == &"void_shot":  # the sparks need room in the hit family: fill it, off screen
			var fx := PackFx.new()
			_view.add_child(fx)
			for k in fx.cap_for(&"hit"):
				fx.spawn(&"vx7_void_spark", Vector3(0, -80, 0), 1.0, {}, 0.0)
			_view.voids.set("pack_fx", fx)
	layer.drawers.append(_draw.bind(layer))
	_frame = 0
	_setup_tile(layer)


## The old look of the views that took the pack at the world's first sync: no pack, the crest back to its shader.
func _unpack_views() -> void:
	_view.glaives.ring_hold.clear()
	_view.glaives.pack_fx = null
	var waves := _view.waves
	waves.wash_hold.clear()
	waves.pack_fx = null
	var crests: Array = waves.get("_crests")
	var mats: Array = waves.get("_crest_mat")
	for k in crests.size():
		(crests[k] as MeshInstance3D).mesh = WaveView.crest_mesh()
		(crests[k] as MeshInstance3D).material_override = mats[k]
	waves.crest_packed = true  # (nothing to wear: no pack)
	_view.tides.water_hold.clear()
	_view.tides.pack_fx = null


func _setup_tile(layer: VfxLayer) -> void:
	match _tile:
		&"bleed":
			for k in 3:
				var cap := MeshInstance3D.new()
				var mesh := CapsuleMesh.new()
				mesh.radius = 0.35
				mesh.height = 1.0
				cap.mesh = mesh
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.25, 0.22, 0.26)
				cap.material_override = m
				cap.position = SimPlane.to_3d(Vector2(-1.8 + 1.8 * k, 0.0), 0.5)
				_view.add_child(cap)
		&"tide_push":
			BossLab.start(_world, _boss, &"the_pull")
		&"tide_pull":
			BossLab.start(_world, _boss, &"the_pull")
	if _tile == &"marks_fresh" or _tile == &"marks_fade":
		layer.clear_marks()


## The effects layer's drawer for the tile, once a frame.
func _draw(_core: VfxCore, fx: VfxLayer) -> void:
	match _tile:
		&"bleed":
			for k in 3:
				fx.status(
					SimPlane.to_3d(Vector2(-1.8 + 1.8 * k, 0.0), 0.0),
					0.35,
					{&"bleed": 1 + k * 3},
					11 + k,
					1.0
				)
		&"void_patch":
			fx.field(&"void", SimPlane.to_3d(Vector2(-1.8, 0.0), 0.0), 1.8, 1.0, float(_frame), 5)
			if _frame > 20 and _frame < 70:
				fx.burst(
					&"void",
					SimPlane.to_3d(Vector2(1.8, 0.0), 0.0),
					1.6,
					float(_frame - 20) / 50.0,
					6
				)
		&"marks_fresh", &"marks_fade":
			var at := _frame < 2
			fx.mark(1, &"scorch", SimPlane.to_3d(Vector2(-2.2, 0.0), 0.0), 1.1, VfxLayer.SCORCH)
			fx.mark(2, &"frost", SimPlane.to_3d(Vector2(0.0, 0.0), 0.0), 1.2, VfxLayer.FROST_MARK)
			fx.mark(3, &"splat0", SimPlane.to_3d(Vector2(2.2, 0.0), 0.0), 1.0, VfxLayer.BLOOD_MARK)
			if at and _tile == &"marks_fade":
				pass


func _ready() -> bool:
	if _frame >= 500:
		return true
	if _tile == &"tide_pull":
		return _frame >= 120 and _view.tides.strength() > 0.5
	if _tile == &"tide_push":
		return (
			_frame >= 120
			and _view.tides.flow() < -0.5
			and _view.tides.get("_swell_t") > 0.2
			and _view.tides.get("_swell_t") < 0.5
		)
	return _frame >= GRAB or _frame >= 900


func _process(_delta: float) -> bool:
	if _frame < WARM:
		_frame += 1
		return false
	match _tile:
		&"glaive", &"wave", &"void_shot":
			W.run(_world, 1, 0, W.S)
		&"crescent":
			if _frame % 18 == 0:
				_world.projectiles.add(
					900 + _frame,
					-1,
					1,
					Vector2(-1.0 + float(_frame) * 0.02, 0.0),
					Vector2(0.07, 0.0),
					0.18,
					600
				)
				_world.projectiles.set_look(_world.projectiles.ids.size() - 1, &"nemesis_crescent")
			_world.step(InputFrame.new())
		_:
			_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	if _tile == &"marks_fade" and _frame == 4:
		var layer := _view.attack_forms.vfx
		for s: Array in layer.get("_marks"):
			s[4] = float(s[4]) - (VfxCore.MARK_TICKS - 45.0)  # near the end of its life: the fade
	_view.sync()
	_frame += 1
	if not _ready():
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_sheet.blit_rect(
		img, Rect2i(Vector2i.ZERO, TILE), Vector2i((1 if _new else 0) * TILE.x, _row_k * TILE.y)
	)
	if not _new:
		_new = true
	else:
		_new = false
		_row_k += 1
		var rows: Array = SHEETS[_sheet_k]["rows"]
		if _row_k >= rows.size():
			var path := _dir + "%s.png" % SHEETS[_sheet_k]["name"]
			_sheet.save_png(path)
			print("vx7_gaps: ", path)
			_row_k = 0
			_sheet_k += 1
			if _sheet_k >= SHEETS.size():
				return true
			_new_sheet()
	_build()
	return false
