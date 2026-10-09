class_name SwapPanel
extends Control
## The Swap choice (v0.6.0 MX2; owner B7: "you have a swap button for the next you get and you can decide which one
## to swap"). While the sim waits on a swap (a new modifier offered with the six slots full; WorldReader.swapping),
## it shows the incoming card and the six held modifiers, each with its level, plus Skip. It sends the player's
## answer as input (`picked` → InputLatch.note_pick → InputFrame.pick: PICK_SWAP_BASE + n replaces slot n,
## PICK_SWAP_SKIP skips); it decides nothing (EI-07).
## - Mouse: hover focuses a tile, a click answers with it.
## - Keyboard: 1–6 focus a held modifier, ←/→ (↑/↓) move the focus (Skip is the last), Enter answers, Esc skips.
## - Pad: d-pad or left stick moves the focus, A (Cross) answers, B (Circle) skips.
## It sits over the pick panel and the shop (their input waits while it is open).
## v0.6.0 UP: a modal choice, so it wears the menus' Cold glass (MenuStyle): the game blurred and dimmed behind
## (MenuBackdrop), plain type, each held modifier on a glass tile with its family's colour along the top, the focused
## tile lit by the glass wash and a cold rim. The incoming card keeps the pick cards' look.

signal picked(value: int)

const TILE := Vector2(150, 92)
const SKIP := 6

var input_enabled := true
var _dim := MenuBackdrop.new()
var _title := Label.new()
var _hint := Label.new()
var _card: PickSlot
var _row := HBoxContainer.new()
var _tiles: Array[PanelContainer] = []
var _names: Array[Label] = []
var _levels: Array[Label] = []
var _skip: PanelContainer
var _skip_key: Label
var _skip_name: Label
## The reader last shown (read only), so a language switch words the open panel again (v0.6.0 UP).
var _reader: WorldReader
var _count := 0
var _focus := 0
var _open := false
var _sent := false
var _code := -1


func _init() -> void:
	name = "SwapPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # the game under it takes no clicks
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	centre.add_child(col)
	_title.add_theme_font_override("font", HudStyle.font(true))
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", MenuStyle.TEXT)
	for l: Label in [_title, _hint]:  # the menus' soft outline, readable over the blurred game
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_font_size_override("font_size", MenuStyle.HINT_SIZE)
	_hint.add_theme_color_override("font_color", MenuStyle.HINT)
	for l: Label in [_title, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	var card_box := CenterContainer.new()
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PickSlot.new(0, 0.8)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_key_visible(false)  # v0.6.0 UP: the incoming card has no number key here
	card_box.add_child(_card)
	col.add_child(card_box)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 10)
	col.add_child(_row)
	for k in WorldReader.MOD_SLOTS:
		_tiles.append(_make_tile(k))
	_skip = _make_tile(SKIP)
	col.add_child(_hint)
	visible = false


func _make_tile(k: int) -> PanelContainer:
	var t := PanelContainer.new()
	t.name = "SwapSkip" if k == SKIP else "SwapSlot%d" % (k + 1)
	t.custom_minimum_size = TILE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(box)
	var key := _tile_label(13, false, MenuStyle.DIM)
	key.text = tr("UI_SWAP_SKIP_KEY") if k == SKIP else str(k + 1)
	var nm := _tile_label(15, true, MenuStyle.TEXT)
	var lv := _tile_label(13, false, MenuStyle.DIM)
	for l: Label in [key, nm, lv]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	if k != SKIP:
		_names.append(nm)
		_levels.append(lv)
	else:
		nm.text = tr("UI_SWAP_SKIP")
		_skip_key = key
		_skip_name = nm
	t.gui_input.connect(_on_tile_input.bind(k))
	t.mouse_entered.connect(_set_focus.bind(k))
	_row.add_child(t)
	return t


