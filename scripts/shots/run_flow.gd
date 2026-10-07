extends SceneTree
## Run-flow shots (v0.3.0 B): the real main.tscn on a run, posed by a script (a tool, not a test: it moves the
## player and kills the boss directly). Shots: the boss door from outside (shut, red seal), the door sealed behind
## you with the boss up, the portal active after the boss dies, floor 2's title card, the pause menu, the run recap.
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/run_flow.gd
## Writes each shot and a 3 x 2 contact sheet to build/shots/v0.3.0/run_flow/.

const OUT := "res://build/shots/v0.3.0/run_flow/"
const SHEET_COLS := 3
const SHEET_SCALE := 0.5
const SETTLE := 40

var main: Main
var _step := 0
var _frames := 0
var _images: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	print("run_flow: ", OUT + shot_name + ".png")


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_world().actors.invuln[0] = 1 << 24
				var f := _world().floor_layout
				_put(f.boss_door_center - Kin.dir(f.boss_door_angle) * 7.5)
				_next()
		1:
			if _frames == SETTLE:
				_shot("1_boss_door_outside")
				var f := _world().floor_layout
				_put(f.boss_door_center + Kin.dir(f.boss_door_angle) * 2.5)
				_next()
		2:
			if _frames == 4:
				var f := _world().floor_layout
				_put(f.boss_door_center + Kin.dir(f.boss_door_angle) * 3.5)
			if _frames == SETTLE:
				_shot("2_boss_door_sealed")
				var w := _world()
				var i := w.actors.index_of(w.boss_id)
				if i >= 0:
					w.actors.invuln[i] = 0
					Damage.hit(
						w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i)
					)
				_put(w.floor_layout.portal_front_point() + w.floor_layout.portal_facing() * 3.0)
				_next()
		3:
			if _frames == SETTLE + 20:
				_shot("3_portal_active")
				var f := _world().floor_layout
				_put(f.portal_front_point() - f.portal_facing() * 0.7)
				_next()
		4:
			if main.run != null and main.run.floor_index == 2 and _frames > 6:
				_world().actors.invuln[0] = 1 << 24
				_next()
		5:
			if _frames == 26:
				_shot("4_floor_2_title")
				main.open_pause()
				_next()
		6:
			if _frames == 10:
				_shot("5_pause")
				main.close_pause()
				var w := _world()
				w.actors.invuln[0] = 0
				Damage.hit(w, 0, 999999, 0, 0, w.take_root(), 0, w.player_pos(), w.player_pos())
				_next()
		7:
			if main.get_node_or_null("UI/EndPanel") != null and _frames > 70:
				_shot("6_run_recap")
				_save_sheet()
				quit(0)
	if _frames > 4000:
		push_error("run_flow: stuck at step %d" % _step)
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
	var path := OUT + "run_flow_sheet.png"
	sheet.save_png(path)
	print("run_flow: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", _names)
