extends SceneTree
## Renders the four melee combo steps (v0.3.0 L11) as a 2x2 contact sheet: the wanderer, the laser blade and its
## trail at the end of each step's sweep, with the step's hit arc (WorldReader.swing_shape, the shape PlayerKit hits
## with) drawn faintly on the ground. Each cell runs its own sim World: the earlier steps are chained headless, then
## the step is pressed and stepped once per physics tick (the blade and trail sync from WorldReader as in the game).
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/four_slashes.gd
## Writes build/shots/<version>/four_slashes/four_slashes.png and prints the steps' compiled numbers.

const CELL := Vector2i(800, 450)
## Sim aim angle that faces screen right under IsoRig's 45° yaw.
const AIM := 512
const VIEW_M := 5.6
const SETTLE_FRAMES := 6
const NAMES := [
	"1  slash, right to left",
	"2  backhand, left to right",
	"3  thrust (narrow, long, steps in)",
	"4  spinning finisher (360°, lunges)",
]

var _cells: Array = []  # [viewport, world, reader, kit, avatar, capture tick, done]
var _settle := 0
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/four_slashes/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var table := PlayerTable.starting_values()
	print(
		"STEP| step motion ticks active recovery half_arc_units arc_deg reach_m damage hitstop lunge_m sweep"
	)
	for k in table.combo.size():
		var s := table.step(k)
		print(
			(
				"STEP| %d %d %d %d %d %d %.1f %.2f %d %d %.2f %d"
				% [
					k + 1,
					s.motion,
					s.ticks,
					s.active_tick,
					s.recovery_ticks(),
					s.half_arc,
					s.half_arc * 720.0 / 4096.0,
					s.reach_m,
					s.damage,
					s.hitstop_ticks,
					s.lunge_m,
					s.sweep_ticks,
				]
			)
		)
	for k in 4:
		_cells.append(_build_cell(k))


func _build_cell(step: int) -> Array:
	var vp := SubViewport.new()
	vp.size = CELL
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#252931")
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
	var light := DirectionalLight3D.new()  # StageView's light
	light.rotation_degrees = Vector3(-38, 168, 0)
	light.light_energy = 1.05
	light.light_color = Color(1, 0.98, 0.95)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.796, 0.678, 0.569)  # the Ruins ground
	gm.roughness = 1.0
	ground.material_override = gm
	scene.add_child(ground)
	# The sim: chain the earlier steps, then press this one.
	var w := World.new(3, PlayerTable.starting_values())
	for i in step:
		w.step(InputFrame.make(Vector2i.ZERO, AIM, 300, 0, InputFrame.PRIMARY))
		while w.swing_t > 0:
			w.step(InputFrame.make(Vector2i.ZERO, AIM, 300, 0, 0))
	var reader := WorldReader.new(w)
	var kit := KitView.new()
	scene.add_child(kit)
	var avatar := PlayerAvatar.new()
	avatar.setup(Color("#1A1A22"))
	scene.add_child(avatar)
	avatar.position = SimPlane.to_3d(w.player_pos(), 0.0)
	avatar.sync(reader)
	var rig := IsoRig.new()
	rig.set_process(false)
	scene.add_child(rig)
	rig.camera.current = true
	rig.view_size = VIEW_M
	rig.camera.size = VIEW_M
	rig.snap_to(SimPlane.to_3d(w.player_pos(), 0.0) + Vector3(0, 0.4, 0))
	w.step(InputFrame.make(Vector2i.ZERO, AIM, 300, 0, InputFrame.PRIMARY))
	var shape := reader.swing_shape(step)
	var fan := MeshInstance3D.new()
	fan.mesh = KitView.fan_mesh(shape[0], shape[2], shape[1])
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_color = Color(0.1, 0.12, 0.16, 0.16)
	fan.material_override = fm
	fan.position = SimPlane.to_3d(w.player_pos(), 0.02)
	fan.rotation = Vector3(0, SimPlane.yaw_of(AIM), 0)
	scene.add_child(fan)
	var label := Label.new()
	label.text = NAMES[step]
	label.position = Vector2(18, 12)
	label.add_theme_font_size_override(&"font_size", 26)
	label.add_theme_color_override(&"font_color", Color("#F2F2F2"))
	label.add_theme_color_override(&"font_outline_color", Color("#15161A"))
	label.add_theme_constant_override(&"outline_size", 6)
	vp.add_child(label)
	var capture := w.player.step(step).sweep_ticks
	return [vp, w, reader, kit, avatar, capture, false, fan]


func _physics_process(_delta: float) -> bool:
	for c: Array in _cells:
		var w: World = c[1]
		var reader: WorldReader = c[2]
		var kit: KitView = c[3]
		var avatar: PlayerAvatar = c[4]
		if c[6]:
			continue
		kit.sync(reader)
		avatar.sync(reader)
		avatar.position = SimPlane.to_3d(reader.player_pos(), 0.0)
		if reader.swing_tick() >= c[5]:
			c[6] = true
			continue
		w.step(InputFrame.make(Vector2i.ZERO, AIM, 300, 0, 0))
	return false


func _process(_delta: float) -> bool:
	for c: Array in _cells:
		if not c[6]:
			return false
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGB8)
	for k in 4:
		var img: Image = (_cells[k][0] as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(k % 2 * CELL.x, k / 2 * CELL.y))
	var path := _dir + "four_slashes.png"
	sheet.save_png(path)
	print("SHOT| ", ProjectSettings.globalize_path(path))
	quit(0)
	return true
