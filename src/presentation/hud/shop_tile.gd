class_name ShopTile
extends PanelContainer
## One button of the shop panel (v0.5.0 SH): the heal or the reroll (a salvage row until v0.10.5 W3-O9). A title,
## a detail line under it, and a price or refund with the shard icon. A disabled tile is dimmed and its price
## turns red when you can't afford it. A mouse click or hover reports itself; the panel decides.
## v0.10.5 W3-O16 (owner 2026-11-04, the shop's layout A in the Astral style): a wide Astral plate (AstralChrome.plate:
## a slim lozenge, a star off each tip), its icon in a thin ring at the left (`icon_kind`: &"heal" or &"reroll"), the
## title in letter-spaced Cinzel capitals, and the price BIG at the right with Astral's shard. Focus follows Astral's
## rules (the contour brightens, a second contour 6 px outside, the tip stars light). The title and the detail step
## down in size until they fit beside the price (en and es).

signal clicked
signal hovered

const POOR := AstralCardArt.POOR
const REFUND := Color("#B4E0C8")
## The plate's height (px at the 1920 x 1080 base), its padding inside the tips, the icon's ring and the gaps.
const HEIGHT := 64.0
const PAD_Y := 6.0
const ICON := 40.0
const SEP := 16.0
const TITLE_SIZES := [18, 17, 16, 15, 14, 13, 12]
const DETAIL_SIZES := [13, 12, 11]
const PRICE_SIZE := 30
const SHARD := 26.0

var enabled := true
var focused := false
## The icon in the plate's ring: &"heal", &"reroll", or none (a small diamond).
var icon_kind := &"":
	set(v):
		icon_kind = v
		_icon.queue_redraw()
var title := Label.new()
var detail := Label.new()
var price := Label.new()
## Sizes picked by the last fit (tests check the text fits).
var title_size := 0
var detail_size := 0
var _width := 0.0
var _icon := Control.new()
var _shard := ShardIcon.new(SHARD, true)


## `width` is the tile's width (px).
func _init(p_name: String, width: float = 528.0) -> void:
	name = p_name
	_width = width
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(width, HEIGHT)
	var box := StyleBoxEmpty.new()
	var side := _side()
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(SEP))
	add_child(row)
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(title)
	col.add_child(detail)
	row.add_child(col)
	_shard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_shard)
	row.add_child(price)
	title.add_theme_font_override("font", _title_font())
	title.uppercase = true
	detail.add_theme_font_override("font", HudStyle.font(false))
	detail.add_theme_color_override("font_color", AstralCardArt.DIM)
	price.add_theme_font_override("font", AstralCardArt.serif(600, 1))
	price.add_theme_font_size_override("font_size", PRICE_SIZE)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.size_flags_vertical = Control.SIZE_FILL
	for l: Label in [title, detail, price]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
		l.add_theme_constant_override("outline_size", 3)
	title.clip_text = true
	detail.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit())
	_fit()
	_apply()


## Shows the tile: `amount` shards (a cost, or a refund with `refund`), `poor` when it can't be afforded. `accent` and
## `plaque` are the Ember plaque's colours (kept for callers; Astral draws one palette).
func show_tile(
	p_title: String,
	p_detail: String,
	amount: int,
	p_enabled: bool,
	poor: bool = false,
	refund: bool = false,
	_accent: Color = CardStyle.EDGE,
	_plaque: StringName = &"amber"
) -> void:
	title.text = p_title
	detail.text = p_detail
	detail.visible = p_detail != ""
	price.text = ("+%d" % amount) if refund else str(amount)
	price.visible = amount > 0
	_shard.visible = amount > 0
	var col := POOR if poor else (REFUND if refund else AstralCardArt.TEXT)
	price.add_theme_color_override("font_color", col)
	_shard.tint = POOR if poor else AstralCardArt.ACCENT
	enabled = p_enabled
	_fit()
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


## The text box (px): the room between the icon and the plate's right tip.
func text_box() -> Vector2:
	return Vector2(_width - _side() * 2.0 - ICON - SEP, HEIGHT - PAD_Y * 2.0)


## True when the title (one line) and the detail fit beside the price in the text box (tests).
func text_fits() -> bool:
	var box := text_box()
	var tf := _title_font()
	var regular := HudStyle.font(false)
	var tw := tf.get_string_size(title.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var dw := regular.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x
	var h := (
		tf.get_height(title_size) + (regular.get_height(detail_size) if detail.visible else 0.0)
	)
	var room := box.x - _price_w()
	return tw <= room + 0.5 and dw <= room + 0.5 and h <= box.y + 0.5


func _side() -> float:
	return roundf(HEIGHT * AstralChrome.TIP) + 4.0


func _title_font() -> Font:
	return AstralCardArt.serif(600, 3)


## The price's width with its shard and the gaps before them (0 when there is no price).
func _price_w() -> float:
	if not price.visible:
		return 0.0
	var f := AstralCardArt.serif(600, 1)
	var pw := f.get_string_size(price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
	return SEP * 2.0 + _shard.custom_minimum_size.x + pw


func _fit() -> void:
	var box := text_box()
	var room := box.x - _price_w()
	var tf := _title_font()
	var regular := HudStyle.font(false)
	detail_size = TextFit.fit_width(regular, detail.text, room, DETAIL_SIZES)
	var dh := regular.get_height(detail_size) if detail.visible else 0.0
	title_size = TITLE_SIZES[TITLE_SIZES.size() - 1]
	for s: int in TITLE_SIZES:
		var wide := tf.get_string_size(title.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		if wide <= room and tf.get_height(s) + dh <= box.y:
			title_size = s
			break
	title.add_theme_font_size_override("font_size", title_size)
	detail.add_theme_font_size_override("font_size", detail_size)


func _apply() -> void:
	modulate = Color(1, 1, 1, 1.0 if enabled else 0.55)
	set_meta(GameCursor.META_INVALID, not enabled)  # v0.9.5 MC2: the cursor shows INVALID over a tile you can't use
	title.add_theme_color_override(
		"font_color", AstralCardArt.TEXT if focused else Color(AstralCardArt.TEXT, 0.86)
	)
	queue_redraw()
	_icon.queue_redraw()


func _draw() -> void:
	AstralChrome.plate(self, Rect2(Vector2.ZERO, size), focused, enabled)


func _draw_icon() -> void:
	var c := Vector2(roundf(_icon.size.x * 0.5) + 0.5, roundf(_icon.size.y * 0.5) + 0.5)
	var col := AstralCardArt.LINE_HI if focused else AstralCardArt.METAL
	AstralChrome.plate_icon(_icon, icon_kind, c, roundf(ICON * 0.5) - 1.0, col)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()
