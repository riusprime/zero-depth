class_name EventPanel
extends Control
## An event room's panel (v0.5.0 EV, PLAN R3): while the sim waits on an open pedestal, the event's name and line,
## then one card per choice and a last "Leave it" card, in the pick cards' look (CardStyle.current, FACET). Each
## choice card names its cost (red), its reward (the rolled card's own face for a card reward) and, when it carries
## one, its curse (marked in CurseLook.COLOR) before you take it (BLUEPRINT §H). A choice the sim would refuse is
## dimmed with the reason and can't be sent. It shows what the sim offers and sends the player's choice as input
## (`picked` -> InputLatch.note_pick -> InputFrame.pick: 1..n, or PICK_CANCEL for Leave); it decides nothing.
## Keyboard: 1/2/3 or arrows move the focus, Enter takes it, Esc leaves. Pad: d-pad / stick, A takes, B leaves.

signal picked(value: int)

const CARD_W := 270.0
const COST := Color("#FF7A6B")
const GAIN := Color("#8FE3A1")

var input_enabled := true
var _dim := ColorRect.new()
var _title := HudStyle.label(28, true)
var _desc := HudStyle.label(16)
var _hint := HudStyle.label(15)
var _row := HBoxContainer.new()
var _cards: Array[PanelContainer] = []
var _boxes: Array[StyleBoxFlat] = []
## Per card: the value sent (1..n or PICK_CANCEL) and whether the sim would take it.
var _values := PackedInt32Array()
var _ok: Array[bool] = []
var _focus := 0
var _open := false
var _sent := false
var _pedestal := -1


func _init() -> void:
	name = "EventPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	centre.add_child(col)
	for l: Label in [_title, _desc, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", EventPedestalViews.GLOW.lerp(Color.WHITE, 0.35))
	_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(_title)
	col.add_child(_desc)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 18)
	col.add_child(_row)
	col.add_child(_hint)
	visible = false


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	if not reader.event_open():
		if _open:
			_open = false
			_sent = false
			visible = false
		return
	var k := reader.event_open_index()
	if _open and k == _pedestal:
		return
	_open = true
	_sent = false
	_pedestal = k
	visible = true
	_title.text = tr(reader.event_name_key(k))
	_desc.text = tr(reader.event_desc_key(k))
	_hint.text = tr("UI_EVENT_HINT")
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_cards.clear()
	_boxes.clear()
	_values = PackedInt32Array()
	_ok.clear()
	for c in reader.event_choice_count(k):
		var ok := reader.event_choice_block(k, c) == WorldReader.EVENT_BLOCK_OK
		_add_card(choice_lines(self, reader, k, c), c + 1, ok)
	_add_card(leave_lines(self), InputFrame.PICK_CANCEL, true)
	_set_focus(0)


## What choice c's card says (translated through `ci`): title, cost, reward title and line, its colour, the curse
## line ("" none) and the refusal ("" when it can be taken).
static func choice_lines(ci: Object, reader: WorldReader, k: int, c: int) -> Dictionary:
	var v := reader.event_choice_cost_value(k, c)
	var cost := ""
	match reader.event_choice_cost(k, c):
		WorldReader.EVENT_COST_HP:
			cost = ci.tr("UI_EVENT_COST_HP") % v
		WorldReader.EVENT_COST_MAX_HP:
			cost = ci.tr("UI_EVENT_COST_MAX_HP") % v
		WorldReader.EVENT_COST_SHARDS:
			cost = ci.tr("UI_EVENT_COST_SHARDS") % v
		WorldReader.EVENT_COST_OVERHEAT:
			cost = ci.tr("UI_EVENT_COST_OVERHEAT")
		WorldReader.EVENT_COST_FIGHT:
			cost = ci.tr("UI_EVENT_COST_FIGHT") % v
		WorldReader.EVENT_COST_DEFEND:
			cost = ci.tr("UI_EVENT_COST_DEFEND") % v
		_:
			cost = ci.tr("UI_EVENT_COST_NONE")
	var out := {
		"title": ci.tr(reader.event_choice_label(k, c)),
		"cost": cost,
		"reward_title": "",
		"reward": "",
		"color": GAIN,
		"curse": "",
		"block": "",
	}
	var code := reader.event_choice_card(k, c)
	var rv := reader.event_choice_reward_value(k, c)
	match reader.event_choice_reward(k, c):
		WorldReader.EVENT_REWARD_OVERCLOCK:
			out["reward"] = ci.tr("UI_EVENT_REWARD_OVERCLOCK") % rv
		WorldReader.EVENT_REWARD_SHARDS:
			out["reward"] = ci.tr("UI_EVENT_REWARD_SHARDS") % rv
		WorldReader.EVENT_REWARD_CHEST:
			out["reward"] = ci.tr("UI_EVENT_REWARD_CHEST")
		WorldReader.EVENT_REWARD_CLEANSE:
			var held := reader.curses_owned()
			var name := (
				ci.tr(reader.curse_name_key(held[held.size() - 1])) if not held.is_empty() else "—"
			)
			out["reward"] = ci.tr("UI_EVENT_REWARD_CLEANSE") % name
		_:
			if code >= 0:
				var face := PickPanel.card_face(ci, reader, code)
				out["reward_title"] = "%s · %s" % [face["title"], face["tier_text"]]
				out["reward"] = face["sentence"]
				out["color"] = PickSlot.TIERS[clampi(int(face["tier"]), 0, 3)]
	var curse := reader.event_choice_curse(k, c)
	if curse >= 0:
		out["curse"] = CurseLook.line(ci, reader, curse)
	match reader.event_choice_block(k, c):
		WorldReader.EVENT_BLOCK_SHARDS:
			out["block"] = ci.tr("UI_EVENT_BLOCK_SHARDS")
		WorldReader.EVENT_BLOCK_NOTHING:
			out["block"] = ci.tr("UI_EVENT_BLOCK_NOTHING")
		WorldReader.EVENT_BLOCK_BUSY:
			out["block"] = ci.tr("UI_EVENT_BLOCK_BUSY")
	return out


