extends "res://scripts/shots/mock_ui2/screens.gd"
## v0.10.5 W3-O13c G2, round 3 (scripts/shots/mock_ui_cards.gd): Astral is the style (owner, 2026-11-04: "Astral I
## like the most but the shape of the cards is odd, that pointy top is bad."). Three card shapes without a pointed
## top, drawn in place of round 2's crest; everything else is round 2's Astral. A prototype, not game code.
##   1 Tablet: a tall rectangle, its top corners softly chamfered, a crescent finial set inside the top edge, a small
##     keel at the bottom.
##   2 Window: a shallow round arch over straight sides (an impost tick where they meet), a crescent resting on the
##     crown, a flat bottom with a small notch.
##   3 Seal: a plain rectangle with cut corners and a double hairline frame, a crescent medallion breaking the top
##     border.
## card_shape 0 keeps round 2's crest. kind "cards" lays the focused card of each shape side by side, large.

var card_shape := 1


func _draw() -> void:
	if kind != "cards":
		super._draw()
		return
	glass.clear()
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(p["ink"], 0.45))  # the world quieter under the comparison
	var faces: Array = d["faces"]
	var cw := 450.0
	var ch := 630.0
	var gap := 120.0
	var x0 := 960.0 - (cw * 3 + gap * 2) * 0.5
	var y0 := roundf((1080.0 - ch) * 0.5) - 8.0
	for k in 3:
		card_shape = k + 1
		var r := Rect2(x0 + k * (cw + gap), y0, cw, ch)
		_card(r, faces[0], true, int(d["prices"][0]), bool(d["ok"][0]))
		var lbl := ["I", "II", "III"][k] as String
		var cx := r.get_center().x
		_cap(lbl, cx, r.end.y + 72, 26, p["metal"], 6, 1)
		_rule1(cx - 32, r.end.y + 63, -90, Color(p["metal"], 0.5))
		_rule1(cx + 32, r.end.y + 63, 90, Color(p["metal"], 0.5))


func _title_top() -> float:
	if style == "astral" and card_shape == 2:
		return 56.0
	return super._title_top()


func _card_frame(r: Rect2, focused: bool) -> void:
	if style != "astral" or card_shape == 0:
		super._card_frame(r, focused)
		return
	var s := r.size.x / 300.0
	var o := _px(r)
	var line: Color = p["line_hi"] if focused else p["line"]
	var fin_col := Color(line, 1.0 if focused else 0.6)
	var pts: PackedVector2Array
	match card_shape:
		1:
			pts = _tablet(o, s)
		2:
			pts = _window(o, s)
		_:
			pts = _cut(o, roundf(8 * s))
	draw_colored_polygon(pts, p["fill_hi"] if focused else p["fill"])
	var cx := o.get_center().x
	var top := o.position.y
	match card_shape:
		1:
			_poly(_contour(pts, -6.0), Color(line, 0.35 if focused else 0.22))
			_poly(pts, line, 1.4 if focused else 1.0)
			# The finial inside the top edge: a crescent cupped upward between two small diamonds.
			var fc := Vector2(cx, top + roundf(17 * s))
			_crescent(fc, 7.0 * s, fin_col, PI * 0.5)
			for sx: float in [-1.0, 1.0]:
				_dia(fc + Vector2(sx * 18 * s, -1), 2.0, Color(line, 0.7 if focused else 0.45))
		2:
			_poly(_contour(pts, -6.0), Color(line, 0.35 if focused else 0.22))
			_poly(pts, line, 1.4 if focused else 1.0)
			var spring := top + roundf(34 * s)
			for sx: float in [-1.0, 1.0]:  # the imposts where the arch springs from the sides
				var ex := o.position.x if sx < 0 else o.end.x
				_ln(Vector2(ex + sx * 1, spring), Vector2(ex + sx * 7, spring), Color(line, 0.8))
			# The crescent rests on the arch's crown, horns up.
			_crescent(Vector2(cx, top - 9.0 * s), 8.0 * s, fin_col, PI * 0.5)
		_:
			var mr := roundf(15 * s)
			var inner := _cut(o.grow(-5), roundf(5 * s))
			_gap_poly(inner, cx, inner[0].y, mr + 6, Color(line, 0.4 if focused else 0.28))
			_gap_poly(pts, cx, top, mr + 5, line, 1.0)
			if focused:
				_h(o.position.x + 9 * s, o.end.x - 9 * s, top + 1, Color(p["line_hi"], 0.25))
			var mc := Vector2(cx, top)
			draw_circle(mc, mr, Color(p["ink"], 0.92))
			_arc(mc, mr, 0, TAU, line, 1.4 if focused else 1.0)
			_arc(mc, mr - 4, 0, TAU, Color(line, 0.3))
			_crescent(mc + Vector2(0, -1), mr * 0.5, fin_col, PI * 0.5)
	if not focused:
		return
	# Focus: a second contour 6 px outside, and two sparks at a shoulder and the opposite foot.
	if card_shape == 3:
		_gap_poly(_contour(pts, 6.0), cx, top - 6, roundf(15 * s) + 10, Color(p["line_hi"], 0.25))
		_star4(Vector2(cx, o.end.y + 0.5), 7.0, p["line_hi"], 0.16)
	else:
		_poly(_contour(pts, 6.0), Color(p["line_hi"], 0.25))
	var shoulder := {1: 30.0, 2: 34.0, 3: 22.0}[card_shape] as float
	_star4(Vector2(o.position.x - 6, top + roundf(shoulder * s)), 8.0, p["line_hi"], 0.14)
	_star4(Vector2(o.end.x + 6, o.end.y - roundf(28 * s)), 6.0, Color(p["line_hi"], 0.7), 0.14)


