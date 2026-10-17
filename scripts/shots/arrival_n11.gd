extends SceneTree
## v0.8.0 N11 arrival shots (owner O69): the real main.tscn on a run, posed by a script (a tool, not a test: it moves
## the player and kills the boss directly). Floor 1: the receiver alone after the cover opened, mid-shake, the pop, the
## settle; then into the gate and floor 2's step-out, chosen by the sim's own arrival progress (WorldReader). Needs a
## renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/arrival_n11.gd
## Writes each shot and a contact sheet to build/shots/v0.8.0/n11/.

const OUT := "res://build/shots/v0.8.0/n11/"
const SHEET_COLS := 4
const SHEET_SCALE := 0.4
const SETTLE := 40
## Arrival progress marks: floor 1 (the receiver alone, the tremble, the pop, the settle), floor 2 (the step-out).
const FIRST_AT := [0.0, 0.45, 0.6, 0.9]
const FIRST_NAMES := ["1_receiver_alone", "2_mid_shake", "3_pop", "4_settle"]
const STEP_AT := [0.3, 0.5]
const STEP_NAMES := ["5_floor2_step_out", "6_floor2_rising"]

var main: Main
var _step := 0
var _frames := 0
var _mark := 0
var _images: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"arrival_n11: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _world() -> World:
	return main.driver.world


func _put(p: Vector2) -> void:
	var w := _world()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	main.view.rig.snap_to(SimPlane.to_3d(p))


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + shot_name + ".png")
	_images.append(img)
	_names.append(shot_name)
	print(
		"arrival_n11: ",
		OUT + shot_name + ".png tick=",
		_world().tick,
		" progress=",
		main.driver.reader.arrival_progress()
	)


func _ready_to_watch() -> bool:
	return main.driver != null and not main.loads.cover.showing()


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_next()
		1:
			if _ready_to_watch():
				var q := main.driver.reader.arrival_progress()
				if _mark < FIRST_AT.size() and q >= FIRST_AT[_mark]:
					_shot(FIRST_NAMES[_mark])
					_mark += 1
				if q < 0.0:
					_world().actors.invuln[0] = 1 << 24
					_put(_world().floor_layout.boss_door_inside(2.5))
					_mark = 0
					_next()
		2:
			if _frames == SETTLE:
				var w := _world()
				var i := w.actors.index_of(w.boss_id)
				if i >= 0:
					w.actors.invuln[i] = 0
					Damage.hit(
						w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i)
					)
				var f := w.floor_layout
				_put(f.portal_front_point() + f.portal_facing() * 1.0)
				_next()
		3:
			if _frames == SETTLE:
				var f := _world().floor_layout
				_put(f.portal_pos + f.portal_facing() * (FloorLayout.GATE_HALF_DEPTH + 0.6))
				_next()
		4:
			if main.run != null and main.run.floor_index == 2:
				_next()
		5:
			if _ready_to_watch():
				var q := main.driver.reader.arrival_progress()
				if _mark < STEP_AT.size() and q >= STEP_AT[_mark]:
					_shot(STEP_NAMES[_mark])
					_mark += 1
				if _mark >= STEP_AT.size() or q < 0.0:
					_save_sheet()
					quit(0)
	if _frames > 3000:
		push_error("arrival_n11: stuck at step %d" % _step)
		quit(1)
	return false


func _next() -> void:
	_step += 1
	_frames = 0


func _save_sheet() -> void:
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
	var path := OUT + "arrival_sheet.png"
	sheet.save_png(path)
	print("arrival_n11: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", _names)
