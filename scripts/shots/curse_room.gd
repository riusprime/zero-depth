extends SceneTree
## v0.8.0 N17 (owner O75): the curse room in the real game. Boots main.tscn on run seed `seed=N` (one whose floor 1
## holds a curse room), goes to the curse altar (with `walk=1` by the stick, Input.parse_input_event only), grabs the
## room (the default camera), the altar close up (the camera's view size lowered), then presses E and grabs the panel.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/curse_room.gd -- seed=1
## (with XDG_DATA_HOME pointed at an empty folder, so a saved run from another build can't turn Enter into Continue).
## SHOT HELPER (labelled): the hero's HP is held at its max every frame (surviving the walk is not this shot's
## subject), and without `walk=1` the hero is set beside the altar once landed (the walk across the floor takes too
## long on the software renderer; reaching it by input is test_e2e_curse_room's job). Writes <seed>_room.png,
## <seed>_close.png and <seed>_panel.png to build/shots/v0.8.0/n17/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/n17/"
const GIVE_UP_FRAMES := 6000
const CLOSE_VIEW := 6.5

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _nav: NavField
var _seed := 1
var _walk := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
		if a == "walk=1":
			_walk = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"curse_room: renderer=%s device=%s window=%s seed=%d"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size(),
				_seed
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	Main.fixed_seed = _seed
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("curse_room: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _main.driver != null and _main.driver.world != null:
		var w := _main.driver.world
		w.actors.hp[0] = w.actors.max_hp[0]  # SHOT HELPER (labelled): see the header.
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 60:
				var w := _main.driver.world
				if w.ev.curse_k < 0:
					print("curse_room: seed %d has no curse room on this floor" % _seed)
					quit(1)
					return false
				print(
					(
						"curse_room: biome=%s altar=%s event=%s room=%d"
						% [
							_main.view.stage.prop_style,
							w.ev.pos(w.ev.curse_k),
							Events.table(w, w.ev.curse_k).id,
							w.ev.room[w.ev.curse_k]
						]
					)
				)
				if _walk:
					_nav = NavField.new()
					_nav.build(w.walls)
					_nav.flood(_target(w))
					_go(&"walk")
				else:
					_go(&"place")
		&"place":
			if _step_frame == 150:  # after the arrival: SHOT HELPER (labelled), see the header
				var w := _main.driver.world
				w.actors.set_pos(0, _target(w))
				w.vel = Vector2.ZERO
				_main.view.rig.snap_to(SimPlane.to_3d(_target(w)))
				_go(&"room")
		&"walk":
			if _walk_step():
				_go(&"room")
		&"room":
			if _step_frame == 60:
				_grab("room")
				_main.view.rig.view_size = CLOSE_VIEW
			if _step_frame == 100:
				_grab("close")
				_main.view.rig.view_size = 17.0
				_key(KEY_E, true)
			if _step_frame == 102:
				_key(KEY_E, false)
			if _step_frame == 140:
				var w := _main.driver.world
				print(
					(
						"curse_room: open=%d labels=%d prompt_ok=%s"
						% [w.ev.open, _main.view.events.label_count(), w.ev.open == w.ev.curse_k]
					)
				)
				_grab("panel")
				quit(0)
	return false


## Where to stand: beside the altar, toward the room's centre.
func _target(w: World) -> Vector2:
	var at := w.ev.pos(w.ev.curse_k)
	var c := w.floor_layout.rooms[w.ev.room[w.ev.curse_k]].get_center()
	var d := c - at
	return at + (d.normalized() if d.length() > 0.1 else Vector2(1, 0)) * 0.9


func _walk_step() -> bool:
	var w := _main.driver.world
	var p := w.player_pos()
	var target := _target(w)
	if (target - p).length() <= 0.4:
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		return w.vel.length() < 0.001
	var dir := (target - p).normalized() if (target - p).length() < 1.5 else _nav.direction(p)
	if dir == Vector2.ZERO:
		dir = (target - p).normalized()
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)
	return false


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%d_%s.png" % [_seed, shot]
	img.save_png(path)
	print("curse_room: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


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
