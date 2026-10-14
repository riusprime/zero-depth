class_name AscensionPanel
extends Control
## v0.7.5 AP (owner N4): the Ascension portal's choice. While the sim waits on it (WorldReader.ascension_open), a
## title, a line and three stone plaques (crystal until v0.8.0 MU), stacked: End the run (gold: the run is won, the
## recap), Ascend (violet: the next loop, floor 1, your build kept, harder) and Not yet (silver: step back). It shows
## what the sim offers and sends the player's choice as input (`picked` -> InputLatch.note_pick -> InputFrame.pick:
## WorldReader.PICK_ASCEND_END, PICK_ASCEND_ASCEND, or PICK_CANCEL for Not yet); it decides nothing (EI-07). Keyboard:
## 1/2/3 or arrows move the focus, Enter takes it, Esc is Not yet. Pad: d-pad / stick, A takes, B is Not yet. A mouse
## click takes a plaque.

signal picked(value: int)

const CARD_W := 860.0
const CARD_H := 132.0
const TITLE_GOLD := Color("#FFE6A3")
const LINE_COLOR := Color(1, 1, 1, 0.8)
## Each choice: node name, plaque (a colour id, Plaques), value sent, title and line keys.
const CHOICES := [
	["End", &"gold", WorldReader.PICK_ASCEND_END, "UI_ASCEND_END", "UI_ASCEND_END_LINE"],
	["Ascend", &"violet", WorldReader.PICK_ASCEND_ASCEND, "UI_ASCEND_GO", "UI_ASCEND_GO_LINE"],
	["NotYet", &"silver", InputFrame.PICK_CANCEL, "UI_ASCEND_NOT_YET", "UI_ASCEND_NOT_YET_LINE"],
]

var input_enabled := true
var _dim := ColorRect.new()
var _title := HudStyle.label(30, true)
var _desc := HudStyle.label(17)
var _hint := HudStyle.label(15)
var _col := VBoxContainer.new()
var _cards: Array[PanelContainer] = []
var _boxes: Array[PlaqueBox] = []
var _focus := 0
var _open := false
var _sent := false
## The loop the run is on (the Ascend line names the next one).
var _loop := 1


func _init() -> void:
	name = "AscensionPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.01, 0.08, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 10)
	centre.add_child(_col)
	for l: Label in [_title, _desc, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.name = "Title"
	_desc.name = "Line"
	_hint.name = "Hint"
	_title.add_theme_color_override("font_color", TITLE_GOLD)
	_desc.add_theme_color_override("font_color", LINE_COLOR)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(CARD_W, 0)
	_col.add_child(_title)
	_col.add_child(_desc)
	for c: Array in CHOICES:
		_add_card(c)
	_col.add_child(_hint)
	visible = false


## Opens or closes from the sim's state (after every tick).
func sync(reader: WorldReader) -> void:
	if not reader.ascension_open():
		if _open:
			_open = false
			_sent = false
			visible = false
		return
	if _open:
		return
	_open = true
	_sent = false
	_loop = reader.loop()
	visible = true
	_word()
	_set_focus(0)


## The words in the language now (again on a language switch while it shows).
func _word() -> void:
	_title.text = tr("UI_ASCEND_TITLE")
	_desc.text = tr("UI_ASCEND_LINE")
	_hint.text = tr("UI_ASCEND_HINT")
	for k in _cards.size():
		var c: Array = CHOICES[k]
		(_cards[k].find_child("Title", true, false) as Label).text = tr(c[3])
		var line := tr(c[4])
		if c[0] == "Ascend":
			line = line % (_loop + 1)
		(_cards[k].find_child("Line", true, false) as Label).text = line


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _open:
		_word()


func is_open() -> bool:
	return _open


func card_count() -> int:
	return _cards.size()


func focus_index() -> int:
	return _focus


## Card k's text by line name ("Title", "Line"), for tests and the shot script.
func card_text(k: int, line_name: String) -> String:
	var l := _cards[k].find_child(line_name, true, false) as Label
	return l.text if l != null else ""


func title_text() -> String:
	return _title.text


func _add_card(c: Array) -> void:
	var k := _cards.size()
	var card := PanelContainer.new()
	card.name = "Ascension%s" % c[0]
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var box := Plaques.box(c[1], CARD_H)
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var key := HudStyle.label(16)
	key.name = "Key"
	key.text = str(k + 1)
	key.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	head.add_child(key)
	var title := HudStyle.label(21, true)
	title.name = "Title"
	title.add_theme_color_override("font_color", Color.WHITE)
	head.add_child(title)
	var line := HudStyle.label(15)
	line.name = "Line"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(Plaques.content_size(CARD_H, CARD_W).x, 0)
	line.add_theme_color_override("font_color", Plaques.tint(c[1]).lerp(Color.WHITE, 0.55))
	col.add_child(line)
	card.gui_input.connect(_on_card_input.bind(k))
	card.mouse_entered.connect(_set_focus.bind(k))
	_col.add_child(card)
	_cards.append(card)
	_boxes.append(box)


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_set_focus(event.physical_keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER:
				_take(_focus)
			KEY_ESCAPE:
				_send(InputFrame.PICK_CANCEL)
			KEY_LEFT, KEY_UP:
				step = -1
			KEY_RIGHT, KEY_DOWN:
				step = 1
			_:
				return
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_take(_focus)
			JOY_BUTTON_B:
				_send(InputFrame.PICK_CANCEL)
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
		_set_focus(clampi(_focus + step, 0, _cards.size() - 1))
	get_viewport().set_input_as_handled()


func _on_card_input(event: InputEvent, k: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _open and input_enabled and not _sent:
			_set_focus(k)
			_take(k)


func _set_focus(k: int) -> void:
	if k < 0 or k >= _cards.size():
		return
	_focus = k
	for j in _cards.size():
		_boxes[j].set_focused(j == k)


func _take(k: int) -> void:
	if k >= 0 and k < _cards.size():
		_send(CHOICES[k][2])


func _send(value: int) -> void:
	_sent = true
	picked.emit(value)
