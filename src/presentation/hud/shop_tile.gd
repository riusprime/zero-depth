class_name ShopTile
extends PanelContainer
## One button of the shop panel (v0.5.0 SH): the heal, the reroll or a salvage row, in the cards' CardStyle panel
## (FACET by default). A title, a detail line and a price or refund with the shard icon. A disabled tile is dimmed
## and its price turns red when you can't afford it. A mouse click or hover reports itself; the panel decides.

signal clicked
signal hovered

const POOR := Color("#FF5A4D")
const REFUND := Color("#9CF29C")

var enabled := true
var focused := false
var title := Label.new()
var detail := Label.new()
var price := Label.new()
var _box := CardStyle.box(Vector4(12, 8, 12, 8))
var _icon := ShardIcon.new(18.0)
var _accent := CardStyle.EDGE


func _init(p_name: String, min_width: float = 200.0) -> void:
	name = p_name
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(min_width, 0)
	add_theme_stylebox_override("panel", _box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	col.add_child(title)
	col.add_child(detail)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon)
	row.add_child(price)
	col.add_child(row)
	HudStyle.style_label(title, 17, true)
	HudStyle.style_label(detail, 13)
	HudStyle.style_label(price, 16, true)
	for l: Label in [title, detail, price]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit())
	_apply()


## Shows the tile: `amount` shards (a cost, or a refund with `refund`), `poor` when it can't be afforded.
func show_tile(
	p_title: String,
	p_detail: String,
	amount: int,
	p_enabled: bool,
	poor: bool = false,
	refund: bool = false,
	accent: Color = CardStyle.EDGE
) -> void:
	title.text = p_title
	detail.text = p_detail
	detail.visible = not p_detail.is_empty()
	price.text = ("+%d" % amount) if refund else str(amount)
	price.visible = amount > 0
	_icon.visible = amount > 0
	price.add_theme_color_override(
		"font_color", POOR if poor else (REFUND if refund else Color.WHITE)
	)
	enabled = p_enabled
	_accent = accent
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


func panel_box() -> StyleBoxFlat:
	return _box


func _apply() -> void:
	CardStyle.apply(_box, _accent, focused)
	modulate = Color(1, 1, 1, 1.0 if enabled else 0.45)
	title.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.55))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()
