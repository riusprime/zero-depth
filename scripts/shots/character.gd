extends SceneTree
## Renders the player's hooded wanderer (v0.2.0 G2) for the owner. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd \
##     -- mode=turnaround ref=<path to docs/art/main-character-sheet.png>
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd -- mode=motion
## Writes build/shots/<version>/character/{turnaround,compare,motion}.png and prints each path.
## turnaround: the owner's sheet's four views (front, right-front, right, back-right) on a dark ground like the
## sheet's, rendered at the sheet's size (1774 x 887) with the figures where the sheet has them: row A from a low
## camera like the sheet's, row B from the in-game iso camera (IsoRig's pitch), row C poses driven through
## PlayerAvatar.apply_state (idle, walk, dash, swing, guard, dead) under the iso camera. compare.png stacks the
## owner's sheet over rows A and B at the same scale.
## motion: boots main.tscn, picks the utility and enters the floor with Enter, then walks, dashes and swings with
## real key and mouse events; frames are cropped around the player and grabbed in _process. Around the dash and
## the swing the script lets the sim step only once per rendered frame (SimDriver.paused), so frames land a tick
## apart; the sim itself is unchanged.

## The sheet's views as sim aim angles under IsoRig's fixed yaw: -45° faces the camera, +45° faces screen right
## (the camera sees the wanderer's right side). The sheet's views aren't at even 45° steps: from how much of the
## hood's side and face each one shows, they're turned about 0°, 60°, 75° and 155° from the front.
const VIEWS_DEG := [-45.0, 15.0, 30.0, 110.0]
const VIEW_NAMES := ["front", "right-front", "right", "back-right"]
## The sheet's size, and its figures' centres (px from the left) and feet line (px from the top), measured on it.
const SHEET := Vector2i(1774, 887)
const SHEET_X := [250.0, 665.0, 1070.0, 1530.0]
const SHEET_FEET := 676.0
## Metres per sheet pixel: the sheet's front figure is ~490 px tall; the wanderer is ~1.12 m.
const M_PER_PX := 1.12 / 490.0
## The sheet's camera looks down somewhat (its hood tops and cloak shoulders show); picked by eye, not measured.
const SHEET_PITCH := 20.0
const ISO_PITCH := 35.26
const MOTION_CELL := 220

var _mode := "turnaround"
var _ref := "res://docs/art/main-character-sheet.png"
var _dir := ""
var _frame := 0
var _ticks := 0
# turnaround
var _vp: SubViewport
var _rig: IsoRig
var _turn: Array[PlayerAvatar] = []
var _poses: Array[PlayerAvatar] = []
var _shots: Array[Image] = []
var _pose_at := Vector3.ZERO
var _game_light: DirectionalLight3D
var _sheet_light: DirectionalLight3D
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
	_vp = SubViewport.new()
	_vp.size = SHEET
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#252931")  # the sheet's background
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
	var light := DirectionalLight3D.new()  # the same light as StageView
	light.rotation_degrees = Vector3(-38, 168, 0)
	light.light_energy = 1.05
	light.light_color = Color(1, 0.98, 0.95)
	light.shadow_enabled = true
	light.shadow_blur = 0.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)
	_game_light = light
	# Row A only: a soft key from above and in front, as the sheet is lit (its tops and front facets are the
	# brightest); rows B and C use the game's light above.
	_sheet_light = DirectionalLight3D.new()
	_sheet_light.rotation_degrees = Vector3(-58, 70, 0)
	_sheet_light.light_energy = 0.95
	_sheet_light.light_color = Color(1, 0.97, 0.93)
	_sheet_light.shadow_enabled = true
	_sheet_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(_sheet_light)
	_game_light.visible = false
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#1C1F26")
	gm.roughness = 1.0
	ground.material_override = gm
	scene.add_child(ground)
	_rig = IsoRig.new()
	_rig.set_process(false)
	scene.add_child(_rig)
	_rig.camera.current = true
	for k in VIEWS_DEG.size():
		var a := _avatar(scene, _right() * (SHEET_X[k] - SHEET.x * 0.5) * M_PER_PX)
		a.apply_state(_state(0, Vector2.ZERO, deg_to_rad(VIEWS_DEG[k])))
		_turn.append(a)
	_pose_at = _down() * 30.0
	for k in 6:
		_poses.append(_avatar(scene, _pose_slot(k)))
	_frame_rig(SHEET_PITCH, Vector3.ZERO)


## Screen-right and screen-down on the ground plane under IsoRig's fixed 45° yaw.
func _right() -> Vector3:
	return Vector3(cos(PI / 4), 0, -sin(PI / 4))


func _down() -> Vector3:
	return Vector3(cos(PI / 4), 0, sin(PI / 4))


func _pose_slot(k: int) -> Vector3:
	return _pose_at + _right() * (float(k) - 2.5) * 1.35


## Points the rig so the ground under `at` lands on the sheet's feet line at the sheet's scale.
func _frame_rig(pitch: float, at: Vector3, view_m: float = SHEET.y * M_PER_PX) -> void:
	_rig.set_pitch(pitch)
	_rig.view_size = view_m
	_rig.camera.size = view_m
	# A point `rise` metres above the ground shows (rise * cos(pitch)) higher on screen; aim that far above the
	# ground so the ground lands on the feet line.
	var below := (SHEET_FEET - SHEET.y * 0.5) / SHEET.y * view_m
	_rig.snap_to(at + Vector3(0, below / cos(deg_to_rad(pitch)), 0))


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
		_poses[k].position = _pose_slot(k)


func _turnaround_process() -> void:
	_frame += 1
	if _frame == 30:
		_shots.append(_grab_vp())
		_frame_rig(ISO_PITCH, Vector3.ZERO)
		_sheet_light.visible = false
		_game_light.visible = true
	if _frame == 40:
		_shots.append(_grab_vp())
		_frame_rig(ISO_PITCH, _pose_at, 4.6)
	if _frame > 40:
		_drive_poses(_frame - 40)
	if _frame == 40 + 86:
		_shots.append(_grab_vp())
		_write_turnaround()
		quit(0)


func _grab() -> Image:
	return root.get_texture().get_image()


func _grab_vp() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _stack(rows: Array[Image]) -> Image:
	var out := Image.create(SHEET.x, SHEET.y * rows.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color("#252931"))
	for k in rows.size():
		var r := rows[k]
		out.blit_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), Vector2i(0, SHEET.y * k))
	return out


func _write_turnaround() -> void:
	var sheet := _stack(_shots)
	var path := _dir + "turnaround.png"
	sheet.save_png(path)
	print(
		"character: ",
		path,
		" views=",
		", ".join(VIEW_NAMES),
		"; rows: sheet camera, iso camera, poses"
	)
	var ref := Image.new()
	if ref.load(ProjectSettings.globalize_path(_ref)) != OK:
		print("character: reference NOT FOUND at ", _ref, "; compare.png not written")
		return
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(SHEET.x, SHEET.y)
	var rows: Array[Image] = [ref, _shots[0], _shots[1]]
	var cmp := _stack(rows)
	cmp.resize(cmp.get_width() * 3 / 4, cmp.get_height() * 3 / 4)
	var cpath := _dir + "compare.png"
	cmp.save_png(cpath)
	print("character: ", cpath, " reference=", _ref)


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
