extends SceneTree
## The v0.3.0 MM shots: the corner minimap at the start of a floor, after a few rooms and after more, then the full
## map while Tab is held. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/minimap.gd [-- lang=es]
## Boots main.tscn and walks with the left stick only (a flow field to a spot just inside the nearest
## unexplored neighbouring room); Tab is a real key event. SHOT HELPER (labelled): the dev panel's god mode is
## switched on so the walk isn't cut short by a death; it changes nothing on the map. Writes each shot and
## minimap_sheet.png to build/shots/v0.3.0/minimap/<lang>/. Evidence copies are made by hand.

const SHEET_CROP := Vector2i(400, 380)
const SHEET_FULL_SCALE := 0.75
const GIVE_UP_FRAMES := 9000
## Rooms entered before the "mid" and "late" shots (the start hall counts); the late shot also waits for the boss
## door to be on the map.
const MID_ROOMS := 3
const LATE_ROOMS := 6

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _shots := {}
var _target := Vector2.ZERO
var _nav: NavField
var _pending: Array = []
var _lang := "en"
var _out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			_lang = arg.trim_prefix("lang=")
	_out = "res://build/shots/v0.3.0/minimap/%s/" % _lang
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("minimap: gave up in step ", _step)
		quit(1)
		return false
	if not _pending.is_empty():
		_pending[1] -= 1
		if _pending[1] <= 0:
			_grab(_pending[0])
			_pending = []
		return false
	_step_frame += 1
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 70:
				_main.driver.debug = DebugApi.new(_main.driver.world)
				_main.driver.debug.god = true
				_grab_soon("early")
				_go(&"walk_mid")
		&"walk_mid":
			if _explore(MID_ROOMS):
				_grab_soon("mid", 4)
				_go(&"walk_late")
		&"walk_late":
			if _explore(LATE_ROOMS):
				_grab_soon("late", 4)
				_go(&"hold_tab")
		&"hold_tab":
			if _step_frame == 1:
				_key(KEY_TAB, true)
			if _step_frame == 4:
				print("minimap: full map showing = ", _hud().minimap.full_map_showing())
				_grab_soon("full", 1)
				_go(&"done")
		&"done":
			_key(KEY_TAB, false)
			_save()
			quit(0)
	return false


## One frame of exploring; true once `rooms` rooms are known (for the late shot, the boss door too) and the player
## has stopped.
func _explore(rooms: int) -> bool:
	var st := _hud().minimap.state
	var r := _reader()
	if st.discovered_count() >= rooms and (rooms < LATE_ROOMS or _boss_door_known(st, r)):
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		return _main.driver.world.vel.length() < 0.001
	if _nav == null or st.is_discovered(r.floor_room_of(_target)):
		_pick_target(st, r)
	var p := r.player_pos()
	var dir := (_target - p).normalized() if (_target - p).length() < 1.5 else _nav.direction(p)
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)
	return false


## A spot just inside the nearest unexplored room past a known doorway (never the boss room: the door seals).
func _pick_target(st: MinimapState, r: WorldReader) -> void:
	var best := -1
	for i in st.unknown_doors(r):
		var d := r.floor_door_rooms(i)
		var room := d.y if st.is_discovered(d.x) else d.x
		if room == r.boss_room():
			continue
		# Just past the doorway's far face: walkable on every floor (FloorGenerator keeps door approaches clear).
		var side: Vector2 = MinimapView.SIDES[(r.floor_door_angle(i) / 1024) % 4]
		var into := side if room == d.y else -side
		var dr := r.floor_door_rect(i)
		var c := dr.get_center() + into * (absf(dr.size.dot(side)) * 0.5 + 1.5)
		if best < 0 or c.distance_to(r.player_pos()) < _target.distance_to(r.player_pos()):
			best = room
			_target = c
	_nav = NavField.new()
	_nav.build(_main.driver.world.walls)
	_nav.flood(_target)
	print("minimap: heading for room ", best)


func _boss_door_known(st: MinimapState, r: WorldReader) -> bool:
	return r.floor_boss_door() < 0 or st.door_known(r, r.floor_boss_door())


func _hud() -> Hud:
	return _main.get_node("UI/Hud")


func _reader() -> WorldReader:
	return _main.driver.reader


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab_soon(shot: String, frames: int = 2) -> void:
	_pending = [shot, frames]


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _out + shot + ".png"
	img.save_png(path)
	_shots[shot] = img
	print(
		(
			"minimap: %s (frame %d, tick %d, rooms %d/%d)"
			% [
				path,
				_frame,
				_main.driver.world.tick,
				_hud().minimap.state.discovered_count(),
				_reader().floor_room_count()
			]
		)
	)


## Three top-right crops (the corner map) over the full map, scaled.
func _save() -> void:
	var full: Image = (_shots["full"] as Image).duplicate()
	full.resize(
		int(full.get_width() * SHEET_FULL_SCALE),
		int(full.get_height() * SHEET_FULL_SCALE),
		Image.INTERPOLATE_LANCZOS
	)
	var w := maxi(SHEET_CROP.x * 3, full.get_width())
	var sheet := Image.create(w, SHEET_CROP.y + full.get_height(), false, Image.FORMAT_RGB8)
	var i := 0
	for name in ["early", "mid", "late"]:
		var img: Image = _shots[name]
		var crop := img.get_region(
			Rect2i(img.get_width() - SHEET_CROP.x, 0, SHEET_CROP.x, SHEET_CROP.y)
		)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, SHEET_CROP), Vector2i(i * SHEET_CROP.x, 0))
		i += 1
	sheet.blit_rect(full, Rect2i(Vector2i.ZERO, full.get_size()), Vector2i(0, SHEET_CROP.y))
	var path := _out + "minimap_sheet.png"
	sheet.save_png(path)
	print("minimap: ", path, " ", sheet.get_width(), "x", sheet.get_height())


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
