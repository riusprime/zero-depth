extends SceneTree
## The v0.3.0 E shots: shard gems flying from a kill to the player with the HUD counter, an altar with its prompt,
## the 3-card pick (the shipped layout and two alternatives for the owner, G2), and a chest whose price you can't
## afford yet (red). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/rewards.gd
## Boots main.tscn and plays with real input events only (stick, triggers, pad buttons); frames are grabbed in
## _process. Writes each shot, rewards_sheet.png (2 × 2) and pick_mockups.png (3 layouts) to
## build/shots/v0.3.0/rewards/. In the 3 × 2 sheet a "+" tile is a 2× close-up of the frame's middle (the camera
## centres the player): shards, altar and chest up close, then the pick, the chest and the shards whole.
## Evidence copies are made by hand.

const OUT := "res://build/shots/v0.3.0/rewards/"
const SHEET_SCALE := 0.45
const GIVE_UP_FRAMES := 6000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _shots := {}
var _target := Vector2.ZERO
var _nav: NavField
var _mock: PickPanel
var _mock_layouts: Array = [PickPanel.Layout.ROW_LOW, PickPanel.Layout.COLUMN_RIGHT]
var _pending: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"rewards: renderer=%s device=%s"
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
		print("rewards: gave up in step ", _step)
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
			if _main.driver != null and _step_frame > 40:
				_go(&"fight")
		&"fight":
			_fight_step()
		&"to_altar":
			if _walk_step():
				_grab_soon("altar")
				_go(&"open_altar")
		&"open_altar":
			if _step_frame == 2:
				_button(JOY_BUTTON_X, true)
			if _step_frame == 4:
				_button(JOY_BUTTON_X, false)
			if (
				_step_frame > 4
				and _hud().pick_panel().is_open()
				and _cards_shown(_hud().pick_panel())
			):
				print("rewards: pick open, title '%s'" % _hud().pick_panel().title_text())
				_grab_soon("pick_row_centre")
				_go(&"mockups")
		&"mockups":
			_mockup_step()
		&"take":
			if _step_frame == 2:
				_button(JOY_BUTTON_A, true)
			if _step_frame == 3:
				_button(JOY_BUTTON_A, false)
			if _step_frame > 3 and not _reader().choosing():
				print("rewards: took item %s" % _reader().item_id(_reader().items_owned()[0]))
				_start_walk(RewardStore.Kind.CHEST)
		&"to_chest":
			if _walk_step():
				print(
					(
						"rewards: chest price %d, shards %d, prompt '%s'"
						% [
							_reader().reward_price(_reader().reward_in_reach()),
							_reader().shards(),
							_hud().prompt_text()
						]
					)
				)
				_grab_soon("chest")
				_go(&"done")
		&"done":
			_save()
			quit(0)
	return false


func _fight_step() -> void:
	var w := _main.driver.world
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and (best < 0 or _closer(w, i, best)):
			best = i
	if best >= 0:
		var d := (w.actors.pos(best) - w.player_pos()).normalized()
		var c := InputLatch.C45
		var screen := Vector2((d.x + d.y) * c, (d.y - d.x) * c)
		_axis(JOY_AXIS_RIGHT_X, screen.x)
		_axis(JOY_AXIS_RIGHT_Y, -screen.y)
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	if _main.view.shards.count() >= 3:
		print(
			(
				"rewards: %d gems in flight, shards %d, kills %d"
				% [_main.view.shards.count(), w.shards, w.kills]
			)
		)
		_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		_axis(JOY_AXIS_RIGHT_X, 0.0)
		_axis(JOY_AXIS_RIGHT_Y, 0.0)
		_grab_soon("shards", 1)
		_start_walk(RewardStore.Kind.ALTAR)


func _closer(w: World, a: int, b: int) -> bool:
	return w.actors.pos(a).distance_to(w.player_pos()) < w.actors.pos(b).distance_to(w.player_pos())


func _start_walk(kind: int) -> void:
	var w := _main.driver.world
	var i := -1
	for k in w.rewards.size():
		var d := w.rewards.pos(k).distance_to(w.player_pos())
		if (
			w.rewards.kind[k] == kind
			and (i < 0 or d < w.rewards.pos(i).distance_to(w.player_pos()))
		):
			i = k
	_target = w.rewards.pos(i)
	_nav = NavField.new()
	_nav.build(w.walls)
	_nav.flood(_target)
	_go(&"to_altar" if kind == RewardStore.Kind.ALTAR else &"to_chest")


## One frame of walking; true once the player stands still within reach.
func _walk_step() -> bool:
	var w := _main.driver.world
	var p := w.player_pos()
	if (_target - p).length() <= w.reward_table.interact_radius_m * 0.6:
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		return w.vel.length() < 0.001
	var dir := (_target - p).normalized() if (_target - p).length() < 1.5 else _nav.direction(p)
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)
	return false


## The two alternative layouts, shown one at a time over the same open choice (the shipped panel hidden).
func _mockup_step() -> void:
	var shipped := _hud().pick_panel()
	if _mock == null:
		if _mock_layouts.is_empty():
			shipped.visible = true
			_go(&"take")
			return
		shipped.visible = false
		_mock = PickPanel.new(_mock_layouts.pop_front())
		_mock.input_enabled = false
		_hud().add_child(_mock)
		_mock.sync(_reader())
		_step_frame = 0
		return
	if _step_frame > 4 and _cards_shown(_mock):
		_grab("pick_row_low" if _mock.layout == PickPanel.Layout.ROW_LOW else "pick_column_right")
		_mock.queue_free()
		_mock = null


func _cards_shown(p: PickPanel) -> bool:
	for k in p.card_count():
		if p.slot(k).card.modulate.a < 0.99:
			return false
	return true


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
	var path := OUT + shot + ".png"
	img.save_png(path)
	_shots[shot] = img
	print("rewards: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


func _save() -> void:
	_sheet(
		["shards+", "altar+", "chest+", "pick_row_centre", "chest", "shards"],
		3,
		"rewards_sheet.png"
	)
	_sheet(["pick_row_centre", "pick_row_low", "pick_column_right"], 1, "pick_mockups.png")


func _sheet(names: Array, cols: int, file: String) -> void:
	var first: Image = _shots[names[0].trim_suffix("+")]
	var cw := int(first.get_width() * SHEET_SCALE)
	var ch := int(first.get_height() * SHEET_SCALE)
	var rows := int(ceil(float(names.size()) / cols))
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGB8)
	for i in names.size():
		var img: Image = (_shots[names[i].trim_suffix("+")] as Image).duplicate()
		if names[i].ends_with("+"):
			img = img.get_region(
				Rect2i((img.get_width() - cw) / 2, (img.get_height() - ch) / 2, cw, ch)
			)
		else:
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	var path := OUT + file
	sheet.save_png(path)
	print("rewards: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", names)


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
