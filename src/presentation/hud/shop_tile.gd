class_name ShopTile
extends PanelContainer
## One button of the shop panel (v0.5.0 SH): the heal, the reroll or a salvage row. A title, and under it a detail line
## and a price or refund with the shard icon. A disabled tile is dimmed and its price turns red when you can't afford
## it. A mouse click or hover reports itself; the panel decides.
## v0.6.1 R1: the tile is one of the owner's crystal plaques (PlaqueBox): a salvage row in its card's family colour,
## the heal green, the reroll amber, the cleanse violet (Plaques.USE_FAMILY); the focused tile is drawn bright. The
## title and the detail step down in size until they fit the plaque's dark panel (en and es).

signal clicked
signal hovered

const POOR := Color("#FF5A4D")
const REFUND := Color("#9CF29C")
## The plaque's height (px at the 1920 x 1080 base) and the gap inside it.
const HEIGHT := 90.0
const PAD := 2.0
const TITLE_SIZES := [17, 16, 15, 14, 13, 12]
const DETAIL_SIZES := [13, 12, 11]
const PRICE_SIZE := 15
const ICON := 16.0

var enabled := true
var focused := false
var title := Label.new()
var detail := Label.new()
var price := Label.new()
## Sizes picked by the last fit (tests check the text fits).
var title_size := 0
var detail_size := 0
var _width := 0.0
var _box := Plaques.box(&"amber", HEIGHT, PAD)
var _icon := ShardIcon.new(ICON)
var _accent := CardStyle.EDGE


## `width` is the tile's width (px).
func _init(p_name: String, width: float = 340.0) -> void:
	name = p_name
	_width = width
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(width, HEIGHT)
	add_theme_stylebox_override("panel", _box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(detail)
	row.add_child(_icon)
	row.add_child(price)
	col.add_child(row)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HudStyle.style_label(title, TITLE_SIZES[0], true)
	HudStyle.style_label(detail, DETAIL_SIZES[0])
	HudStyle.style_label(price, PRICE_SIZE, true)
	for l: Label in [title, detail, price]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	detail.clip_text = true
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit())
	_apply()


## Shows the tile: `amount` shards (a cost, or a refund with `refund`), `poor` when it can't be afforded; `plaque` its
## crystal plaque's colour.
func show_tile(
	p_title: String,
	p_detail: String,
	amount: int,
	p_enabled: bool,
	poor: bool = false,
	refund: bool = false,
	accent: Color = CardStyle.EDGE,
	plaque: StringName = &"amber"
) -> void:
	title.text = p_title
	detail.text = p_detail
	price.text = ("+%d" % amount) if refund else str(amount)
	price.visible = amount > 0
	_icon.visible = amount > 0
	price.add_theme_color_override(
		"font_color", POOR if poor else (REFUND if refund else Color.WHITE)
	)
	enabled = p_enabled
	_accent = accent
	_box.set_plaque(plaque)
	_fit()
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


func panel_box() -> PlaqueBox:
	return _box


## The plaque's text box (px).
func text_box() -> Vector2:
	return Plaques.content_size(HEIGHT, _width, PAD)


## True when the title (one line) and the detail beside the price fit the plaque's text box (tests).
func text_fits() -> bool:
	var box := text_box()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var tw := bold.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var dw := regular.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x
	var h := (
		bold.get_height(title_size)
		+ maxf(regular.get_height(detail_size), bold.get_height(PRICE_SIZE))
	)
	return tw <= box.x + 0.5 and dw <= box.x - _price_w() + 0.5 and h <= box.y + 0.5


func _price_w() -> float:
	if not price.visible:
		return 0.0
	var bold := HudStyle.font(true)
	return (
		ICON + 12.0 + bold.get_string_size(price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
	)


func _fit() -> void:
	var box := text_box()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var row_h := maxf(regular.get_height(DETAIL_SIZES[0]), bold.get_height(PRICE_SIZE))
	title_size = TITLE_SIZES[TITLE_SIZES.size() - 1]
	for s: int in TITLE_SIZES:
		var wide := bold.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		if wide <= box.x and bold.get_height(s) + row_h <= box.y:
			title_size = s
			break
	detail_size = DETAIL_SIZES[DETAIL_SIZES.size() - 1]
	for s: int in DETAIL_SIZES:
		if (
			regular.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
			<= box.x - _price_w()
		):
			detail_size = s
			break
	title.add_theme_font_size_override("font_size", title_size)
	detail.add_theme_font_size_override("font_size", detail_size)
	title.custom_minimum_size = Vector2(box.x, 0)


func _apply() -> void:
	_box.set_focused(focused)
	modulate = Color(1, 1, 1, 1.0 if enabled else 0.45)
	title.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.55))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()