## Shape 1: the top corners chamfered on a soft curve, square sides, small cut foot corners and a shallow keel.
static func _tablet(o: Rect2, s: float) -> PackedVector2Array:
	var a := o.position
	var b := o.end
	var cx := o.get_center().x
	var c := roundf(22 * s)
	var f := roundf(6 * s)
	var pts: Array[Vector2] = []
	_bez(pts, Vector2(a.x, a.y + c), Vector2(a.x + c, a.y), Vector2(a.x + c * 0.32, a.y + c * 0.32))
	_bez(pts, Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x - c * 0.32, a.y + c * 0.32))
	pts.append(Vector2(b.x, b.y - f))
	pts.append(Vector2(b.x - f, b.y))
	pts.append(Vector2(cx + roundf(30 * s), b.y))
	pts.append(Vector2(cx, b.y + roundf(8 * s)))
	pts.append(Vector2(cx - roundf(30 * s), b.y))
	pts.append(Vector2(a.x + f, b.y))
	pts.append(Vector2(a.x, b.y - f))
	return PackedVector2Array(pts)


## Shape 2: a shallow segmental arch (34 px rise) over straight sides; a flat foot with cut corners and a notch.
static func _window(o: Rect2, s: float) -> PackedVector2Array:
	var a := o.position
	var b := o.end
	var cx := o.get_center().x
	var hw := o.size.x * 0.5
	var rise := roundf(34 * s)
	var rad := (hw * hw + rise * rise) / (2.0 * rise)
	var cy := a.y + rad
	var f := roundf(8 * s)
	var pts: Array[Vector2] = []
	for k in 49:
		var x := a.x + o.size.x * k / 48.0
		pts.append(Vector2(x, cy - sqrt(maxf(0.0, rad * rad - (x - cx) * (x - cx)))))
	pts.append(Vector2(b.x, b.y - f))
	pts.append(Vector2(b.x - f, b.y))
	pts.append(Vector2(cx + roundf(16 * s), b.y))
	pts.append(Vector2(cx, b.y - roundf(6 * s)))
	pts.append(Vector2(cx - roundf(16 * s), b.y))
	pts.append(Vector2(a.x + f, b.y))
	pts.append(Vector2(a.x, b.y - f))
	return PackedVector2Array(pts)


## A quadratic curve from p0 to p2 (12 steps) appended to `pts`.
static func _bez(pts: Array[Vector2], p0: Vector2, p2: Vector2, ctrl: Vector2) -> void:
	for k in 13:
		var t := k / 12.0
		pts.append(p0.lerp(ctrl, t).lerp(ctrl.lerp(p2, t), t))


## The closed outline with the stretch of its top edge (at `y`) within `hw` of `cx` left open.
func _gap_poly(
	pts: PackedVector2Array, cx: float, y: float, hw: float, col: Color, w := 1.0
) -> void:
	for k in pts.size():
		var a := pts[k]
		var b := pts[(k + 1) % pts.size()]
		if absf(a.y - y) < 0.6 and absf(b.y - y) < 0.6:
			var x0 := minf(a.x, b.x)
			var x1 := maxf(a.x, b.x)
			if x0 < cx - hw:
				_ln(Vector2(x0, a.y), Vector2(minf(x1, cx - hw), a.y), col, w)
			if x1 > cx + hw:
				_ln(Vector2(maxf(x0, cx + hw), a.y), Vector2(x1, a.y), col, w)
		else:
			_ln(a, b, col, w)
