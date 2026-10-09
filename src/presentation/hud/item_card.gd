class_name ItemCard
extends PanelContainer
## A compact item card (PLAN v0.2.0 L13, owner: "more concise, appear in a smaller card and one small sentence … add to
## the card a symbol"): the item's icon, its name in its colour and one short sentence. It fades and slides in when
## shown and fades out when hidden. It shows text it is given (already translated); it decides nothing about the game.
## v0.6.1 R1: the card is one of the owner's wide crystal plaques (Plaques, a nine-slice PlaqueBox) in the card's
## family colour (CardFrames.family, the card frames' table); the name and the sentence step down in size until they
## fit the plaque's dark panel (en and es).

const WIDTH := 600.0
## The plaque's height at its natural scale (px at the 1920 x 1080 base).
const HEIGHT := 132.0
const MIN_HEIGHT := HEIGHT
## A sentence too long for the plaque at the smallest size grows the plaque through these sizes (width, height): the
## crystals scale with the height, the plain middle takes the width (a long ability sentence).
const GROW := [
	Vector2(600, 132), Vector2(680, 140), Vector2(760, 148), Vector2(860, 156), Vector2(960, 164)
]
const ICON := 44.0
const GAP := 12
const PAD := 4.0
const NAME_SIZES := [21, 20, 19, 18, 17, 16, 15]
const DESC_SIZES := [15, 14, 13, 12]
const CAPTION_SIZE := 13
const FADE_S := 0.15
const SLIDE_PX := 14.0

var icon := ItemIconView.new()
## False inside a container (the 3-card pick): the card fades but leaves its position to the container.
var slide := true
## Sizes picked by the last layout (tests check the text fits).
var name_size := 0
var desc_size := 0
var _name := Label.new()
var _caption := Label.new()
var _desc := Label.new()
var _box := Plaques.box(&"amber", HEIGHT, PAD)
## The plaque's size now (WIDTH x HEIGHT, or a GROW step for a long ability sentence).
var _height := HEIGHT
var _width := WIDTH
var _placed := false
var _showing := false
## 0 (hidden) .. 1 (fully shown); eased toward the target in _process.
var _shown := 0.0
var _rest_bottom := 0.0


func _init() -> void:
	name = "ItemCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(WIDTH, MIN_HEIGHT)
	add_theme_stylebox_override("panel", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
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
	_name.name = "Title"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_override("font", HudStyle.font(true))
	_caption.add_theme_font_override("font", HudStyle.font(false))
	_caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	head.add_child(_caption)
	_desc.name = "Desc"
	_desc.add_theme_font_override("font", HudStyle.font(false))
	_desc.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_desc)
	for l: Label in [_name, _caption, _desc]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_constant_override("line_spacing", 0)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## Shows the card for item `id` with already-translated `title` and `sentence`; `caption` is a small note by the
## name (for example "Picked up"), or "". `plaque` picks the plaque's colour (default: the card's family).
func show_item(
	id: StringName, title: String, sentence: String, c: Color, caption := "", plaque := &""
) -> void:
	icon.set_item(id, c)
	_box.set_plaque(plaque if plaque != &"" else Plaques.of_card(id))
	_name.text = title
	_name.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.35))
	_desc.text = sentence
	_caption.text = caption
	_caption.visible = caption != ""
	_fit()
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


## The plaque this card is drawn on.
func plaque_box() -> PlaqueBox:
	return _box


## The text column's size (px): the plaque's text box less the icon.
func text_box() -> Vector2:
	var c := Plaques.content_size(_height, _width, PAD)
	return Vector2(c.x - ICON - GAP, c.y)


## True when the name (one line beside the caption) and the sentence fit the plaque's text box at the sizes picked.
func text_fits() -> bool:
	var box := text_box()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var name_w := box.x - _caption_w()
	var one_line := bold.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var h := (
		bold.get_height(name_size) + CrystalCard.text_height(regular, _desc.text, box.x, desc_size)
	)
	return one_line <= name_w + 0.5 and h <= box.y + 0.5


## The plaque's height now (px).
func plaque_height() -> float:
	return _height


## The plaque's width now (px).
func plaque_width() -> float:
	return _width


## Picks the smallest plaque (GROW) at which the text fits, and the sizes that fit it.
func _fit() -> void:
	for g: Vector2 in GROW:
		_width = g.x
		_height = g.y
		_fit_sizes()
		if text_fits():
			break
	if not is_equal_approx(_box.scale_factor, _height / Plaques.SIZE.y):
		var plaque := _box.plaque
		_box = Plaques.box(plaque, _height, PAD)
		add_theme_stylebox_override("panel", _box)
	custom_minimum_size = Vector2(_width, _height)
	size = custom_minimum_size  # shrink back after a larger card
	if _placed:
		offset_left = -_width * 0.5
		offset_right = _width * 0.5


## Picks the largest name and sentence sizes that fit the plaque's text box at its height now.
func _fit_sizes() -> void:
	var box := text_box()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var name_w := box.x - _caption_w()
	name_size = NAME_SIZES[NAME_SIZES.size() - 1]
	for s: int in NAME_SIZES:
		if bold.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= name_w:
			name_size = s
			break
	var room := box.y - bold.get_height(name_size)
	desc_size = CrystalCard.fit_size(regular, _desc.text, box.x, room, DESC_SIZES)
	_name.add_theme_font_size_override("font_size", name_size)
	_desc.add_theme_font_size_override("font_size", desc_size)
	_desc.custom_minimum_size = Vector2(box.x, 0)


func _caption_w() -> float:
	if _caption.text.is_empty():
		return 0.0
	var f := HudStyle.font(false)
	return f.get_string_size(_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x + 8.0


## Anchors the card to the bottom centre of its parent, its bottom edge `bottom` px from the parent's bottom
## (negative is up); it slides up to there as it appears and grows upward to fit its text.
func place_bottom_centre(bottom: float) -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_placed = true
	offset_left = -_width * 0.5
	offset_right = _width * 0.5
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
	offset_top = offset_bottom - maxf(_height, MIN_HEIGHT)
