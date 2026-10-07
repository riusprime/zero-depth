class_name PickSlot
extends PanelContainer
## One card of the 3-card pick (v0.3.0 E): the compact item card (ItemCard) in a frame coloured by the item's
## rarity, with its number key and rarity above it. The focused slot has a thicker, brighter frame. A mouse click
## or hover reports itself; the panel decides what happens.

signal clicked(slot: int)
signal hovered(slot: int)

const COMMON := Color("#9AA4B2")
const RARE := Color("#F0B840")

var index := 0
var card := ItemCard.new()
var focused := false
var rare := false
var _box := StyleBoxFlat.new()
var _key := Label.new()
var _rarity := Label.new()


func _init(p_index: int) -> void:
	index = p_index
	name = "PickSlot%d" % (p_index + 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box.bg_color = Color(0.02, 0.03, 0.05, 0.55)
	_box.set_corner_radius_all(12)
	_box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_key.text = str(p_index + 1)
	_key.add_theme_font_size_override("font_size", 15)
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_key)
	_rarity.add_theme_font_size_override("font_size", 14)
	head.add_child(_rarity)
	for l: Label in [_key, _rarity]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.slide = false
	col.add_child(card)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit(index))
	_apply()


## Shows item `id` (already-translated title and sentence) with its rarity.
func show_item(
	id: StringName, title: String, sentence: String, c: Color, p_rare: bool, rarity_text: String
) -> void:
	rare = p_rare
	card.show_item(id, title, sentence, c)
	_rarity.text = rarity_text
	_rarity.add_theme_color_override("font_color", RARE if rare else COMMON)
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


func frame_color() -> Color:
	return RARE if rare else COMMON


func _apply() -> void:
	var c := frame_color()
	_box.border_color = c if focused else Color(c, 0.55)
	_box.set_border_width_all(5 if focused else 2)
	_box.bg_color = Color(0.06, 0.07, 0.1, 0.8) if focused else Color(0.02, 0.03, 0.05, 0.55)
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.95 if focused else 0.5))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)