## A tile's plain-type label (the menus' font, sized and coloured).
static func _tile_label(px: int, bold: bool, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudStyle.font(bold))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	_reader = reader
	if not reader.swapping():
		if _open:
			_open = false
			_sent = false
			visible = false
		return
	var b := reader.build()
	var code := int(b["swap_code"])
	if _open and code == _code:
		return
	_open = true
	_sent = false
	_code = code
	visible = true
	_card.show_card(PickPanel.card_face(self, reader, code))
	var slots: Array = b["slots"]
	_count = slots.size()
	for k in _tiles.size():
		var t := _tiles[k]
		t.visible = k < _count
		if k >= _count:
			continue
		var s: Dictionary = slots[k]
		_names[k].text = tr(s["name_key"])
		var lvl := int(s["level"])
		_levels[k].text = (
			tr("UI_SWAP_LEVEL") % lvl if int(s["type"]) == WorldReader.CARD_ABILITY else ""
		)
		var fam := CardFrames.family(s["id"], int(s["type"]))
		t.set_meta(&"tint", CardFrames.tint(CardFrames.frame_of(fam)))
	_title.text = tr("UI_SWAP_TITLE") % _count
	_hint.text = tr("UI_SWAP_HINT")
	_set_focus(0)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or _skip_name == null:
		return
	_skip_key.text = tr("UI_SWAP_SKIP_KEY")
	_skip_name.text = tr("UI_SWAP_SKIP")
	if _open and _reader != null:  # word the open choice again, keeping its focus and answer
		var f := _focus
		var sent := _sent
		_open = false
		sync(_reader)
		_set_focus(f)
		_sent = sent


## The Skip tile's name (tests).
func skip_text() -> String:
	return _skip_name.text


func is_open() -> bool:
	return _open


func focus_index() -> int:
	return _focus


func slot_count() -> int:
	return _count


## The tile of held slot k (SKIP: the Skip tile), for tests.
func tile(k: int) -> PanelContainer:
	return _skip if k == SKIP else _tiles[k]


func slot_name(k: int) -> String:
	return _names[k].text


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	var step := 0
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_set_focus(event.physical_keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER:
				_answer(_focus)
			KEY_ESCAPE:
				_answer(SKIP)
			KEY_LEFT, KEY_UP:
				step = -1
			KEY_RIGHT, KEY_DOWN:
				step = 1
			_:
				return
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_answer(_focus)
			JOY_BUTTON_B:
				_answer(SKIP)
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP:
				step = -1
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN:
				step = 1
			_:
				return
	elif event is InputEventJoypadMotion:
		if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
			step = -1
		elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
			step = 1
		else:
			return
	else:
		return
	if step != 0:
		_set_focus(_step_from(_focus, step))
	# The pick panel and the shop below don't see what the swap answered.
	get_viewport().set_input_as_handled()


## The next focus from `k` by `step` over the held slots then Skip.
func _step_from(k: int, step: int) -> int:
	var order: Array[int] = []
	for n in _count:
		order.append(n)
	order.append(SKIP)
	var at := maxi(0, order.find(k))
	return order[clampi(at + step, 0, order.size() - 1)]


func _set_focus(k: int) -> void:
	if k != SKIP and (k < 0 or k >= _count):
		return
	_focus = k
	for n in _tiles.size():
		_style(_tiles[n], n == k)
	_style(_skip, k == SKIP)


func _style(t: PanelContainer, on: bool) -> void:
	var tint: Color = t.get_meta(&"tint", MenuStyle.GLASS)
	var box := MenuStyle.glass_panel(Vector2(8, 6))
	box.border_color = Color(tint, 0.9)
	box.border_width_top = 2
	if on:  # the focused tile: the glass wash and a cold rim
		box.bg_color = Color(MenuStyle.GLASS, 0.16)
		box.border_color = MenuStyle.GLASS
		box.set_border_width_all(1)
		box.border_width_top = 2
	t.add_theme_stylebox_override("panel", box)


func _on_tile_input(event: InputEvent, k: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_focus(k)
		_answer(k)


func _answer(k: int) -> void:
	if not _open or not input_enabled or _sent:
		return
	if k != SKIP and (k < 0 or k >= _count):
		return
	_sent = true
	picked.emit(WorldReader.PICK_SWAP_SKIP if k == SKIP else WorldReader.PICK_SWAP_BASE + k)
