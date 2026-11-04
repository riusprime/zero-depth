class_name AstralHudParts
extends RefCounted
## v0.10.5 W3-O17 (owner, 2026-11-04: "and what about the rest of the UI? it should match the new style"): the in-run
## HUD's own Astral pieces (W3_O13_UI_STYLE_G2.md round 2, Astral; the round-2 mock HUD, scripts/shots/mock_ui2/), next
## to the shared kit (AstralChrome: hairlines, stars, diamonds, crescents). Unboxed: no slab under any group; straight
## lines are 1 px rects on whole pixels, only curves and diagonals antialiased; no glow, no rounded boxes.
## - Wash: a faint ink wash under the HUD's top and bottom rows, so they read over the lit floor.
## - The HP medallion: a ring with a four-point star and the HP rune, a short arc over it, joined to the bar.
## - A continuous bar (the HP bar, the boss bar): one unbroken fill on an ink bed in a hairline frame, a lit top line,
##   a bright tick at the fill's end, a star at the bar's end (owner: "a continuous bar not split in parts").
## - An ability medallion: an ink disc in a silver ring with a dotted inner ring; cooling, a dark wedge over the part
##   still cooling and a moon-blue arc outside it (a diamond at the arc's head); a key cap under it.
## - A key cap: the binding's short name in a 1 px frame.
## It only draws: nothing here changes an outcome (EI-07).

## The HP rune (RunicGlyphs' Futhark strokes; the mock's).
const HP_RUNE := 14


