extends SceneTree
## v0.6.0 Step SR: the owner's gamble shrine model in the real game. Boots main.tscn, walks to the shrine in the start
## hall with the stick (Input.parse_input_event only), grabs it in reach (its price floating above, the crystal's
## light up), then uses it with the pad's X and grabs the spin. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 \
##     -s scripts/shots/shrine_model.gd
## (with XDG_DATA_HOME pointed at an empty folder, so a saved run from another build can't turn Enter into Continue).
## SHOT HELPER (labelled): the shards are granted directly before the use (earning them is not this shot's subject).
## Writes near.png and spin.png to build/shots/v0.6.0/shrine_model/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.6.0/shrine_model/"
const GIVE_UP_FRAMES := 4000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _nav: NavField


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"shrine_model: renderer=%s device=%s window=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("shrine_model: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 40:
				var w := _main.driver.world
				_nav = NavField.new()
				_nav.build(w.walls)
				_nav.flood(_front(w))
				_go(&"walk")
		&"walk":
			if _walk_step():
				_go(&"near")
		&"near":
			if _step_frame == 40:
				var shrine := _main.view.gamble_shrine
				var w := _main.driver.world
				print(
					(
						"shrine_model: uses_model=%s view_pos=%s sim_pos=%s price='%s'"
						% [
							shrine.uses_model(),
							shrine.root.position,
							w.gamble_pos,
							shrine.price_label.text
						]
					)
				)
				_grab("near")
				w.shards = 160  # SHOT HELPER (labelled): see the header.
				_go(&"use")
		&"use":
			if _step_frame == 2:
				_button(JOY_BUTTON_X, true)
			if _step_frame == 4:
				_button(JOY_BUTTON_X, false)
			if _step_frame == 14:
				print("shrine_model: spinning=%s" % _main.view.gamble_shrine.spinning())
				_grab("spin")
				quit(0)
	return false


## One frame of walking toward the shrine; true once the player stands still within reach.
func _walk_step() -> bool:
	var w := _main.driver.world
	var p := w.player_pos()
	var target := _front(w)
	if (target - p).length() <= 0.35:
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		return w.vel.length() < 0.001
	var dir := (target - p).normalized() if (target - p).length() < 1.5 else _nav.direction(p)
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)
	return false


## A spot just in front of the shrine (toward the start point): the shrine itself is solid.
func _front(w: World) -> Vector2:
	var to_start := w.floor_layout.start_pos - w.gamble_pos
	return w.gamble_pos + to_start.normalized() * 1.2


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + shot + ".png"
	img.save_png(path)
	print("shrine_model: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _button(b: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
