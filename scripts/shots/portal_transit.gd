extends SceneTree
## Portal transit shots (v0.3.5 PT; owner F19, F20): the real main.tscn on a run, posed by a script (a tool, not a
## test: it moves the player and kills the boss directly). Four moments of the way into the light-blue portal, then
## four of the arrival on floor 2, chosen by the sim's own progress (WorldReader). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal_transit.gd
## Writes each shot and a 4 x 2 contact sheet to build/shots/v0.3.5/portal/.

const OUT := "res://build/shots/v0.3.5/portal/"
const SHEET_COLS := 4
const SHEET_SCALE := 0.4
const SETTLE := 40
## Progress marks to shoot at: the way in, then the arrival.
const ENTER_AT := [0.2, 0.5, 0.68, 0.82]
const ARRIVE_AT := [0.1, 0.35, 0.6, 0.85]

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
			"portal_transit: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
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
	print("portal_transit: ", OUT + shot_name + ".png tick=", _world().tick)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_world().actors.invuln[0] = 1 << 24
				_put(_world().floor_layout.boss_door_inside(2.5))
				_next()
		1:
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
		2:
			if _frames == SETTLE:
				var f := _world().floor_layout
				# Into the gate's opening: the portal takes the hero on the next tick.
				_put(f.portal_pos + f.portal_facing() * (FloorLayout.GATE_HALF_DEPTH + 0.6))
				_next()
		3:
			var p := main.driver.reader.portal_enter_progress() if main.driver != null else -1.0
			if _mark < ENTER_AT.size() and p >= ENTER_AT[_mark]:
				_shot("in_%d_%02d" % [_mark + 1, int(p * 100)])
				_mark += 1
			if main.run != null and main.run.floor_index == 2:
				_mark = 0
				_next()
		4:
			var q := main.driver.reader.arrival_progress()
			if _mark < ARRIVE_AT.size() and q >= ARRIVE_AT[_mark]:
				_shot("out_%d_%02d" % [_mark + 1, int(q * 100)])
				_mark += 1
			if _mark >= ARRIVE_AT.size() or q < 0.0:
				_save_sheet()
				quit(0)
	if _frames > 3000:
		push_error("portal_transit: stuck at step %d" % _step)
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
	var path := OUT + "portal_transit_sheet.png"
	sheet.save_png(path)
	print("portal_transit: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", _names)
