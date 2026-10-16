class_name InlaySocket
extends Control
## v0.8.0 MU (Ember stone, EmberStone): a round socket carved into the stone with a glowing inlay ring in an element's
## colour, holding a card's icon (ItemIconView) or any picture. It draws behind its children; it takes no input.
## v0.8.0 TX3: an elemental card's socket also wears the owner's glyph of its element (ElementGlyphs) in a small
## carved badge set into the ring at its lower right, over the icon (none on a socket too small to read it).
## Presentation only (EI-07).

## The icon's inset inside the socket (share of the socket's size on each side).
const INSET := 0.24
## v0.8.0 TX3: the glyph badge's radius (share of the socket's), where on the ring it sits (radians, y down), and the
## smallest socket (px) that shows one (starting values).
const BADGE := 0.36
const BADGE_AT := 0.25 * PI
const BADGE_MIN_PX := 40.0

var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
## 0..1: the focused card's ring glows brighter.
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()
## The picture in the socket (an ItemIconView by default; null for an empty socket).
var icon: ItemIconView
## v0.8.0 TX3: the element whose glyph the badge shows (&"": none).
var element := &"":
	set(v):
		element = v
		_badge.queue_redraw()
var _badge := Control.new()


func _init(with_icon: bool = true) -> void:
	name = "InlaySocket"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_icon:
		icon = ItemIconView.new()
		icon.name = "Icon"
		icon.anchor_left = INSET
		icon.anchor_top = INSET
		icon.anchor_right = 1.0 - INSET
		icon.anchor_bottom = 1.0 - INSET
		add_child(icon)
	_badge.name = "ElementGlyph"
	_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # a 256 px glyph drawn at ~40 px
	_badge.draw.connect(_draw_badge)
	add_child(_badge)


## Shows card `id`'s icon in `icon_color`, with the ring in `ring` (the element's colour).
func show_item(id: StringName, icon_color: Color, ring: Color) -> void:
	color = ring
	if icon != null:
		icon.set_item(id, icon_color)
		icon.visible = id != &""
	element = ElementGlyphs.element_of(id)


func _draw() -> void:
	var k := clampf(minf(size.x, size.y) / 80.0, 0.35, 1.4)
	draw_socket(get_canvas_item(), size * 0.5, minf(size.x, size.y) * 0.5, color, glow, k)


## Whether the badge draws a glyph now (an elemental card, the sheet installed, the socket large enough).
func shows_glyph() -> bool:
	return (
		element != &""
		and minf(size.x, size.y) >= BADGE_MIN_PX
		and not ElementGlyphs.region(element).is_empty()
	)


func _draw_badge() -> void:
	if not shows_glyph():
		return
	var r := minf(size.x, size.y) * 0.5
	var k := clampf(r * 2.0 / 80.0, 0.35, 1.4)
	var c := size * 0.5 + Vector2(cos(BADGE_AT), sin(BADGE_AT)) * r * 0.92
	var br := r * BADGE
	_badge.draw_circle(c, br + 1.5 * k, Color(EmberStone.GROOVE, 0.95))
	_badge.draw_circle(c, br, Color(0.045, 0.036, 0.03))
	_badge.draw_arc(c, br, 0.0, TAU, 24, Color(color.lightened(0.25), 0.8), 1.4 * k, true)
	var g := br * 1.55
	ElementGlyphs.draw(_badge, element, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)))


## A socket at `c` of radius `r` on canvas item `ci`: the carved dark well, a warm reflection on its lower lip, the
## ring's glow and the bright groove in `col`.
static func draw_socket(ci: RID, c: Vector2, r: float, col: Color, lit: float, k: float) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_circle(ci, c, r + 1.5 * k, Color(EmberStone.GROOVE, 0.85))
	rs.canvas_item_add_circle(ci, c, r - 2.0 * k, Color(0.045, 0.036, 0.03))
	_arc(ci, c, r - 5.0 * k, 0.15 * PI, 0.85 * PI, EmberStone.ember(lit, 0.3 + 0.2 * lit), 2.0 * k)
	_arc(ci, c, r - 5.0 * k, 1.15 * PI, 1.85 * PI, Color(0, 0, 0, 0.5), 2.5 * k)
	if col.a <= 0.0:
		return
	_arc(ci, c, r, 0.0, TAU, Color(col, 0.18 + 0.14 * lit), 7.0 * k)
	_arc(ci, c, r, 0.0, TAU, Color(col.lightened(0.25), 0.95), 2.4 * k)


static func _arc(
	ci: RID, c: Vector2, r: float, from: float, to: float, col: Color, w: float
) -> void:
	var pts := PackedVector2Array()
	var n := maxi(12, int(r * (to - from) / 4.0))
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), w, true)
