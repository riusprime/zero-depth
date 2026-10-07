extends SceneTree
## Renders the player's hooded wanderer (v0.2.0 G) for the owner. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd \
##     -- mode=turnaround ref=<path to docs/art/main_character_visual_reference.png>
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd -- mode=motion
## Writes build/shots/<version>/character/{turnaround,motion}.png (contact sheets) and prints each path.
## turnaround: five facings (front, 3/4, side, 3/4 back, back) under the iso camera, then a row of poses driven
## through PlayerAvatar.apply_state (idle, walk, dash, swing, guard, dead), next to the owner's reference.
## motion: boots main.tscn, picks the utility and enters the floor with Enter, then walks, dashes and swings with
## real key and mouse events; frames are cropped around the player and grabbed in _process. Around the dash and
## the swing the script lets the sim step only once per rendered frame (SimDriver.paused), so frames land a tick
## apart; the sim itself is unchanged.

const FACINGS_DEG := [-45.0, 0.0, 45.0, 90.0, 135.0]
const CELL := 300
const MOTION_CELL := 220

var _mode := "turnaround"
var _ref := "res://docs/art/main_character_visual_reference.png"
var _dir := ""
var _frame := 0
var _ticks := 0
# turnaround
var _rig: IsoRig
var _turn: Array[PlayerAvatar] = []
var _poses: Array[PlayerAvatar] = []
var _shots: Array[Image] = []
# motion
var _main: Main
var _cells: Array[Image] = []
var _labels: Array[String] = []
var _step_allowed := true


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):
			_mode = arg.trim_prefix("mode=")
		if arg.begins_with("ref="):
			_ref = arg.trim_prefix("ref=")
	_dir = "res://build/shots/%s/character/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	if _mode == "motion":
		var profile := ProfileStore.new("")
		ProfileStore.use_shared(profile)
		_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
		root.add_child(_main)
	else:
		_build_turnaround()


# --- turnaround -------------------------------------------------------------------------------------------------


func _build_turnaround() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#A08A74")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1DC")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()  # the same light as StageView
	light.rotation_degrees = Vector3(-38, 168, 0)
	light.light_energy = 1.05
	light.light_color = Color(1, 0.98, 0.95)
	light.shadow_enabled = true
	light.shadow_blur = 0.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#CBAD91")
	gm.roughness = 1.0
	ground.material_override = gm
	scene.add_child(ground)
	_rig = IsoRig.new()
	_rig.view_size = 3.4
	scene.add_child(_rig)
	# Screen-right on the ground plane is the rig's +X: (cos 45°, 0, -sin 45°). Row 1 at the target, row 2 below.
	var right := Vector3(cos(PI / 4), 0, -sin(PI / 4))
	var down := Vector3(cos(PI / 4), 0, sin(PI / 4))
	for k in FACINGS_DEG.size():
		var a := _avatar(scene, right * (float(k) - 2.0) * 1.15)
		a.apply_state(_state(0, Vector2.ZERO, deg_to_rad(FACINGS_DEG[k])))
		_turn.append(a)
	for k in 6:
		var at := right * (float(k) - 2.5) * 1.0 + down * 30.0
		_poses.append(_avatar(scene, at))
	_rig.snap_to(Vector3.ZERO)


func _avatar(scene: Node3D, at: Vector3) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color("#1A1A22"))
	a.position = at
	scene.add_child(a)
	return a


func _state(tick: int, pos: Vector2, yaw: float, extra: Dictionary = {}) -> Dictionary:
	var s := {
		"tick": tick,
		"pos": pos,
		"aim": int(round(yaw / TAU * 4096.0)) & 4095,
		"dashing": false,
		"swing_t": 0,
		"swing_ticks": 14,
		"swing_angle": 0,
		"combo": 0,
		"guarding": false,
		"dead": false,
	}
	s.merge(extra, true)
	return s


## Drives the six pose avatars for one frame: their (synthetic) sim state as if at tick t.
func _drive_poses(t: int) -> void:
	var face := deg_to_rad(-20.0)  # mostly toward the camera
	var dir := Vector2(cos(face), sin(face))
	var cases := [
		{},
		{"pos": dir * 6.0 / 60.0 * t},
		{
			"pos":
			dir * 6.0 / 60.0 * t + (dir * 26.0 / 60.0 * (t - 80) if t > 80 else Vector2.ZERO),
			"dashing": t > 80
		},
		{"swing_t": clampi(t - 80, 0, 6), "swing_angle": int(round(face / TAU * 4096.0)) & 4095},
		{"guarding": true},
		{"dead": t > 40},
	]
	for k in cases.size():
		var c: Dictionary = cases[k]
		if not c.has("pos"):
			c["pos"] = Vector2.ZERO
		_poses[k].apply_state(_state(t, c["pos"], face, c))
		# The pose avatars stand still on screen; only their sim-side velocity changes.
		_poses[k].position = Vector3(cos(PI / 4), 0, -sin(PI / 4)) * (float(k) - 2.5) * 1.0


func _turnaround_process() -> void:
	_frame += 1
	if _frame == 40:
		_shots.append(_grab())
		_rig.snap_to(Vector3(cos(PI / 4), 0, sin(PI / 4)) * 30.0)
		for k in _poses.size():
			_poses[k].position += Vector3(cos(PI / 4), 0, sin(PI / 4)) * 30.0
	if _frame > 40:
		_drive_poses(_frame - 40)
		for k in _poses.size():
			_poses[k].position += Vector3(cos(PI / 4), 0, sin(PI / 4)) * 30.0
	if _frame == 40 + 86:
		_shots.append(_grab())
		_write_turnaround()
		quit(0)


