class_name EventPanel
extends Control
## An event room's panel (v0.5.0 EV, PLAN R3): while the sim waits on an open pedestal, the event's name and line,
## then one card per choice and a last "Leave it" card, in the pick cards' look (CardStyle.current, FACET). Each
## choice card names its cost (red), its reward (the rolled card's own face for a card reward) and, when it carries
## one, its curse (marked in CurseLook.COLOR) before you take it (BLUEPRINT §H). A choice the sim would refuse is
## dimmed with the reason and can't be sent. It shows what the sim offers and sends the player's choice as input
## (`picked` -> InputLatch.note_pick -> InputFrame.pick: 1..n, or PICK_CANCEL for Leave); it decides nothing.
## Keyboard: 1/2/3 or arrows move the focus, Enter takes it, Esc leaves. Pad: d-pad / stick, A takes, B leaves.
## v0.6.1 R1: each choice is one of the owner's wide crystal plaques (PlaqueBox), stacked: the title and the cost on
## the left, the reward and the curse on the right. Its colour is the reward's family (a card's own, the card frames'
## table; Plaques.USE_FAMILY for shards, a chest, overclock, a cleanse and Leave); a choice that carries a curse wears
## the curse colour. The text steps down in size until it fits the plaque's dark panel (en and es).

signal picked(value: int)

## The plaque's size (px at the 1920 x 1080 base) and its two text columns.
const CARD_W := 1060.0
const CARD_H := 180.0
const LEFT_W := 280.0
const COL_GAP := 14
const LINE_GAP := 2
## Each line's starting size (px); a choice that doesn't fit steps every line down together, to MIN_SIZE.
const SIZES := {
	"Key": 15,
	"Title": 20,
	"CostHead": 12,
	"Cost": 15,
	"Block": 14,
	"RewardHead": 12,
	"RewardTitle": 16,
	"Reward": 15,
	"CursedHead": 13,
	"Curse": 14,
}
const BOLD := ["Title", "RewardTitle", "CursedHead"]
const MIN_SIZE := 10
const COST := Color("#FF7A6B")
const GAIN := Color("#8FE3A1")

var input_enabled := true
var _dim := ColorRect.new()
var _title := HudStyle.label(28, true)
var _desc := HudStyle.label(16)
var _hint := HudStyle.label(15)
var _row := VBoxContainer.new()
var _cards: Array[PanelContainer] = []
var _boxes: Array[PlaqueBox] = []
## Per card: how many steps its lines went down to fit (tests).
var _steps := PackedInt32Array()
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
	_row.add_theme_constant_override("separation", 10)
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
	_steps = PackedInt32Array()
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
		"plaque": Plaques.of_use(&"event_shards"),
	}
	var code := reader.event_choice_card(k, c)
	var rv := reader.event_choice_reward_value(k, c)
	match reader.event_choice_reward(k, c):
		WorldReader.EVENT_REWARD_OVERCLOCK:
			out["reward"] = ci.tr("UI_EVENT_REWARD_OVERCLOCK") % rv
			out["plaque"] = Plaques.of_use(&"event_overclock")
		WorldReader.EVENT_REWARD_SHARDS:
			out["reward"] = ci.tr("UI_EVENT_REWARD_SHARDS") % rv
		WorldReader.EVENT_REWARD_CHEST:
			out["reward"] = ci.tr("UI_EVENT_REWARD_CHEST")
			out["plaque"] = Plaques.of_use(&"event_chest")
		WorldReader.EVENT_REWARD_CLEANSE:
			var held := reader.curses_owned()
			var name := (
				ci.tr(reader.curse_name_key(held[held.size() - 1])) if not held.is_empty() else "—"
			)
			out["reward"] = ci.tr("UI_EVENT_REWARD_CLEANSE") % name
			out["plaque"] = Plaques.of_use(&"event_cleanse")
		_:
			if code >= 0:
				var face := PickPanel.card_face(ci, reader, code)
				out["reward_title"] = "%s · %s" % [face["title"], face["tier_text"]]
				out["reward"] = face["sentence"]
				out["color"] = PickSlot.TIERS[clampi(int(face["tier"]), 0, 3)]
				out["plaque"] = Plaques.of_card(face["id"], int(face["type"]), int(face["tier"]))
	var curse := reader.event_choice_curse(k, c)
	if curse >= 0:
		out["curse"] = CurseLook.line(ci, reader, curse)
		out["plaque"] = Plaques.of_family(&"curse")
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
		"plaque": Plaques.of_use(&"event_leave"),
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


func card_box(k: int) -> PlaqueBox:
	return _boxes[k]


## How many size steps card k's lines went down to fit (0: the starting sizes).
func card_steps(k: int) -> int:
	return _steps[k]


## True when card k's two columns fit the plaque's dark panel at the sizes picked (tests).
func card_fits(k: int) -> bool:
	var h := Plaques.content_size(CARD_H, CARD_W).y
	var cols := _columns(_cards[k])
	return (
		_column_height(cols[0], LEFT_W) <= h + 0.5
		and _column_height(cols[1], _right_w()) <= h + 0.5
	)


func card_enabled(k: int) -> bool:
	return _ok[k]


