class_name PickPanel
extends Control
## The 3-card pick (v0.3.0 E, owner line L9): while the sim waits on an open altar or chest, three compact item
## cards (PickSlot: flat square panels with a rarity mark since v0.3.5 F16), a title (the chest's price) and a
## hint. It shows what the sim offers and sends the player's choice as input (the `picked` signal →
## InputLatch.note_pick → InputFrame.pick); it decides nothing itself.
## - Mouse: hover focuses a card, a click takes it.
## - Keyboard: ←/→ (or 1/2/3) moves the focus, Enter takes it, Esc leaves the choice for later.
## - Pad: d-pad or left stick moves the focus, A (Cross) takes it, B (Circle) leaves.
## Space (dash) never confirms: the panel doesn't use ui_accept.
## Layouts (G2 mockups for the owner): ROW_CENTRE ships as the default.

signal picked(value: int)

enum Layout { ROW_CENTRE, ROW_LOW, COLUMN_RIGHT }

const SLOTS := 3

var layout := Layout.ROW_CENTRE
## Off while a menu (pause) sits over the panel.
var input_enabled := true
var _dim := ColorRect.new()
var _title := Label.new()
var _price_icon := ShardIcon.new(26.0)
var _hint := Label.new()
var _slots: Array[PickSlot] = []
var _count := 0
var _focus := 0
var _reward := -1
var _sent := false
var _open := false


func _init(p_layout: Layout = Layout.ROW_CENTRE) -> void:
	layout = p_layout
	name = "PickPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.18 if layout == Layout.ROW_LOW else 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	head.add_child(_title)
	head.add_child(_price_icon)
	_price_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var cards: BoxContainer = (
		VBoxContainer.new() if layout == Layout.COLUMN_RIGHT else HBoxContainer.new()
	)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 18)
	col.add_child(cards)
	col.add_child(_hint)
	HudStyle.style_label(_title, 26, true)  # v0.3.5 F16: the HUD's plain type
	HudStyle.style_label(_hint, 15)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	for l: Label in [_title, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in SLOTS:
		var s := PickSlot.new(k)
		s.clicked.connect(_on_clicked)
		s.hovered.connect(_set_focus)
		cards.add_child(s)
		_slots.append(s)
	_place(col)
	visible = false


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	if not reader.choosing():
		if _open:
			_open = false
			_sent = false
			visible = false
		return
	var r := reader.choice_reward()
	var rid := reader.reward_id(r)
	if _open and rid == _reward:
		return
	_open = true
	_sent = false
	_reward = rid
	visible = true
	var items := reader.choice_items()
	_count = items.size()
	for k in SLOTS:
		var s := _slots[k]
		s.visible = k < _count
		if k >= _count:
			continue
		var idx := items[k]
		var id := reader.item_id(idx)
		var rare := reader.item_rarity(idx) == WorldReader.RARITY_RARE
		s.show_item(
			id,
			tr(reader.item_name_key(idx)),
			tr(reader.item_desc_key(idx)),
			ItemLooks.color_of_id(id),
			rare,
			tr("RARITY_RARE") if rare else tr("RARITY_COMMON")
		)
	var chest := reader.reward_kind(r) == WorldReader.REWARD_CHEST
	_title.text = (
		tr("PICK_TITLE_CHEST") % reader.reward_price(r) if chest else tr("PICK_TITLE_ALTAR")
	)
	_price_icon.visible = chest
	_hint.text = tr("PICK_HINT")
	_set_focus(0)


func is_open() -> bool:
	return _open


func focus_index() -> int:
	return _focus


func card_count() -> int:
	return _count


func slot(k: int) -> PickSlot:
	return _slots[k]


func title_text() -> String:
	return _title.text


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	var step := 0
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_set_focus(event.physical_keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER:
				_send(_focus + 1)
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
				_send(_focus + 1)
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
		_set_focus(clampi(_focus + step, 0, maxi(0, _count - 1)))
	get_viewport().set_input_as_handled()


func _set_focus(k: int) -> void:
	if k < 0 or k >= _count:
		return
	_focus = k
	for s in _slots:
		s.set_focused(s.index == k)


func _on_clicked(k: int) -> void:
	if not _open or not input_enabled or _sent or k >= _count:
		return
	_set_focus(k)
	_send(k + 1)


func _send(value: int) -> void:
	_sent = true
	picked.emit(value)


func _place(col: VBoxContainer) -> void:
	match layout:
		Layout.ROW_CENTRE:
			var centre := CenterContainer.new()
			centre.set_anchors_preset(Control.PRESET_FULL_RECT)
			centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(centre)
			centre.add_child(col)
		Layout.ROW_LOW:
			add_child(col)
			col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			col.grow_horizontal = Control.GROW_DIRECTION_BOTH
			col.grow_vertical = Control.GROW_DIRECTION_BEGIN
			col.offset_bottom = -190
		Layout.COLUMN_RIGHT:
			add_child(col)
			col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			col.grow_vertical = Control.GROW_DIRECTION_BOTH
			col.offset_right = -40
