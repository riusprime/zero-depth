extends SceneTree
## Renders the three bosses (v0.3.0 C) for the owner. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/bosses.gd -- mode=sheet
##   ... -s scripts/shots/bosses.gd -- mode=compare
## Writes build/shots/<version>/bosses/ and prints each path. Frames are grabbed in _process.
## sheet: the real game view (WorldViewRoot: the Ruins stage, the iso camera, ActorViews, TelegraphViews) of a real
## World with each boss: idle (pursuing), then two of its attacks mid-windup with their telegraphs, a 3 x 3 grid.
## compare: each boss model alone in the sheet's three views (FRONT, RIGHT-FRONT, RIGHT) from a low camera, plus
## an iso inset with the player for scale, under the matching row of docs/art/first-three-bosses-concept.png.

const BOSSES: Array[StringName] = [&"gatekeeper", &"brood_mother", &"siege_engine"]
## Two attacks shown per boss in the sheet.
const SHOWN := {
	&"gatekeeper": [&"fist_slam", &"shock_lanes_5"],
	&"brood_mother": [&"leap", &"brood_4"],
	&"siege_engine": [&"barrage_7", &"rail_sweep"],
}
const CELL := Vector2i(560, 400)
const REF := "res://docs/art/first-three-bosses-concept.png"
## The sheet's rows (y from, height) and its figures' centres (x px), measured on the 1536 x 1024 sheet.
const REF_ROWS := [[0, 336], [338, 314], [654, 345]]
const REF_X := [530.0, 925.0, 1330.0]
const ROW := Vector2i(1536, 345)
## Views as the model's yaw (radians) under a camera looking down -Z: front, right-front, right.
const VIEW_YAW := [-PI * 0.5, -PI * 0.25, PI]
const VIEW_M := 4.5
const VIEW_PITCH := 14.0
const FEET_PX := 300.0

var _mode := "sheet"
var _dir := ""
var _frame := 0
var _vp: SubViewport
var _cells: Array[Image] = []
var _labels: Array[String] = []
# sheet
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _step := 0
var _plan: Array = []
# compare
var _boss_k := 0
var _scene: Node3D
var _inset_vp: SubViewport


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):
			_mode = arg.trim_prefix("mode=")
	_dir = "res://build/shots/%s/bosses/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	if _mode == "compare":
		_vp.size = ROW
		_inset_vp = SubViewport.new()
		_inset_vp.size = Vector2i(290, 197)
		_inset_vp.msaa_3d = Viewport.MSAA_4X
		_inset_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_inset_vp.own_world_3d = true
		root.add_child(_inset_vp)
		_build_compare(0)
	else:
		_vp.size = CELL
		for id in BOSSES:
			_plan.append([id, &"", "%s idle" % id])
			for a: StringName in SHOWN[id]:
				_plan.append([id, a, "%s %s" % [id, a]])
		_build_cell(0)


func _process(_delta: float) -> bool:
	_frame += 1
	if _mode == "compare":
		return _compare_process()
	return _sheet_process()


# --- sheet ------------------------------------------------------------------------------------------------------


