class_name CardBack
extends Control
## v0.8.0 N8 (owner O62, "paint the whole card"): a reward card's back, face down while the cards are dealt: the
## same carved stone slab (StoneBox) painted in the card's rarity colour, its frame in that colour, a carved ember
## diamond in the middle with a ring round it, and for an Epic or Legendary card waiting to flip a glow in its colour
## round the slab (`glow`). It draws what it is given; it decides nothing (EI-07).

var tier := 0
var color := Color.WHITE
## 0..1: the waiting high card's glow.
var glow := 0.0:
	set(v):
		if not is_equal_approx(glow, v):
			glow = v
			_box.under = 0.2 + 1.4 * v
			_box.focus = 0.9 * v
			queue_redraw()
var _box := StoneBox.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.cut = 18.0
	_box.chip = 3.5
	_box.cracks = 2
	_box.pattern = 401


## Paints the back for tier `p_tier` (PickSlot.TIERS) in its colour.
func paint(p_tier: int, c: Color) -> void:
	tier = p_tier
	color = c
	_box.fill = CardPaint.face(c)
	_box.edge = c
	_box.glow_color = c
	_box.rim = EmberStone.GOLD if CardDeal.high(p_tier) else Color(0, 0, 0, 0)
	queue_redraw()


func box() -> StoneBox:
	return _box


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_box, r)
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.2
	var ring := PackedVector2Array()
	for k in 33:
		var a := k * TAU / 32.0
		ring.append(c + Vector2(cos(a), sin(a)) * s * 1.35)
	draw_polyline(ring, Color(color, 0.75), 2.5, true)
	draw_polyline(ring, Color(color, 0.18 + 0.3 * glow), 9.0, true)
	var diamond := PackedVector2Array(
		[c + Vector2(0, -s), c + Vector2(s * 0.62, 0), c + Vector2(0, s), c + Vector2(-s * 0.62, 0)]
	)
	draw_colored_polygon(diamond, Color(EmberStone.GROOVE, 0.9))
	var inner := PackedVector2Array()
	for p in diamond:
		inner.append(c + (p - c) * 0.62)
	draw_colored_polygon(inner, color.lerp(EmberStone.EMBER, 0.35).lightened(0.15 + 0.3 * glow))
	for k in 4:  # the carved notches at the corners of the diamond's frame
		var a := k * TAU / 4.0 + TAU / 8.0
		var p := c + Vector2(cos(a), sin(a)) * s * 1.75
		draw_circle(p, 3.0, Color(color, 0.6))