func _grab() -> Image:
	return root.get_texture().get_image()


func _write_turnaround() -> void:
	var row1 := _shots[0]
	var row2 := _shots[1]
	var w := row1.get_width()
	var h := row1.get_height()
	var sheet_w := w
	var ref := Image.new()
	var have_ref := ref.load(ProjectSettings.globalize_path(_ref)) == OK
	if have_ref:
		ref.convert(Image.FORMAT_RGBA8)
		ref.resize(int(ref.get_width() * float(h) / ref.get_height()), h)
		sheet_w += ref.get_width()
	var sheet := Image.create(sheet_w, h * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#2A2A30"))
	row1.convert(Image.FORMAT_RGBA8)
	row2.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(row1, Rect2i(0, 0, w, h), Vector2i(0, 0))
	sheet.blit_rect(row2, Rect2i(0, 0, w, h), Vector2i(0, h))
	if have_ref:
		sheet.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i(w, 0))
	sheet.resize(sheet_w / 2, h)
	var path := _dir + "turnaround.png"
	sheet.save_png(path)
	print("character: ", path, " reference=", _ref if have_ref else "NOT FOUND")


# --- motion -----------------------------------------------------------------------------------------------------


func _physics_process(_delta: float) -> bool:
	if _mode != "motion" or _main == null or _main.driver == null:
		return false
	# Slow motion around the dash and the swing: let the sim step only once per rendered frame (this shot only;
	# this renderer otherwise runs ~4 ticks per frame).
	if (_ticks >= 76 and _ticks < 100) or (_ticks >= 166 and _ticks < 196):
		_main.driver.paused = not _step_allowed
		if not _step_allowed:
			return false
		_step_allowed = false
	else:
		_main.driver.paused = false
	_ticks += 1
	match _ticks:
		30:
			_mouse(Vector2(300, 700))
			_key(KEY_A, true)
		80:
			_key(KEY_SPACE, true)
		82:
			_key(KEY_SPACE, false)
		110:
			_key(KEY_A, false)
		170:
			_mouse(Vector2(400, 600))
			_click(true)
		174:
			_click(false)
		230:
			_write_motion()
			quit(0)
	return false


func _process(_delta: float) -> bool:
	if _mode != "motion":
		_turnaround_process()
		return false
	_frame += 1
	_step_allowed = true
	if _frame in [8, 14]:
		_key(KEY_ENTER, true)
	if _frame in [9, 15]:
		_key(KEY_ENTER, false)
	if _main.driver == null or _ticks < 20:
		return false
	var tag := _phase_name()
	# Grab a few frames per phase (frame-time, so the in-between animation shows).
	var n := 0
	for l in _labels:
		if l.begins_with(tag):
			n += 1
	var want := 8 if tag == "dash" or tag == "swing" else 4
	var every := 2 if tag == "dash" or tag == "swing" else 3
	if n < want and _frame % every == 0:
		_cells.append(_crop_player())
		_labels.append("%s t%d" % [tag, _main.driver.reader.tick()])
	return false


func _phase_name() -> String:
	if _ticks < 30:
		return "idle"
	if _ticks < 80:
		return "walk"
	if _ticks < 110:
		return "dash"
	if _ticks < 170:
		return "stop"
	return "swing"


func _crop_player() -> Image:
	var img := _grab()
	var cam := _main.view.rig.camera
	var reader := _main.driver.reader
	var node := _main.view.actors.actor_node(reader.actor_id(0))
	var at := SimPlane.to_3d(reader.player_pos())
	if node != null:
		at = node.get_global_transform_interpolated().origin
	var p := cam.unproject_position(at + Vector3(0, 0.55, 0))
	# The camera projects into the viewport's base size; the grabbed image is the window's size.
	p *= Vector2(img.get_size()) / root.get_visible_rect().size
	var half := MOTION_CELL / 2
	var x := clampi(int(p.x) - half, 0, img.get_width() - MOTION_CELL)
	var y := clampi(int(p.y) - half, 0, img.get_height() - MOTION_CELL)
	var out := img.get_region(Rect2i(x, y, MOTION_CELL, MOTION_CELL))
	out.convert(Image.FORMAT_RGBA8)
	out.resize(MOTION_CELL * 2, MOTION_CELL * 2, Image.INTERPOLATE_NEAREST)
	return out


func _write_motion() -> void:
	var cols := 6
	var c := MOTION_CELL * 2
	var rows := ceili(_cells.size() / float(cols))
	var sheet := Image.create(c * cols, c * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#2A2A30"))
	for k in _cells.size():
		sheet.blit_rect(_cells[k], Rect2i(0, 0, c, c), Vector2i((k % cols) * c, (k / cols) * c))
	var path := _dir + "motion.png"
	sheet.save_png(path)
	var full := _dir + "motion_full.png"
	_grab().save_png(full)
	print("character: ", path, " frames=", _cells.size(), " full=", full)
	print("character: cells (row-major) = ", ", ".join(_labels))


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mouse(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(400, 600)
	ev.global_position = Vector2(400, 600)
	Input.parse_input_event(ev)