func _add_card(lines: Dictionary, value: int, ok: bool) -> void:
	var k := _cards.size()
	var card := PanelContainer.new()
	card.name = "EventCard%d" % (k + 1)
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var box := Plaques.box(lines["plaque"], CARD_H)
	card.add_theme_stylebox_override("panel", box)
	var cols := HBoxContainer.new()
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", COL_GAP)
	card.add_child(cols)
	var left := _column("Left", LEFT_W)
	var right := _column("Right", _right_w())
	cols.add_child(left)
	cols.add_child(right)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	left.add_child(head)
	head.add_child(_text("Key", str(k + 1), Color(1, 1, 1, 0.55)))
	var title := _text("Title", lines["title"], Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if not String(lines["cost"]).is_empty():
		left.add_child(_text("CostHead", tr("UI_EVENT_COST"), Color(1, 1, 1, 0.5)))
		left.add_child(_text("Cost", lines["cost"], COST))
	if not ok:
		left.add_child(_text("Block", lines["block"], Color(1, 1, 1, 0.6)))
		card.modulate = Color(1, 1, 1, 0.55)
	if value != InputFrame.PICK_CANCEL:
		right.add_child(_text("RewardHead", tr("UI_EVENT_REWARD"), Color(1, 1, 1, 0.5)))
	if not String(lines["reward_title"]).is_empty():
		right.add_child(_text("RewardTitle", lines["reward_title"], lines["color"]))
	right.add_child(_text("Reward", lines["reward"], Color(lines["color"], 0.9)))
	if not String(lines["curse"]).is_empty():
		var row := HBoxContainer.new()
		row.name = "CurseRow"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		var mark := CardMark.new(12.0)
		mark.color = CurseLook.COLOR
		row.add_child(mark)
		row.add_child(_text("CursedHead", tr("UI_CURSED"), CurseLook.COLOR))
		right.add_child(row)
		right.add_child(_text("Curse", lines["curse"], CurseLook.COLOR.lerp(Color.WHITE, 0.3)))
	_steps.append(_fit(card))
	card.gui_input.connect(_on_card_input.bind(k))
	card.mouse_entered.connect(_set_focus.bind(k))
	_row.add_child(card)
	_cards.append(card)
	_boxes.append(box)
	_values.append(value)
	_ok.append(ok)


func _column(col_name: String, width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = col_name
	col.custom_minimum_size = Vector2(width, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", LINE_GAP)
	return col


static func _right_w() -> float:
	return Plaques.content_size(CARD_H, CARD_W).x - LEFT_W - COL_GAP


func _text(line_name: String, text: String, c: Color) -> Label:
	var l := HudStyle.label(SIZES[line_name], BOLD.has(line_name))
	l.name = line_name
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("line_spacing", 0)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Steps every line of `card` down together until both columns fit the plaque's dark panel; returns the steps.
func _fit(card: PanelContainer) -> int:
	var h := Plaques.content_size(CARD_H, CARD_W).y
	var cols := _columns(card)
	var step := 0
	while true:
		for l: Label in card.find_children("*", "Label", true, false):
			l.add_theme_font_size_override(
				"font_size", maxi(MIN_SIZE, SIZES[String(l.name)] - step)
			)
		var fit := _column_height(cols[0], LEFT_W) <= h and _column_height(cols[1], _right_w()) <= h
		if fit or step >= 8:
			break
		step += 1
	for col: VBoxContainer in cols:
		var w := col.custom_minimum_size.x
		for l: Label in col.get_children().filter(func(n: Node) -> bool: return n is Label):
			l.custom_minimum_size = Vector2(w, 0)
	var title := card.find_child("Title", true, false) as Label
	var key := card.find_child("Key", true, false) as Label
	title.custom_minimum_size = Vector2(LEFT_W - _width(key) - 8.0, 0)
	return step


func _columns(card: PanelContainer) -> Array:
	return [card.find_child("Left", true, false), card.find_child("Right", true, false)]


## A column's height (px) with its lines wrapped to `w`.
func _column_height(col: VBoxContainer, w: float) -> float:
	var h := 0.0
	var n := 0
	for c in col.get_children():
		var line_h := 0.0
		if c is Label:
			line_h = _label_height(c, w)
		else:  # the head (key + title) or the curse row (mark + head)
			var used := 0.0
			for d in c.get_children():
				if d is Label and String(d.name) != "Title":
					used += _width(d) + 8.0
			for d in c.get_children():
				if d is Label:
					var dw: float = w - used if String(d.name) == "Title" else _width(d)
					line_h = maxf(line_h, _label_height(d, dw))
				elif d is Control:
					line_h = maxf(line_h, (d as Control).custom_minimum_size.y)
		h += line_h
		n += 1
	return h + LINE_GAP * maxi(0, n - 1)


func _label_height(l: Label, w: float) -> float:
	var f := l.get_theme_font("font")
	var s := l.get_theme_font_size("font_size")
	return maxf(f.get_height(s), CrystalCard.text_height(f, l.text, w, s))


func _width(l: Label) -> float:
	var f := l.get_theme_font("font")
	return (
		f
		. get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size"))
		. x
	)


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
		_boxes[j].set_focused(j == k)


## Sends card k's value, unless the sim would refuse it (the card already says why).
func _take(k: int) -> void:
	if k >= 0 and k < _cards.size() and _ok[k]:
		_send(_values[k])


func _send(value: int) -> void:
	_sent = true
	picked.emit(value)
