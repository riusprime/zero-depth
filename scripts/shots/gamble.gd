extends SceneTree
## The v0.3.0 L19 shots: the gamble shrine in the start hall with its price in red (no shards yet), the card's spin,
## the landed result with the stats panel, and a second win. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/gamble.gd
## Boots main.tscn and walks with the stick, uses the shrine with the pad's X; frames are grabbed in _process.
## SHOT HELPER (labelled): the shards are granted directly before the first use (earning them is the rewards shots'
## subject). Writes each shot and gamble_sheet.png (2 × 2: "+" tiles are 2× close-ups of the frame's middle) to
## build/shots/v0.3.0/gamble/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.3.0/gamble/"
const SHEET_SCALE := 0.5
const GIVE_UP_FRAMES := 4000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _shots := {}
var _nav: NavField
var _settle := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"gamble: renderer=%s device=%s"
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
		print("gamble: gave up in step ", _step)
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
				_go(&"poor")
		&"poor":
			if _step_frame == 30:
				print("gamble: prompt '%s'" % _hud().gamble.prompt_text())
				_grab("poor")
				_main.driver.world.shards = 160  # SHOT HELPER (labelled): see the header.
				_go(&"use1")
		&"use1":
			_press_x()
			if _step_frame == 14:
				_grab("spin")
			if _landed():
				print("gamble: won '%s'" % _hud().gamble.card.line_text())
				_grab("result")
				_go(&"use2")
		&"use2":
			_press_x()
			if _landed():
				var w := _main.driver.world
				print(
					(
						"gamble: won '%s', shards %d, next price %d"
						% [_hud().gamble.card.line_text(), w.shards, Gamble.price(w)]
					)
				)
				_grab("second")
				_save()
				quit(0)
	return false


## The card has landed on the stat won (a few frames on, so the pop settles; the renderer is slow, frame time).
func _landed() -> bool:
	var card := _hud().gamble.card
	if _step_frame > 6 and card.showing() and not card.spinning():
		_settle += 1
	else:
		_settle = 0
	return _settle == 3


func _press_x() -> void:
	if _step_frame == 2:
		_button(JOY_BUTTON_X, true)
	if _step_frame == 4:
		_button(JOY_BUTTON_X, false)


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
	_shots[shot] = img
	print("gamble: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


func _save() -> void:
	var names := ["poor+", "spin+", "result", "second"]
	var first: Image = _shots["poor"]
	var cw := int(first.get_width() * SHEET_SCALE)
	var ch := int(first.get_height() * SHEET_SCALE)
	var sheet := Image.create(cw * 2, ch * 2, false, Image.FORMAT_RGB8)
	for i in names.size():
		var img: Image = (_shots[names[i].trim_suffix("+")] as Image).duplicate()
		if names[i].ends_with("+"):
			img = img.get_region(
				Rect2i((img.get_width() - cw) / 2, (img.get_height() - ch) / 2 - ch / 6, cw, ch)
			)
		else:
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((i % 2) * cw, (i / 2) * ch))
	var path := OUT + "gamble_sheet.png"
	sheet.save_png(path)
	print("gamble: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", names)


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
