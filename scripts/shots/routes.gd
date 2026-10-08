extends SceneTree
## Route shots (v0.5.0 RT, R5): the real main.tscn on a run, posed by a script (a tool, not a test: it moves the
## player and kills the boss directly). 1: the boss room's two open portals, the gate and the violet Deep gate;
## 2: the Deep gate taking the hero, the gate closed; 3: floor 2's card, "Floor 2 · Deep". Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/routes.gd
## Writes each shot and a 3 x 1 contact sheet to build/shots/v0.5.0/routes/.

const OUT := "res://build/shots/v0.5.0/routes/"
const SHEET_SCALE := 0.5
const SETTLE := 40

var main: Main
var _step := 0
var _frames := 0
var _images: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"routes: renderer=%s device=%s"
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
	print("routes: ", OUT + shot_name + ".png tick=", _world().tick)


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
				# Between the two gates' fronts, a little back, so both are in frame.
				var mid := (f.portal_front_point() + Routes.deep_front(f).get_center()) * 0.5
				_put(mid + f.portal_facing() * 2.0)
				_next()
		2:
			if _frames == SETTLE * 2:
				_shot("1_two_portals")
				var f := _world().floor_layout
				var n := Kin.dir(f.deep_portal_angle)
				_put(f.deep_portal_pos + n * (FloorLayout.GATE_HALF_DEPTH + 0.6))
				_next()
		3:
			var p := main.driver.reader.portal_enter_progress() if main.driver != null else -1.0
			if _images.size() == 1 and p >= 0.3:
				_shot("2_deep_taken")
			if main.run != null and main.run.floor_index == 2:
				_next()
		4:
			if _frames == 30:
				_shot("3_floor_2_deep")
				_save_sheet()
				quit(0)
	if _frames > 3000:
		push_error("routes: stuck at step %d" % _step)
		quit(1)
	return false


func _next() -> void:
	_step += 1
	_frames = 0


func _save_sheet() -> void:
	var cw := int(_images[0].get_width() * SHEET_SCALE)
	var ch := int(_images[0].get_height() * SHEET_SCALE)
	var sheet := Image.create(cw * _images.size(), ch, false, Image.FORMAT_RGB8)
	for i in _images.size():
		var img := _images[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i(i * cw, 0))
	sheet.save_png(OUT + "routes_sheet.png")
	print(
		"routes: %sroutes_sheet.png %dx%d %s" % [OUT, sheet.get_width(), sheet.get_height(), _names]
	)