func _build_cell(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = _plan[k]
	var player := PlayerTable.starting_values()
	_world = StageScenario.build(9, player, ContentCompiler.compile_enemies(_repo))
	_world.set_boss_tables(ContentCompiler.compile_bosses(_repo))
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == spec[0]:
			bk = j
	_world.actors.set_pos(0, Vector2(4.5, -3.0))
	var id := _world.spawn_boss(bk, Vector2(-1.0, 1.0))
	var i := _world.actors.index_of(id)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.cd[i] = 100000 if spec[1] == &"" else 0
	_world.actors.hp[0] = 100000
	if spec[1] != &"":
		BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(spec[1]))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.rig.view_size = 12.5
	_view.rig.camera.size = 12.5
	_view.rig.snap_to(SimPlane.to_3d(Vector2(1.5, -0.8)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_step = 0


func _sheet_process() -> bool:
	var spec: Array = _plan[_cells.size()]
	var i := -1
	for j in _world.actors.size():
		if BossAi.is_boss_kind(_world.actors.kinds[j]):
			i = j
	# Step the sim one tick per frame until the windup is about two thirds through (or 40 ticks for idle).
	var want := 40
	if spec[1] != &"" and i >= 0:
		var atk := BossAi.attack_of(_world, i)
		want = atk.windup_ticks * 2 / 3 if atk != null else 0
	if _step < want:
		_world.actors.set_pos(0, Vector2(4.5, -3.0))
		_world.step(InputFrame.make(Vector2i.ZERO, 2048 + 300, 300, 0, 0))
		_view.sync()
		_step += 1
		return false
	_step += 1
	if _step < want + 12:  # let frame-time animation settle
		return false
	_cells.append(_grab(_vp))
	_labels.append(spec[2])
	if _cells.size() == _plan.size():
		_write_sheet()
		return true
	_build_cell(_cells.size())
	return false


func _write_sheet() -> void:
	var cols := 3
	var out := Image.create(CELL.x * cols, CELL.y * _cells.size() / cols, false, Image.FORMAT_RGBA8)
	for k in _cells.size():
		out.blit_rect(
			_cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i(k % cols * CELL.x, k / cols * CELL.y)
		)
	var path := _dir + "bosses.png"
	out.save_png(path)
	print("bosses: ", path, " cells=", ", ".join(_labels))


# --- compare ----------------------------------------------------------------------------------------------------


func _env(scene: Node3D, bg: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9CEDA")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)


func _ground(scene: Node3D, c: Color) -> void:
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	g.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = c
	gm.roughness = 1.0
	g.material_override = gm
	scene.add_child(g)


func _boss_avatar(id: StringName) -> BossAvatar:
	var a: BossAvatar = (
		{
			&"gatekeeper": GatekeeperAvatar,
			&"brood_mother": BroodMotherAvatar,
			&"siege_engine": SiegeEngineAvatar,
		}[id]
		. new()
	)
	a.setup(Color("#1A1A22"))
	a.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
	return a


func _build_compare(k: int) -> void:
	for vp in [_vp, _inset_vp]:
		for c in vp.get_children():
			c.queue_free()
	var id := BOSSES[k]
	_scene = Node3D.new()
	_vp.add_child(_scene)
	_env(_scene, Color("#252931"))
	_ground(_scene, Color("#1C1F26"))
	var m_per_px := VIEW_M / ROW.y
	for v in 3:
		var a := _boss_avatar(id)
		a.position = Vector3((REF_X[v] - ROW.x * 0.5) * m_per_px, 0, 0)
		a.rotation = Vector3(0, VIEW_YAW[v], 0)
		_scene.add_child(a)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW_M
	cam.rotation_degrees = Vector3(-VIEW_PITCH, 0, 0)
	var below := (FEET_PX - ROW.y * 0.5) * m_per_px
	var aim := Vector3(0, below / cos(deg_to_rad(VIEW_PITCH)), 0)
	cam.position = aim + cam.transform.basis.z * 30.0
	_scene.add_child(cam)
	cam.current = true
	# The iso inset: the boss and the player on sand, from the game's camera.
	var inset := Node3D.new()
	_inset_vp.add_child(inset)
	_env(inset, Color("#C8A57A"))
	_ground(inset, Color("#C8A57A"))
	var b := _boss_avatar(id)
	b.rotation = Vector3(0, -0.62, 0)  # facing the player
	inset.add_child(b)
	var p := PlayerAvatar.new()
	p.setup(Color("#1A1A22"))
	p.position = Vector3(4.2, 0, 3.0)
	inset.add_child(p)
	var rig := IsoRig.new()
	rig.set_process(false)
	inset.add_child(rig)
	rig.view_size = 6.0
	rig.camera.size = 6.0
	rig.snap_to(Vector3(1.6, 0.8, 1.2))
	rig.camera.current = true


func _compare_process() -> bool:
	if _frame % 40 != 0:
		return false
	var id := BOSSES[_boss_k]
	var ours := _grab(_vp)
	ours.blit_rect(_grab(_inset_vp), Rect2i(0, 0, 290, 197), Vector2i(37, 90))
	var ref := Image.new()
	if ref.load(ProjectSettings.globalize_path(REF)) != OK:
		print("bosses: reference NOT FOUND at ", REF)
		return true
	ref.convert(Image.FORMAT_RGBA8)
	var r: Array = REF_ROWS[_boss_k]
	var crop := ref.get_region(Rect2i(0, r[0], ref.get_width(), r[1]))
	var out := Image.create(ROW.x, r[1] + ROW.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i.ZERO)
	out.blit_rect(ours, Rect2i(Vector2i.ZERO, ROW), Vector2i(0, r[1]))
	var path := _dir + "boss_%s_compare.png" % id
	out.save_png(path)
	print("bosses: ", path)
	_boss_k += 1
	if _boss_k >= BOSSES.size():
		return true
	_build_compare(_boss_k)
	return false


func _grab(vp: SubViewport) -> Image:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
