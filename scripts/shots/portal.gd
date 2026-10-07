extends SceneTree
## The portal gate shots (v0.2.0 PLAN step D): the gate on Ruins ground through the real iso camera, at several
## facing angles, sealed and open. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal.gd
## Writes each shot and a 3 × 2 contact sheet to build/shots/v0.2.0/portal/.

const OUT := "res://build/shots/v0.2.0/portal/"
const GATE_AT := Vector2(3.0, 3.0)
## [name, facing angle (1/4096 turn), sealed]. The camera sits toward sim angle -45° (3584): 3584 faces it,
## 0 and 3072 are 45° off either way, 512 is edge-on (the worst case), 1536 shows the back.
const SHOTS := [
	["facing_camera_sealed", 3584, true],
	["facing_camera_open", 3584, false],
	["facing_0_sealed", 0, true],
	["facing_3072_sealed", 3072, true],
	["facing_512_edge_on_sealed", 512, true],
	["facing_1536_back_sealed", 1536, true],
]
const SHEET_COLS := 3
const SHEET_SCALE := 0.5

var _index := -1
var _frames := 0
var _stage: Node3D
var _images: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"portal: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	_next()


func _stage_for(facing: int, sealed: bool) -> Node3D:
	var holder := Node3D.new()
	var w := World.new(7, PlayerTable.starting_values())
	var walls: Array[Obb] = []
	walls.append(Obb.make(Vector2(0, 9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(0, -9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-9.5, 0), Vector2(0.4, 9), 0))
	w.set_walls(walls)
	var view := WorldViewRoot.new()
	view.rig.view_size = 9.0
	view.rig.dead_zone_m = 1000.0
	holder.add_child(view)
	var palette := Gallery.palette_of(&"ruins")
	view.setup(WorldReader.new(w), palette, 10.0)
	view.rig.snap_to(SimPlane.to_3d(GATE_AT, 1.4))
	var gate := PortalGate.new()
	gate.setup(GATE_AT, facing)
	gate.set_sealed(sealed)
	view.add_child(gate)
	return holder


func _next() -> void:
	if _stage != null:
		_stage.queue_free()
	_index += 1
	if _index >= SHOTS.size():
		_save_sheet()
		quit(0)
		return
	var s: Array = SHOTS[_index]
	_stage = _stage_for(s[1], s[2])
	root.add_child(_stage)
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20 and _index < SHOTS.size():
		var img := root.get_texture().get_image()
		var path := OUT + String(SHOTS[_index][0]) + ".png"
		img.save_png(path)
		_images.append(img)
		print("portal: ", path)
		_next()
	return false


func _save_sheet() -> void:
	if _images.is_empty():
		return
	var cw := int(_images[0].get_width() * SHEET_SCALE)
	var ch := int(_images[0].get_height() * SHEET_SCALE)
	var rows := int(ceil(float(_images.size()) / SHEET_COLS))
	var sheet := Image.create(cw * SHEET_COLS, ch * rows, false, Image.FORMAT_RGB8)
	for i in _images.size():
		var img := _images[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(
			img, Rect2i(0, 0, cw, ch), Vector2i((i % SHEET_COLS) * cw, (i / SHEET_COLS) * ch)
		)
	var path := OUT + "portal_gate_sheet.png"
	sheet.save_png(path)
	print("portal: ", path, " ", sheet.get_width(), "x", sheet.get_height())
