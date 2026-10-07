extends SceneTree
## The v0.2.0 K shots (PLAN L12-L13): the dash trail, a blink's two blue flashes, the item card previewing a
## pedestal and after a pickup, and every item icon. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/vfx_cards.gd
## Boots main.tscn (Blink picked in the profile), plays with real input events and grabs frames in _process when
## the effect is on screen (on a software renderer several ticks pass per frame). Writes each shot and a 3 × 2
## contact sheet to build/shots/v0.2.0/vfx_cards/.

const OUT := "res://build/shots/v0.2.0/vfx_cards/"
const SHEET_COLS := 3
const SHEET_SCALE := 0.5
const GIVE_UP_FRAMES := 4000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _shots: Array[Image] = []
var _names: Array[String] = []
var _target := Vector2.ZERO
var _nav: NavField
## A shot waiting a few frames, so the grabbed image shows the state that triggered it: [name, frames left].
var _pending: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"vfx_cards: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	var profile := ProfileStore.new("")
	profile.section("loadout")["utility"] = "blink"
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	_step_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("vfx_cards: gave up in step ", _step)
		quit(1)
		return false
	if not _pending.is_empty():
		_pending[1] -= 1
		if _pending[1] <= 0:
			_grab(_pending[0])
			_pending = []
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 40:
				_go(&"dash")
		&"dash":
			_dash_step()
		&"blink":
			_blink_step()
		&"walk":
			_walk_step()
		&"icons":
			if _step_frame == 6:
				_grab("icons_and_cards")
				_save_sheet()
				quit(0)
		&"settle":
			if _pending.is_empty():
				_show_icons()
	return false


func _dash_step() -> void:
	var trail := _main.view.utility.dash_trail
	if _step_frame == 1:
		_key(KEY_D, true)
	if _step_frame == 10:
		_key(KEY_SPACE, true)
	if _step_frame == 11:
		_key(KEY_SPACE, false)
	if _step_frame > 11 and not _reader().is_dashing() and trail.point_count() >= 4:
		_key(KEY_D, false)
		print(
			"vfx_cards: dash trail points=%d ghosts=%d" % [trail.point_count(), trail.ghost_count()]
		)
		_grab_soon("dash_trail")
		_go(&"blink")


func _blink_step() -> void:
	var u := _main.view.utility
	if _step_frame == 30:
		_key(KEY_A, true)
	if _step_frame == 34:
		_key(KEY_SHIFT, true)
	if _step_frame == 35:
		_key(KEY_SHIFT, false)
	if _step_frame > 35 and u.appear.is_playing() and u.appear.progress() >= 0.12:
		_key(KEY_A, false)
		print(
			(
				"vfx_cards: blink from %s to %s, flash progress %.2f"
				% [_reader().blink_from(), _reader().player_pos(), u.appear.progress()]
			)
		)
		_grab_soon("blink_both_ends")
		_start_walk()


func _start_walk() -> void:
	var w := _main.driver.world
	if w.pickups.size() == 0:
		# v0.3.0 E replaced the pedestals with altars and chests (scripts/shots/rewards.gd shoots those).
		print("vfx_cards: no pedestals on the floor since v0.3.0 E; skipping the card shots")
		_go(&"settle")
		return
	var best := 0
	for i in w.pickups.ids.size():
		if (
			w.pickups.pos(i).distance_to(w.player_pos())
			< w.pickups.pos(best).distance_to(w.player_pos())
		):
			best = i
	_target = w.pickups.pos(best)
	_nav = NavField.new()
	_nav.build(w.walls)
	_nav.flood(_target)
	_go(&"walk")


func _walk_step() -> void:
	var w := _main.driver.world
	var hud: Hud = _main.get_node("UI/Hud")
	var p := w.player_pos()
	var dir := (_target - p).normalized() if (_target - p).length() < 1.5 else _nav.direction(p)
	var c := InputLatch.C45
	var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
	if hud.card_mode() == &"preview" and not _names.has("card_preview"):
		screen *= 0.0
		if hud.card().modulate.a >= 0.99 and _pending.is_empty():
			print(
				(
					"vfx_cards: preview card '%s' / '%s'"
					% [hud.card().title_text(), hud.card().desc_text()]
				)
			)
			_grab_soon("card_preview")
	if not _pending.is_empty():
		screen *= 0.0
	if hud.card_mode() == &"pickup" and hud.card().modulate.a >= 0.99 and _pending.is_empty():
		screen *= 0.0
		print(
			(
				"vfx_cards: pickup card '%s' / '%s' caption '%s'; icon row %d"
				% [
					hud.card().title_text(),
					hud.card().desc_text(),
					hud.card().caption_text(),
					hud.item_icon_count()
				]
			)
		)
		_grab_soon("card_pickup")
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		_go(&"settle")
		return
	_axis(JOY_AXIS_LEFT_X, screen.x)
	_axis(JOY_AXIS_LEFT_Y, -screen.y)


## Every icon on a tile with its id, and four cards, over the paused game.
func _show_icons() -> void:
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.11, 0.14)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(60, 50)
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 16)
	layer.add_child(grid)
	for id in ItemIcons.IDS + [&"unknown_item"]:
		var cell := VBoxContainer.new()
		var icon := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		icon.custom_minimum_size = Vector2(96, 96)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var l := Label.new()
		l.text = String(id)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(170, 0)
		cell.add_child(l)
		grid.add_child(cell)
	var cards := VBoxContainer.new()
	cards.position = Vector2(1240, 40)
	cards.add_theme_constant_override("separation", 16)
	layer.add_child(cards)
	# Items whose strings this build has (the new items' names and sentences land with their content).
	for id: StringName in [&"long_edge", &"ember_edge", &"overcharge", &"kinetic_dash"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(ItemCard.WIDTH, 100)
		cards.add_child(holder)
		var card := ItemCard.new()
		holder.add_child(card)
		card.place_bottom_centre(0)
		var key := "ITEM_" + String(id).to_upper()
		card.show_item(
			id,
			TranslationServer.translate(key),
			TranslationServer.translate(key + "_DESC"),
			ItemLooks.color_of_id(id)
		)
		card._shown = 1.0
		card.modulate.a = 1.0
	_go(&"icons")


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _reader() -> WorldReader:
	return _main.driver.reader


func _grab_soon(shot: String) -> void:
	_pending = [shot, 2]


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + shot + ".png"
	img.save_png(path)
	_shots.append(img)
	_names.append(shot)
	print("vfx_cards: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


func _save_sheet() -> void:
	var cw := int(_shots[0].get_width() * SHEET_SCALE)
	var ch := int(_shots[0].get_height() * SHEET_SCALE)
	var rows := int(ceil(float(_shots.size()) / SHEET_COLS))
	var sheet := Image.create(cw * SHEET_COLS, ch * rows, false, Image.FORMAT_RGB8)
	for i in _shots.size():
		var img := _shots[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(
			img, Rect2i(0, 0, cw, ch), Vector2i((i % SHEET_COLS) * cw, (i / SHEET_COLS) * ch)
		)
	var path := OUT + "vfx_cards_sheet.png"
	sheet.save_png(path)
	print("vfx_cards: ", path, " ", sheet.get_width(), "x", sheet.get_height(), " ", _names)


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
