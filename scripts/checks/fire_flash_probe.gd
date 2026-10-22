extends SceneTree
## v0.8.0 N1 (owner O46/O55: "some fire drawings popping randomly in position and timing through the whole screen …
## it happens really fast"): counts flame and ember pixels drawn where no fire burns, frame by frame.
## The game's own VfxLayer (the effect sprites' pools) draws the fire props' flames the way WorldViewRoot does
## (_draw_prop_fires: one prop_fire per visible fire light, in the lights' order), on a black stage seen by an
## orthographic iso camera, while the physics clock ticks at 60 Hz as in the game (physics interpolation on, the
## project's setting). Every `toggle` frames one fire light hides or shows again (what P3's far-light fades do as
## you walk: StageKit hides a light out of the view's reach), so the flames after it take other pool slots, as they
## do in play whenever a light hides or another effect's flames are drawn first; shuffle=1 changes the order every
## frame (the worst case).
## Per rendered frame it counts the bright pixels outside every visible fire's own box ("stray"): a flame or an ember
## drawn far from any fire. 0 is right.
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/fire_flash_probe.gd \
##     -- [frames=240] [toggle=6] [shuffle=1] [interp=inherit] [tag=after]
## interp=inherit: the effect layer follows the scene's physics interpolation (the look before N1) instead of the
## layer's own mode. Needs a renderer (not --headless). Writes only under build/ (build/perf/fire_flash_<tag>.txt)
## and prints the same report. Quits on every path.

const OUT_DIR := "res://build/perf"
const COLS := 4
const ROWS := 3
const SPACING := 6.0
## A fire's own box on screen: this many metres around the top of its flame (the flames and the embers rising).
const BOX_M := 1.6
const BRIGHT := 0.12

var _frames := 240
var _toggle := 6
var _shuffle := false
var _inherit := false
var _tag := "probe"
var _layer: VfxLayer
var _cam: Camera3D
var _fires: Array[Vector3] = []
var _hidden := -1
var _frame := 0
var _last_boxes: Array[Rect2] = []
var _rows: Array[int] = []
var _report: PackedStringArray = []
var _order: Array[int] = []
var _shot_at: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			_frames = int(a.trim_prefix("frames="))
		elif a.begins_with("toggle="):
			_toggle = maxi(1, int(a.trim_prefix("toggle=")))
		elif a == "shuffle=1":
			_shuffle = true
		elif a == "interp=inherit":
			_inherit = true
		elif a == "shot=1":
			_shot_at = [7, 13, 19, 25]
		elif a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
	if DisplayServer.get_name() == "headless" or not VfxLayer.available():
		print("fire_flash_probe: needs a renderer and the VFX textures")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage := Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.BLACK
	stage.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 24.0
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stage.add_child(_cam)
	_cam.look_at_from_position(Vector3(14, 16, 14), Vector3.ZERO, Vector3.UP)
	_layer = VfxLayer.new()
	stage.add_child(_layer)
	if _inherit:
		_layer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	for r in ROWS:
		for c in COLS:
			_fires.append(
				Vector3((c - (COLS - 1) * 0.5) * SPACING, 0.9, (r - (ROWS - 1) * 0.5) * SPACING)
			)
	for k in _fires.size():
		_order.append(k)
	(
		_report
		. append(
			(
				"fire_flash_probe: fires=%d frames=%d toggle=%d shuffle=%s layer_interpolation=%s renderer=%s device=%s"
				% [
					_fires.size(),
					_frames,
					_toggle,
					str(_shuffle),
					(
						"inherit (scene: on)"
						if _inherit
						else _mode_name(_layer.physics_interpolation_mode)
					),
					ProjectSettings.get_setting("rendering/renderer/rendering_method"),
					RenderingServer.get_video_adapter_name(),
				]
			)
		)
	)
	process_frame.connect(_on_frame)


static func _mode_name(m: int) -> String:
	return ["inherit", "on", "off"][clampi(m, 0, 2)]


func _on_frame() -> void:
	# Count the frame drawn last time (its boxes were kept), then lay out this one.
	if _frame >= 3 and not _last_boxes.is_empty():
		var img := root.get_texture().get_image()
		_rows.append(_stray(img, _last_boxes))
		if _shot_at.has(_frame):  # shot=1: the frame with every fire's box outlined (build/perf/)
			for b in _last_boxes:
				_outline(img, b)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
			img.save_png("%s/fire_flash_%s_%d.png" % [OUT_DIR, _tag, _frame])
	if _frame >= _frames + 3:
		_finish()
		return
	if _frame % _toggle == 0:
		_hidden = -1 if _hidden >= 0 else (_frame / _toggle) % _fires.size()
	if _shuffle:
		_order.shuffle()
	var now := float(_frame)
	_layer.begin(now)
	var boxes: Array[Rect2] = []
	for k in _order:
		if k == _hidden:
			continue
		var p := _fires[k]
		_layer.prop_fire(p, k * 7919 + 13)
		boxes.append(_box(p))
	_layer.finish()
	_last_boxes = boxes
	_frame += 1


## A fire's box on screen (px): BOX_M around its flame and the embers above it.
func _box(p: Vector3) -> Rect2:
	# unproject_position is in the viewport's base size (the stretch's 1920 x 1080); the image is the window's.
	var k := Vector2(root.size) / root.get_visible_rect().size
	var a := _cam.unproject_position(p + Vector3(0, 0.6, 0)) * k
	var b := _cam.unproject_position(p + Vector3(BOX_M, 0.6, 0)) * k
	var r := maxf(8.0, a.distance_to(b))
	return Rect2(a - Vector2(r, r * 1.6), Vector2(r * 2.0, r * 2.6))


static func _outline(img: Image, b: Rect2) -> void:
	var r := Rect2i(b).intersection(Rect2i(Vector2i.ZERO, img.get_size() - Vector2i.ONE))
	for x in range(r.position.x, r.end.x):
		img.set_pixel(x, r.position.y, Color(0, 0.6, 1))
		img.set_pixel(x, r.end.y, Color(0, 0.6, 1))
	for y in range(r.position.y, r.end.y):
		img.set_pixel(r.position.x, y, Color(0, 0.6, 1))
		img.set_pixel(r.end.x, y, Color(0, 0.6, 1))


static func _stray(img: Image, boxes: Array[Rect2]) -> int:
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := img.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) < BRIGHT:
				continue
			var inside := false
			for b in boxes:
				if b.has_point(Vector2(x, y)):
					inside = true
					break
			if not inside:
				n += 1
	return n


func _finish() -> void:
	var with := 0
	var total := 0
	var worst := 0
	for v in _rows:
		total += v
		worst = maxi(worst, v)
		if v > 0:
			with += 1
	(
		_report
		. append(
			(
				"frames counted=%d  frames with stray flame pixels=%d  stray pixels total=%d  worst frame=%d (every 2nd px)"
				% [_rows.size(), with, total, worst]
			)
		)
	)
	var line := PackedStringArray()
	for v in _rows.slice(0, mini(60, _rows.size())):
		line.append(str(v))
	_report.append("first frames: " + " ".join(line))
	var text := "\n".join(_report)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open("%s/fire_flash_%s.txt" % [OUT_DIR, _tag], FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)
