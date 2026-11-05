extends SceneTree
## v0.10.0 VX3 (VFX_PACK R19-R26, R28-R30, R41): the zones, the statuses on an enemy and the element bursts before (the
## sprite looks) and after (the pack's), from the game camera. Three sheets, each with the sprite look on top and the
## pack's below, each tile the real game view (WorldViewRoot, the ruins' mood, the effects layer), Effects density High:
## - zones.png: a fire patch (the hero's, then an enemy's), frost, venom and bleed patches; rings: fire, frost,
##   venom, bleed and Ember Ward's (the next row). Thin green rings mark the patch radius (1.2 m) and the ring radius.
## - status.png: capsules (a 0.9 m body) with burn (three enemies, three flame scenes), poison, frost, frozen and the
##   player's guard orbs.
## - bursts.png: a frost burst, a shatter, a venom burst, a bleed burst and Wildfire (a thin green ring marks 1.5 m).
## A tool, not a test. Needs a renderer (no --headless) and a fixed frame time:
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx3_zones.gd
## Writes build/shots/v0.10.0/vx3/<sheet>.png and prints each path.

const SHEETS: Array[StringName] = [&"zones", &"status", &"bursts"]
const TILE := Vector2i(1280, 540)
## The camera's height in metres per sheet.
const VIEW := {&"zones": 5.5, &"status": 3.8, &"bursts": 5.5}
const SEED := 4242
## Grab frame per sheet (60 per second).
const GRAB := {&"zones": 110, &"status": 90, &"bursts": 20}
## Across the screen, and down it, on the ground (the iso camera looks along a diagonal).
const ACROSS := Vector2(0.7071, 0.7071)
const DOWN := Vector2(0.7071, -0.7071)
const SPACING := {&"zones": 2.6, &"status": 1.1, &"bursts": 3.0}
const COUNT := {&"zones": 5, &"status": 7, &"bursts": 5}
const BURST_START := 3
const BURST_FRAMES := 45.0
const RADIUS := 1.2
const BURST_R := 1.5

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _sheet_k := 0
var _after := false
var _frame := 0
var _sheet: Image
var _dir := ""
var _layer: VfxLayer


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx3/"
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
	_sheet = Image.create(TILE.x, TILE.y * 2, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2(0, 7))  # (the hero stands out of the frame)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = float(VIEW[SHEETS[_sheet_k]])
	_view.rig.camera.size = float(VIEW[SHEETS[_sheet_k]])
	_view.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_layer = _view.attack_forms.vfx
	if not _after:
		_layer.pack_fx = null  # the sprite looks
		_view.element_fx.pack_fx = null
	_layer.drawers.append(_draw_sheet)
	var sheet := SHEETS[_sheet_k]
	if sheet == &"zones":
		for k in 5:
			_marker_ring(_pos(k, -1.2), RADIUS)
			_marker_ring(_pos(k, 1.6), 1.0)
	elif sheet == &"bursts":
		for k in 5:
			_marker_ring(_pos(k, 0.0), BURST_R)
	else:
		for k in 7:
			_body(_pos(k, 0.0))
	_frame = 0


func _marker_ring(at: Vector2, r: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.015
	torus.outer_radius = r + 0.015
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.3)
	ring.material_override = mat
	ring.position = SimPlane.to_3d(at, 0.04)
	_view.add_child(ring)


## A grey 0.9 m body the statuses sit on.
func _body(at: Vector2) -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 0.9
	body.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.5)
	body.material_override = mat
	body.position = SimPlane.to_3d(at, 0.45)
	_view.add_child(body)


## Item `k` of the sheet's row, `row` metres down the screen.
func _pos(k: int, row: float) -> Vector2:
	var sheet := SHEETS[_sheet_k]
	var across := (float(k) - (int(COUNT[sheet]) - 1) * 0.5) * float(SPACING[sheet])
	return ACROSS * across + DOWN * row


func _at(k: int, row: float) -> Vector3:
	return SimPlane.to_3d(_pos(k, row), 0.0)


func _draw_sheet(_core: VfxCore) -> void:
	if _sheet_k >= SHEETS.size():
		return
	match SHEETS[_sheet_k]:
		&"zones":
			_draw_zones()
		&"status":
			_draw_status()
		&"bursts":
			_draw_bursts()


func _draw_zones() -> void:
	var age := float(_frame)
	var kinds: Array[StringName] = [&"fire", &"fire", &"frost", &"venom", &"bleed"]
	for k in kinds.size():
		var hostile := k == 1
		_layer.field(kinds[k], _at(k, -1.2), RADIUS, 1.0, age, SEED + k, hostile)
	var rings: Array[StringName] = [&"fire", &"frost", &"venom", &"bleed"]
	for k in rings.size():
		_layer.ring(rings[k], _at(k, 1.6), 1.0, 1.0, age, SEED + 10 + k)
	# Ember Ward's ring (ElementVisuals): played again every 50 frames
	if _frame % 50 == 2:
		var ward := _pos(4, 1.6)
		if _view.element_fx.pack_fx != null:  # the old look's WARD_COLOR is gone (the pack draws the ward)
			_view.element_fx._pack_ring(ward, 1.0, &"ring_fire", &"fire")


func _draw_status() -> void:
	var ons: Array[Dictionary] = [
		{&"burn": 3},
		{&"burn": 3},
		{&"burn": 3},
		{&"poison": 3},
		{&"frost": 3},
		{&"frozen": 1, &"frost": 3},
		{&"guard": 3},
	]
	for k in ons.size():
		_layer.status(_at(k, 0.0), 0.35, ons[k], k + 1, 0.9)


func _draw_bursts() -> void:
	if _frame < BURST_START or _frame >= BURST_START + BURST_FRAMES:
		return
	var u := (_frame - BURST_START) / BURST_FRAMES
	var kinds: Array[StringName] = [&"frost", &"shatter", &"venom", &"bleed", &"wildfire"]
	for k in kinds.size():
		_layer.burst(kinds[k], _at(k, 0.0), BURST_R, u, SEED + k * 100)


func _process(_delta: float) -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	_view.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))
	_view.sync()
	_frame += 1
	var sheet := SHEETS[_sheet_k]
	if _frame == int(GRAB[sheet]) + 3:
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		_sheet.blit_rect(
			img, Rect2i(Vector2i.ZERO, TILE), Vector2i(0, (1 if _after else 0) * TILE.y)
		)
	if _frame < int(GRAB[sheet]) + 4:
		return false
	if not _after:
		_after = true
	else:
		var path := _dir + "%s.png" % sheet
		_sheet.save_png(path)
		print("vx3_zones: ", path)
		_after = false
		_sheet_k += 1
		if _sheet_k >= SHEETS.size():
			return true
		_new_sheet()
	_build()
	return false