static func leave_lines(ci: Object) -> Dictionary:
	return {
		"title": ci.tr("UI_EVENT_LEAVE"),
		"cost": "",
		"reward_title": "",
		"reward": ci.tr("UI_EVENT_LEAVE_DESC"),
		"color": Color(1, 1, 1, 0.7),
		"curse": "",
		"block": "",
	}


func is_open() -> bool:
	return _open


func card_count() -> int:
	return _cards.size()


func focus_index() -> int:
	return _focus


## Card k's texts, by line name (title, cost, reward, curse, block), for tests and the shot script.
func card_text(k: int, line_name: String) -> String:
	var l := _cards[k].find_child(line_name, true, false) as Label
	return l.text if l != null and l.visible else ""


func card_box(k: int) -> StyleBoxFlat:
	return _boxes[k]


func card_enabled(k: int) -> bool:
	return _ok[k]


func _add_card(lines: Dictionary, value: int, ok: bool) -> void:
	var k := _cards.size()
	var card := PanelContainer.new()
	card.name = "EventCard%d" % (k + 1)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := CardStyle.box(Vector4(14, 10, 14, 12))
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	head.add_child(_text("Key", str(k + 1), 15, Color(1, 1, 1, 0.55)))
	var title := _text("Title", lines["title"], 20, Color.WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if not String(lines["cost"]).is_empty():
		col.add_child(_text("CostHead", tr("UI_EVENT_COST"), 12, Color(1, 1, 1, 0.5)))
		col.add_child(_text("Cost", lines["cost"], 15, COST))
	if value != InputFrame.PICK_CANCEL:
		col.add_child(_text("RewardHead", tr("UI_EVENT_REWARD"), 12, Color(1, 1, 1, 0.5)))
	if not String(lines["reward_title"]).is_empty():
		col.add_child(_text("RewardTitle", lines["reward_title"], 16, lines["color"], true))
	col.add_child(_text("Reward", lines["reward"], 15, Color(lines["color"], 0.9)))
	if not String(lines["curse"]).is_empty():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		var mark := CardMark.new(12.0)
		mark.color = CurseLook.COLOR
		row.add_child(mark)
		row.add_child(_text("CursedHead", tr("UI_CURSED"), 13, CurseLook.COLOR, true))
		col.add_child(row)
		col.add_child(_text("Curse", lines["curse"], 14, CurseLook.COLOR.lerp(Color.WHITE, 0.3)))
	if not ok:
		col.add_child(_text("Block", lines["block"], 14, Color(1, 1, 1, 0.6)))
		card.modulate = Color(1, 1, 1, 0.55)
	card.gui_input.connect(_on_card_input.bind(k))
	card.mouse_entered.connect(_set_focus.bind(k))
	_row.add_child(card)
	_cards.append(card)
	_boxes.append(box)
	_values.append(value)
	_ok.append(ok)


func _text(line_name: String, text: String, px: int, c: Color, bold: bool = false) -> Label:
	var l := HudStyle.label(px, bold)
	l.name = line_name
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_W - 40.0, 0)
	l.add_theme_color_override("font_color", c)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
		_set_focus(clampi(_focus + step, 0, maxi(0, _cards.size() - 1)))
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
		CardStyle.apply(_boxes[j], EventPedestalViews.GLOW, j == k)


## Sends card k's value, unless the sim would refuse it (the card already says why).
func _take(k: int) -> void:
	if k >= 0 and k < _cards.size() and _ok[k]:
		_send(_values[k])


func _send(value: int) -> void:
	_sent = true
	picked.emit(value)
