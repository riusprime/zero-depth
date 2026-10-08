extends SceneTree
## The v0.5.0 EV shots: the floor's event pedestal lit with its name and prompt, its open panel, a cursed chest card
## in the 3-card pick, and the HUD's threat panel once the curse is held. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/events.gd
## Boots main.tscn and walks with the stick, opens with the pad's X and takes with A; frames are grabbed in _process.
## SHOT HELPERS (labelled): the player is kept invulnerable (the walk crosses the floor's spawns), the next chest is
## cursed through the dev route's flag (DebugApi.curse_next_chest sets the same) and shards are granted before the
## chest. Writes each shot to build/shots/v0.5.0/events/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.5.0/events/"
const GIVE_UP_FRAMES := 9000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _nav: NavField
var _target := Vector2.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"events: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("events: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _main.driver != null:
		_main.driver.world.actors.invuln[0] = 1 << 20  # SHOT HELPER (labelled): see the header.
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 40:
				_walk_to(_main.driver.world.ev.pos(0) + Vector2(0.0, -1.0))
				_go(&"walk_pedestal")
		&"walk_pedestal":
			if _walk_step():
				_go(&"pedestal")
		&"pedestal":
			if _step_frame == 30:
				var w := _main.driver.world
				print(
					(
						"events: event '%s', prompt '%s'"
						% [Events.table(w, 0).id, _hud().events.prompt_text()]
					)
				)
				_grab("pedestal")
				_go(&"open")
		&"open":
			_press(JOY_BUTTON_X)
			if _step_frame == 30:
				var p := _hud().events.panel
				print("events: panel open %s, %d cards" % [p.is_open(), p.card_count()])
				_grab("panel")
				_go(&"take")
		&"take":
			_press(JOY_BUTTON_A)
			if _step_frame == 20:
				var w := _main.driver.world
				w.ev.force_curse = true  # SHOT HELPER (labelled): the dev route's flag.
				w.shards = 500  # SHOT HELPER (labelled): see the header.
				var chest := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
				_walk_to(w.rewards.pos(chest))
				_go(&"walk_chest")
		&"walk_chest":
			if _walk_step():
				_go(&"chest")
		&"chest":
			_press(JOY_BUTTON_X)
			if _step_frame == 30:
				print("events: cursed card '%s'" % _hud().pick_panel().slot(0).curse_text())
				_grab("cursed_card")
				_go(&"take_cursed")
		&"take_cursed":
			_press(JOY_BUTTON_A)
			if _step_frame == 40:
				var w := _main.driver.world
				print("events: threat %d, curses %s" % [Curses.threat(w), w.curses_owned])
				_grab("threat")
				quit(0)
	return false


func _press(b: JoyButton) -> void:
	if _step_frame == 2:
		_button(b, true)
	if _step_frame == 4:
		_button(b, false)


func _walk_to(target: Vector2) -> void:
	_target = target
	_nav = NavField.new()
	_nav.build(_main.driver.world.walls)
	_nav.flood(target)


## One frame of walking toward the target; true once the player stands still within reach.
func _walk_step() -> bool:
	var w := _main.driver.world
	var p := w.player_pos()
	if (_target - p).length() <= 0.5:
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		return w.vel.length() < 0.001
	var dir := (_target - p).normalized() if (_target - p).length() < 1.5 else _nav.direction(p)
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)
	return false


func _hud() -> Hud:
	return _main.get_node("UI/Hud")


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + shot + ".png"
	img.save_png(path)
	print("events: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


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
