class_name ItemCard
extends PanelContainer
## A compact item card (PLAN v0.2.0 L13, owner: "more concise, appear in a smaller card and one small sentence …
## add to the card a symbol"): a dark rounded panel with an item-coloured left edge, the item's icon, its name
## and one short sentence. It fades and slides in when shown and fades out when hidden. It shows text it is given
## (already translated); it decides nothing about the game.

const WIDTH := 330.0
const MIN_HEIGHT := 72.0
const ICON := 56.0
const FADE_S := 0.15
const SLIDE_PX := 14.0

var icon := ItemIconView.new()
## False inside a container (the 3-card pick): the card fades but leaves its position to the container.
var slide := true
var _name := Label.new()
var _caption := Label.new()
var _desc := Label.new()
var _box := StyleBoxFlat.new()
var _showing := false
## 0 (hidden) .. 1 (fully shown); eased toward the target in _process.
var _shown := 0.0
var _rest_bottom := 0.0


func _init() -> void:
	name = "ItemCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, MIN_HEIGHT)
	_box.bg_color = Color(0.03, 0.04, 0.07, 0.82)
	_box.set_corner_radius_all(10)
	_box.border_width_left = 6
	_box.content_margin_left = 14
	_box.content_margin_right = 12
	_box.content_margin_top = 8
	_box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var head := HBoxContainer.new()
	text.add_child(head)
	_name.add_theme_font_size_override("font_size", 21)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	head.add_child(_caption)
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(WIDTH - ICON - 50, 0)
	text.add_child(_desc)
	for l: Label in [_name, _caption, _desc]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## Shows the card for item `id` with already-translated `title` and `sentence`; `caption` is a small note by the
## name (for example "Picked up"), or "".
func show_item(id: StringName, title: String, sentence: String, c: Color, caption := "") -> void:
	icon.set_item(id, c)
	_box.border_color = c
	_name.text = title
	_name.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.35))
	_desc.text = sentence
	_caption.text = caption
	_caption.visible = caption != ""
	if not _showing:
		_showing = true
		visible = true
		_shown = 0.0
		_apply()


func hide_card() -> void:
	_showing = false


func is_showing() -> bool:
	return _showing


func title_text() -> String:
	return _name.text if _showing else ""


func desc_text() -> String:
	return _desc.text if _showing else ""


func caption_text() -> String:
	return _caption.text if _showing else ""


func icon_id() -> StringName:
	return icon.item_id if _showing else &""


## Anchors the card to the bottom centre of its parent, its bottom edge `bottom` px from the parent's bottom
## (negative is up); it slides up to there as it appears and grows upward to fit its text.
func place_bottom_centre(bottom: float) -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	_rest_bottom = bottom
	_apply()


func _process(delta: float) -> void:
	if not visible:
		return
	var target := 1.0 if _showing else 0.0
	_shown = move_toward(_shown, target, minf(delta, 1.0 / 30.0) / FADE_S)
	_apply()
	if not _showing and _shown <= 0.0:
		visible = false


func _apply() -> void:
	modulate.a = _shown
	if not slide:
		return
	offset_bottom = _rest_bottom + SLIDE_PX * (1.0 - _shown) * (1.0 - _shown)
	offset_top = offset_bottom - maxf(size.y, MIN_HEIGHT)