## A vertical ink wash in `r`, `a0` alpha at its top to `a1` at its foot.
static func wash(ci: CanvasItem, r: Rect2, a0: float, a1: float) -> void:
	var c0 := Color(HudStyle.A_INK, a0)
	var c1 := Color(HudStyle.A_INK, a1)
	ci.draw_polygon(
		PackedVector2Array(
			[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		),
		PackedColorArray([c0, c0, c1, c1])
	)


## A rune `g` (RunicGlyphs) `h` px tall centred on `c`.
static func rune(ci: CanvasItem, g: int, c: Vector2, h: float, col: Color, w := 1.4) -> void:
	var k := h / RunicGlyphs.H
	var at := c - Vector2(h * 0.25, h * 0.5)
	for line: PackedVector2Array in RunicGlyphs.strokes(g):
		var pts := PackedVector2Array()
		for q in line:
			pts.append(at + q * k)
		ci.draw_polyline(pts, col, w, true)


## The HP medallion on `c`, ring radius `r`; `warn` (0..1) turns its ring toward the warning colour.
static func hp_medal(ci: CanvasItem, c: Vector2, r: float, warn := 0.0) -> void:
	var ring := HudStyle.A_METAL.lerp(HudStyle.A_WARN, clampf(warn, 0.0, 1.0))
	ci.draw_circle(c, r, Color(HudStyle.A_INK, 0.72))
	ci.draw_arc(c, r, 0.0, TAU, 64, ring, 1.2, true)
	ci.draw_arc(c, r - 4.0, 0.0, TAU, 48, Color(ring, 0.22), 1.0, true)
	ci.draw_arc(c, r + 5.0, -PI * 0.9, -PI * 0.1, 32, Color(ring, 0.5), 1.0, true)
	ci.draw_arc(c, r + 5.0, PI * 0.15, PI * 0.85, 32, Color(ring, 0.18), 1.0, true)
	AstralChrome.star4(ci, c, r * 0.8, Color(HudStyle.A_LINE_HI, 0.92), 0.14)
	rune(ci, HP_RUNE, c + Vector2(0, 1), r * 0.5, HudStyle.A_INK, 1.4)
	for k in 4:  # four small diamonds on the ring's quarters
		var a := PI * 0.25 + PI * 0.5 * k
		AstralChrome.dia(ci, c + Vector2(cos(a), sin(a)) * r, 2.0, ring, HudStyle.A_INK)


## The continuous bar in `r` (the HP bar and the boss bar): the ink bed in its hairline frame, the damage chunk
## (`chunk_x0`..`chunk_x1`, px from r's left, in `chunk_col`), the fill to `fill_w` px in `col` with a lit top line and
## a darker foot, a bright tick at its end, and `end_star` (a small star past the bar's end).
static func bar(
	ci: CanvasItem,
	r: Rect2,
	fill_w: float,
	col: Color,
	chunk_x0: float,
	chunk_x1: float,
	chunk_col: Color,
	end_star := true
) -> void:
	var x0 := roundf(r.position.x)
	var x1 := roundf(r.end.x)
	var y0 := roundf(r.position.y)
	var h := roundf(r.size.y)
	ci.draw_rect(Rect2(x0, y0, x1 - x0, h), Color(HudStyle.A_INK, 0.7))
	_frame(ci, Rect2(x0 - 1, y0 - 1, x1 - x0 + 2, h + 2), Color(HudStyle.A_METAL, 0.42))
	var inner := Rect2(x0 + 2, y0 + 2, x1 - x0 - 4, h - 4)
	var fx := roundf(
		inner.position.x + clampf(fill_w / maxf(1.0, r.size.x), 0.0, 1.0) * inner.size.x
	)
	if chunk_x1 > chunk_x0:
		var cx0 := roundf(inner.position.x + chunk_x0 / maxf(1.0, r.size.x) * inner.size.x)
		var cx1 := roundf(inner.position.x + chunk_x1 / maxf(1.0, r.size.x) * inner.size.x)
		ci.draw_rect(Rect2(cx0, inner.position.y, cx1 - cx0, inner.size.y), chunk_col)
	if fx > inner.position.x:
		var fill := Rect2(inner.position.x, inner.position.y, fx - inner.position.x, inner.size.y)
		ci.draw_rect(fill, col)
		AstralChrome.hline(ci, fill.position.x, fx, fill.position.y, col.lightened(0.45))
		AstralChrome.hline(
			ci, fill.position.x, fx, fill.end.y - 1, Color(col.darkened(0.35), col.a)
		)
		AstralChrome.vline(ci, fx - 1, y0 - 4, y0 + h + 4, Color(HudStyle.A_LINE_HI, col.a))
	if end_star:
		var sy := y0 + h * 0.5
		AstralChrome.hline(ci, x1 + 1, x1 + 5, roundf(sy - 0.5), Color(HudStyle.A_METAL, 0.6))
		AstralChrome.star4(ci, Vector2(x1 + 11.5, sy), 6.0, Color(HudStyle.A_METAL, 0.9), 0.16)


## A slim meter's bed (the heat bar, the danger bar): ink in a hairline frame.
static func slim_bed(ci: CanvasItem, r: Rect2, frame_alpha := 0.34) -> void:
	var o := Rect2(r.position.round(), r.size.round())
	ci.draw_rect(o, Color(HudStyle.A_INK, 0.62))
	_frame(ci, o.grow(1.0), Color(HudStyle.A_METAL, frame_alpha))


## A 1 px rectangle frame on whole pixels.
static func _frame(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var o := Rect2(r.position.round(), r.size.round())
	AstralChrome.hline(ci, o.position.x, o.end.x, o.position.y, col)
	AstralChrome.hline(ci, o.position.x, o.end.x, o.end.y - 1, col)
	AstralChrome.vline(ci, o.position.x, o.position.y + 1, o.end.y - 1, col)
	AstralChrome.vline(ci, o.end.x - 1, o.position.y + 1, o.end.y - 1, col)


static func frame(ci: CanvasItem, r: Rect2, col: Color) -> void:
	_frame(ci, r, col)


## An ability medallion on `c`, radius `r`: `share` (0..1) of it still cooling (0: ready).
static func medallion(ci: CanvasItem, c: Vector2, r: float, share: float) -> void:
	var ready := share <= 0.0
	ci.draw_circle(c, r, Color(HudStyle.A_INK, 0.72))
	ci.draw_arc(
		c, r, 0.0, TAU, 72, HudStyle.A_METAL if ready else Color(HudStyle.A_METAL, 0.5), 1.2, true
	)
	for k in 36:  # the dotted inner ring
		var a := TAU * k / 36.0
		ci.draw_rect(
			Rect2((c + Vector2(cos(a), sin(a)) * (r - 5.0)).round(), Vector2.ONE),
			Color(HudStyle.A_METAL, 0.3)
		)
	if ready:
		for k in 4:  # four small stars on the quarters: lit and ready
			var a := -PI * 0.5 + PI * 0.5 * k
			AstralChrome.star4(
				ci, c + Vector2(cos(a), sin(a)) * (r + 5.0), 3.0, Color(HudStyle.A_METAL, 0.7), 0.25
			)
		return
	var a0 := -PI * 0.5
	var head := a0 + TAU * (1.0 - share)
	# the part still cooling: a dark wedge inside the ring, clockwise from twelve o'clock
	var pts := PackedVector2Array([c])
	var steps := maxi(2, int(ceil(share * 48.0)))
	for k in steps + 1:
		var a := head + TAU * share * k / steps
		pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
	if share >= 0.01:
		ci.draw_colored_polygon(pts, Color(HudStyle.A_INK, 0.62))
	# the arc outside: the ready part lit, the rest faint; a diamond at its head
	ci.draw_arc(c, r + 6.0, a0, head, 72, HudStyle.A_ACCENT, 2.0, true)
	ci.draw_arc(c, r + 6.0, head, a0 + TAU, 72, Color(HudStyle.A_METAL, 0.16), 1.0, true)
	AstralChrome.dia(
		ci,
		c + Vector2(cos(head), sin(head)) * (r + 6.0),
		3.0,
		HudStyle.A_LINE_HI,
		HudStyle.A_LINE_HI
	)


## A key cap centred on `c`: the binding's short name in Atkinson bold 13 in a 1 px frame on ink.
static func keycap(ci: CanvasItem, text: String, c: Vector2) -> void:
	if text == "":
		return
	var f := HudStyle.font(true)
	var fs := 13
	var w := maxf(22.0, f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0)
	var r := Rect2(Vector2(roundf(c.x - w * 0.5), roundf(c.y - 10.0)), Vector2(roundf(w), 20))
	ci.draw_rect(r, Color(HudStyle.A_INK, 0.85))
	_frame(ci, r, Color(HudStyle.A_METAL, 0.7))
	ci.draw_string(
		f,
		Vector2(r.position.x, r.position.y + 15.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		fs,
		HudStyle.A_TEXT
	)


## A string in Cinzel (`wght`, tracked `track`) at `base` (baseline), aligned within `w` (-1: from `base` on), with a
## thin ink outline so it reads over the floor.
static func serif_text(
	ci: CanvasItem,
	text: String,
	base: Vector2,
	fs: int,
	col: Color,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	w := -1.0,
	track := 2,
	wght := 600
) -> void:
	var f := HudStyle.serif(wght, track)
	ci.draw_string_outline(f, base, text, align, w, fs, 4, Color(HudStyle.A_INK, 0.75))
	ci.draw_string(f, base, text, align, w, fs, col)


## v0.10.5 W3-O17: the content margins of a HudFrame (ASTRAL lays its groups out unboxed).
static func set_margins(f: HudFrame, left: float, right: float, top: float, bottom: float) -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	f.add_theme_stylebox_override("panel", box)


## v0.10.5 W3-O17: the floor line's ornaments: a four-point star each side of the text and a hairline fading outward.
## It sits over the floor label and redraws only when the label's text or size changes.
class FloorMarks:
	extends Control

	var label: Label

	func _init() -> void:
		name = "FloorMarks"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if label == null or label.text == "":
			return
		var f := label.get_theme_font(&"font")
		var fs := label.get_theme_font_size(&"font_size")
		var tw := f.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := roundf(size.x * 0.5)
		var y := roundf(size.y * 0.5) - 0.5
		for sx: float in [-1.0, 1.0]:
			var ox := roundf(cx + sx * (tw * 0.5 + 20.0)) + 0.5
			AstralChrome.star4(self, Vector2(ox, y), 6.0, HudStyle.A_METAL, 0.2)
			AstralChrome.rule1(
				self, ox + sx * 12.0, roundf(y), sx * 64.0, Color(HudStyle.A_METAL, 0.6)
			)


## The HUD's ink washes: under the top row and under the bottom row, faint, full width. Drawn once per resize.
class Wash:
	extends Control

	const TOP_H := 128.0
	const BOTTOM_H := 176.0

	func _init() -> void:
		name = "AstralWash"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		AstralHudParts.wash(self, Rect2(0, 0, size.x, TOP_H), 0.46, 0.0)
		AstralHudParts.wash(self, Rect2(0, size.y - BOTTOM_H, size.x, BOTTOM_H), 0.0, 0.52)


## The HP medallion beside the HP bar: its ring centred `bar_y` px above its own foot (the bar's mid-line), and a
## hairline from the ring to its right edge, where the bar starts. `warn` tints the ring (the low-HP pulse).
class HpMedal:
	extends Control

	const R := 30.0
	var bar_y := 16.0:
		set(v):
			if v != bar_y:
				bar_y = v
				queue_redraw()
	var warn := 0.0:
		set(v):
			if absf(v - warn) > 0.01:
				warn = v
				queue_redraw()

	func _init() -> void:
		name = "HpMedal"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(R * 2.0 + 20.0, R * 2.0 + 12.0)
		size_flags_vertical = Control.SIZE_SHRINK_END

	func centre() -> Vector2:
		return Vector2(R + 6.0, size.y - bar_y)

	func _draw() -> void:
		var c := centre()
		AstralChrome.hline(
			self, c.x + R, size.x + 2.0, roundf(c.y - 0.5), Color(HudStyle.A_METAL, 0.8)
		)
		AstralHudParts.hp_medal(self, c, R, warn)


## A slot pip (the build row): a small diamond; filled with its card family's colour (`ring_color`) when the slot holds
## a card, an empty outline otherwise (`dim` < 1). A StoneBox, so the row's contract (pip_box, ring_color) holds.
class Pip:
	extends StoneBox

	func _draw(to: RID, rect: Rect2) -> void:
		var c := rect.get_center()
		var rr := minf(rect.size.x, rect.size.y) * 0.5
		var pts := AstralChrome.dia_pts(c, rr)
		var filled := ring_color.a > 0.0
		RenderingServer.canvas_item_add_polygon(
			to, pts, PackedColorArray([Color(HudStyle.A_INK, 0.8)])
		)
		if filled:
			RenderingServer.canvas_item_add_polygon(
				to, AstralChrome.dia_pts(c, rr - 3.0), PackedColorArray([Color(ring_color, 0.38)])
			)
		var line := Color(ring_color, 0.95) if filled else Color(HudStyle.A_METAL, 0.35)
		var loop := pts.duplicate()
		loop.append(pts[0])
		RenderingServer.canvas_item_add_polyline(to, loop, PackedColorArray([line]), 1.0, true)
