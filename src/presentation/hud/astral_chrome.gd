class_name AstralChrome
extends RefCounted
## v0.10.5 W3-O16 (owner 2026-11-04: "Yes, go on"; UI style Astral, W3_O13_UI_STYLE_G2.md round 2; the shop's layout
## A, W3_O9_SHOP_G2.md): the Astral chrome round the cards of the altar pick, the shop and the Swap. Thin crisp lines
## on whole pixels (only diagonals and curves antialiased), no rounded boxes, no glow, Astral's palette only
## (AstralCardArt's tokens):
## - Heading: a sigil (a ring, a four-point star, a crescent over it), the title in letter-spaced Cinzel capitals and a
##   quieter subtitle after a small diamond ("ALTAR ◆ CHOOSE ONE").
## - Rule: a hairline fading out both ways from a small four-point star (under a heading).
## - Hint: the hint line between two thin hairlines fading outward, a small diamond at each inner end.
## - Pips: one diamond per buy, filled while it is left.
## - Plate: a slim lozenge button (pointed ends, a star off each tip), an inner contour 5 px in. Focus (Astral's
##   rules): the contour brightens to line_hi at 1.4 px, a second contour sits 6 px outside at 25 %, the fill lifts
##   with a faint accent wash and the tip stars light.
## - Veil: the shop's store window, no border: an ink veil fading at its sides, between two fading hairlines.
## - FrameBox: a wand tile (the Swap's row): a straight 1 px frame with an inner frame 6 px in; focus as a plate's.
## It only draws: nothing here changes an outcome (EI-07).

const FILL := Color("#0D1120", 0.84)
const FILL_HI := Color("#141A2F", 0.92)
const INK := Color("#070913")
const FAINT := Color("#3F4566")
## A plate's tip length as a share of its height.
const TIP := 0.6


## A hairline fading out both ways from `cx` (six steps), leaving `gap` clear in the middle.
static func rule(ci: CanvasItem, cx: float, y: float, half: float, col: Color, gap := 0.0) -> void:
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		var c0 := gap + (half - gap) * k / 6.0
		var c1 := gap + (half - gap) * (k + 1) / 6.0
		hline(ci, cx - c1, cx - c0, y, Color(col, a))
		hline(ci, cx + c0, cx + c1, y, Color(col, a))


## A hairline from `x0` fading out over `length` px (negative: leftwards).
static func rule1(ci: CanvasItem, x0: float, y: float, length: float, col: Color) -> void:
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		hline(ci, x0 + length * k / 6.0, x0 + length * (k + 1) / 6.0, y, Color(col, a))


## A 1 px horizontal line on whole pixels.
static func hline(ci: CanvasItem, x0: float, x1: float, y: float, col: Color, w := 1.0) -> void:
	var a := roundf(minf(x0, x1))
	ci.draw_rect(Rect2(a, roundf(y), roundf(maxf(x0, x1)) - a, w), col)


## A 1 px vertical line on whole pixels.
static func vline(ci: CanvasItem, x: float, y0: float, y1: float, col: Color, w := 1.0) -> void:
	var a := roundf(minf(y0, y1))
	ci.draw_rect(Rect2(roundf(x), a, w, roundf(maxf(y0, y1)) - a), col)


## A four-point star.
static func star4(ci: CanvasItem, c: Vector2, r: float, col: Color, inner := 0.22) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI * 0.5 + PI * 0.25 * k
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * inner))
	ci.draw_colored_polygon(pts, col)


static func dia_pts(c: Vector2, rx: float, ry := -1.0) -> PackedVector2Array:
	if ry < 0.0:
		ry = rx
	return PackedVector2Array(
		[c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)]
	)


## A diamond: outlined in `col`, filled with `fill` when it has alpha.
static func dia(
	ci: CanvasItem, c: Vector2, r: float, col: Color, fill := Color(0, 0, 0, 0), w := 1.0
) -> void:
	var pts := dia_pts(c, r)
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	if col.a > 0.0:
		poly(ci, pts, col, w)


## A closed antialiased outline.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.0) -> void:
	var out := pts.duplicate()
	out.append(pts[0])
	ci.draw_polyline(out, col, w, true)


## A thin crescent moon on `c`, its lit side facing `facing` (radians).
static func crescent(ci: CanvasItem, c: Vector2, r: float, col: Color, facing := -PI * 0.5) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var a := facing - 1.75 + 3.5 * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var ic := c - Vector2(cos(facing), sin(facing)) * r * 0.32
	for k in 17:
		var a := facing + 1.45 - 2.9 * k / 16.0
		pts.append(ic + Vector2(cos(a), sin(a)) * r * 0.86)
	ci.draw_colored_polygon(pts, col)


## The heading's sigil centred on `c`, `r` its ring's radius: a ring, a four-point star through it, a crescent over it.
static func sigil(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 64, Color(col, 0.6), 1.0, true)
	ci.draw_arc(c, r * 0.62, 0.0, TAU, 48, Color(col, 0.25), 1.0, true)
	star4(ci, c, r * 1.55, col, 0.16)
	crescent(ci, c + Vector2(0, -r * 1.95), r * 0.48, Color(col, 0.9))


## The polygon grown (+) or shrunk (-) by `delta` px.
static func contour(pts: PackedVector2Array, delta: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(pts, delta, Geometry2D.JOIN_MITER)
	return out[0] if not out.is_empty() else pts


## A slim lozenge: pointed ends `tip` px long.
static func lozenge(r: Rect2, tip: float) -> PackedVector2Array:
	var cy := r.get_center().y
	return PackedVector2Array(
		[
			Vector2(r.position.x, cy),
			Vector2(r.position.x + tip, r.position.y),
			Vector2(r.end.x - tip, r.position.y),
			Vector2(r.end.x, cy),
			Vector2(r.end.x - tip, r.end.y),
			Vector2(r.position.x + tip, r.end.y),
		]
	)


## The rectangle on half pixels, so 1 px antialiased outlines fall on whole pixels.
static func px(r: Rect2) -> Rect2:
	return Rect2(
		Vector2(roundf(r.position.x) + 0.5, roundf(r.position.y) + 0.5),
		Vector2(roundf(r.size.x) - 1.0, roundf(r.size.y) - 1.0)
	)


## The plate (a slim lozenge button) in `r` (the tip stars sit 10 px outside it). `enabled` false: a fainter line.
static func plate(ci: CanvasItem, r: Rect2, focused: bool, enabled := true) -> void:
	var o := px(r)
	var tip := roundf(r.size.y * TIP)
	var pts := lozenge(o, tip)
	var line := AstralCardArt.LINE_HI if focused else (AstralCardArt.LINE if enabled else FAINT)
	ci.draw_colored_polygon(pts, FILL_HI if focused else FILL)
	if focused:
		ci.draw_colored_polygon(contour(pts, -3.0), Color(AstralCardArt.ACCENT, 0.1))
		poly(ci, contour(pts, 6.0), Color(AstralCardArt.LINE_HI, 0.25))
	poly(ci, contour(pts, -5.0), Color(line, 0.3))
	poly(ci, pts, line, 1.4 if focused else 1.0)
	var cy := roundf(o.get_center().y) + 0.5
	for sx in [-1.0, 1.0]:
		var x: float = o.get_center().x + sx * (o.size.x * 0.5 + (16.0 if focused else 10.0))
		star4(
			ci,
			Vector2(roundf(x) + 0.5, cy),
			6.0 if focused else 5.0,
			Color(line, 0.95 if focused else 0.5)
		)


## A plate's icon, centred on `c` in a thin ring `r`: &"heal" (a cross with a diamond core), &"reroll" (two turning
## arrows), else a small diamond.
static func plate_icon(ci: CanvasItem, kind: StringName, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, Color(INK, 0.7))
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(col, 0.75), 1.0, true)
	var s := roundf(r * 0.5)
	match kind:
		&"heal":
			hline(ci, c.x - s, c.x + s + 1.0, c.y, col, 1.0)
			vline(ci, c.x, c.y - s, c.y + s + 1.0, col, 1.0)
			dia(ci, c + Vector2(0.5, 0.5), 3.0, col, INK)
			star4(ci, c + Vector2(0.5, 0.5), 1.6, col, 0.9)
		&"reroll":
			ci.draw_arc(c, s, -PI * 0.95, -PI * 0.2, 16, col, 1.4, true)
			ci.draw_arc(c, s, PI * 0.05, PI * 0.8, 16, col, 1.4, true)
			var t1 := c + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * s
			ci.draw_colored_polygon(
				PackedVector2Array([t1 + Vector2(-4, -3), t1 + Vector2(4, -2), t1 + Vector2(1, 4)]),
				col
			)
			var t2 := c + Vector2(cos(PI * 0.8), sin(PI * 0.8)) * s
			ci.draw_colored_polygon(
				PackedVector2Array([t2 + Vector2(4, 3), t2 + Vector2(-4, 2), t2 + Vector2(-1, -4)]),
				col
			)
		_:
			dia(ci, c, s * 0.6, col, col)


## The store window's veil in `r`: ink fading out over `fade` px at its sides, a hairline along its top and foot.
static func veil(ci: CanvasItem, r: Rect2, fade := 96.0) -> void:
	var ink := Color(INK, 0.62)
	var clear := Color(INK, 0.0)
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	ci.draw_rect(Rect2(x0 + fade, y0, r.size.x - fade * 2.0, r.size.y), ink)
	for side in [[x0, x0 + fade, clear, ink], [x1 - fade, x1, ink, clear]]:
		var a: float = side[0]
		var b: float = side[1]
		ci.draw_polygon(
			PackedVector2Array([Vector2(a, y0), Vector2(b, y0), Vector2(b, y1), Vector2(a, y1)]),
			PackedColorArray([side[2], side[3], side[3], side[2]])
		)
	var cx := r.get_center().x
	rule(ci, cx, y0, r.size.x * 0.5, Color(AstralCardArt.LINE, 0.9))
	rule(ci, cx, y1 - 1.0, r.size.x * 0.5, Color(AstralCardArt.LINE, 0.6))
	star4(ci, Vector2(roundf(cx) + 0.5, y0 + 0.5), 5.0, AstralCardArt.METAL, 0.2)


## A heading: a sigil, the title in letter-spaced Cinzel capitals, and an optional quieter subtitle after a diamond.
## The text is split at the first of `splits` it holds ("Altar · choose one" → ALTAR ◆ CHOOSE ONE).
class Heading:
	extends HBoxContainer

	var title := Label.new()
	var sub := Label.new()
	var size_px := 32
	var splits: Array[String] = [" · "]
	var _full := ""
	var _sigil := Control.new()
	var _gap := Control.new()

	func _init(p_size: int = 32) -> void:
		name = "Heading"
		size_px = p_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 10)
		_sigil.name = "Sigil"
		_sigil.custom_minimum_size = Vector2(roundf(p_size * 1.5), roundf(p_size * 1.5))
		_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sigil.draw.connect(_draw_sigil)
		_gap.custom_minimum_size = Vector2(40, 0)
		_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gap.draw.connect(_draw_gap)
		add_child(_sigil)
		add_child(title)
		add_child(_gap)
		add_child(sub)
		title.add_theme_font_override("font", AstralCardArt.serif(600, int(roundf(p_size * 0.32))))
		title.add_theme_font_size_override("font_size", p_size)
		title.add_theme_color_override("font_color", AstralCardArt.TEXT)
		var sub_px := int(roundf(p_size * 0.5))
		sub.add_theme_font_override("font", AstralCardArt.serif(500, int(roundf(sub_px * 0.4))))
		sub.add_theme_font_size_override("font_size", sub_px)
		sub.add_theme_color_override("font_color", AstralCardArt.DIM)
		for l: Label in [title, sub]:
			l.uppercase = true
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_color_override("font_outline_color", Color(INK, 0.6))
			l.add_theme_constant_override("outline_size", 4)

	## Shows `text` (already translated), split into title and subtitle.
	func set_text(text: String) -> void:
		_full = text
		var head := text
		var tail := ""
		for s in splits:
			var at := text.find(s)
			if at > 0:
				head = text.substr(0, at)
				tail = text.substr(at + s.length())
				break
		title.text = head
		sub.text = tail
		sub.visible = tail != ""
		_gap.visible = tail != ""

	## The whole text as given (tests).
	func full_text() -> String:
		return _full

	func _draw_sigil() -> void:
		var c := Vector2(roundf(_sigil.size.x * 0.4) + 0.5, roundf(_sigil.size.y * 0.58) + 0.5)
		AstralChrome.sigil(_sigil, c, roundf(size_px * 0.36), AstralCardArt.METAL)

	func _draw_gap() -> void:
		var c := Vector2(roundf(_gap.size.x * 0.5) + 0.5, roundf(_gap.size.y * 0.5) + 0.5)
		AstralChrome.dia(
			_gap, c, 3.0, Color(AstralCardArt.METAL, 0.8), Color(AstralCardArt.METAL, 0.8)
		)


## A hairline under a heading, fading out both ways from a small four-point star; `half` px each way (0: the width).
class Rule:
	extends Control

	var half := 0.0

	func _init(p_half: float = 0.0) -> void:
		name = "Rule"
		half = p_half
		custom_minimum_size = Vector2(p_half * 2.0, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cx := roundf(size.x * 0.5)
		var y := roundf(size.y * 0.5)
		var h := half if half > 0.0 else size.x * 0.5
		AstralChrome.rule(self, cx, y, h, Color(AstralCardArt.METAL, 0.55), 14.0)
		AstralChrome.star4(
			self, Vector2(cx + 0.5, y + 0.5), 6.0, Color(AstralCardArt.METAL, 0.85), 0.2
		)


## The hint line between two hairlines fading outward (`reach` px), a small diamond at each inner end.
class Hint:
	extends HBoxContainer

	var label := Label.new()
	var reach := 160.0

	func _init(p_reach: float = 160.0, p_size: int = 15) -> void:
		name = "Hint"
		reach = p_reach
		alignment = BoxContainer.ALIGNMENT_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 16)
		for side in [-1.0, 1.0]:
			var r := Control.new()
			r.custom_minimum_size = Vector2(p_reach + 8.0, 16)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.draw.connect(_draw_side.bind(r, side))
			add_child(r)
		add_child(label)
		move_child(label, 1)
		label.add_theme_font_override("font", HudStyle.font(false))
		label.add_theme_font_size_override("font_size", p_size)
		label.add_theme_color_override("font_color", AstralCardArt.DIM)
		label.add_theme_color_override("font_outline_color", Color(INK, 0.6))
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw_side(r: Control, side: float) -> void:
		var y := roundf(r.size.y * 0.5)
		var inner := r.size.x if side < 0.0 else 0.0
		var col := Color(AstralCardArt.METAL, 0.55)
		AstralChrome.dia(r, Vector2(roundf(inner + side * 3.0) + 0.5, y + 0.5), 2.5, col, col)
		AstralChrome.rule1(r, inner + side * 10.0, y, side * (r.size.x - 10.0), col)


## One diamond per buy (`total`), filled while it is left (`left`); the spent ones hollow.
class Pips:
	extends Control

	const STEP := 20.0
	var total := 0
	var left := 0

	func _init() -> void:
		name = "Pips"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_pips(p_left: int, p_total: int) -> void:
		left = p_left
		total = maxi(p_total, 0)
		custom_minimum_size = Vector2(STEP * total, 24)
		queue_redraw()

	func _draw() -> void:
		var y := roundf(size.y * 0.5) + 0.5
		for k in total:
			var c := Vector2(roundf(STEP * k + STEP * 0.5) + 0.5, y)
			if k < left:
				AstralChrome.dia(self, c, 5.0, AstralCardArt.METAL, AstralCardArt.ACCENT)
			else:
				AstralChrome.dia(self, c, 5.0, Color(AstralCardArt.METAL, 0.45), INK)


## A wand tile as a style box (the Swap's row): an ink fill, a 1 px frame with an inner frame 6 px in, a small diamond
## on its top edge. `focus` 1: the frame brightens, a second frame sits 6 px outside at 25 %, the fill lifts; `rim`
## (alpha > 0): a held or new card's frame colour; `dim` < 1: an empty slot, drawn fainter.
class FrameBox:
	extends StyleBox

	var focus := 0.0
	var dim := 1.0
	var rim := Color(0, 0, 0, 0)

	func _init(p_focus: float = 0.0, p_dim: float = 1.0, margins := Vector2(8, 6)) -> void:
		focus = p_focus
		dim = p_dim
		content_margin_left = margins.x
		content_margin_right = margins.x
		content_margin_top = margins.y
		content_margin_bottom = margins.y

	func _draw(to: RID, rect: Rect2) -> void:
		var lit := focus > 0.5
		var o := Rect2(rect.position.floor(), rect.size.floor())
		var line := AstralCardArt.LINE_HI if lit else AstralCardArt.LINE
		if rim.a > 0.0:
			line = rim
		line.a *= dim
		var rs := RenderingServer
		rs.canvas_item_add_rect(to, o, Color(FILL_HI if lit else FILL, (FILL.a) * dim + 0.08))
		if lit:
			rs.canvas_item_add_rect(to, o.grow(-3), Color(AstralCardArt.ACCENT, 0.07))
			_frame(to, o.grow(6), Color(AstralCardArt.LINE_HI, 0.25))
		_frame(to, o.grow(-6), Color(line, 0.28))
		_frame(to, o, line)
		if lit:
			_frame(to, o.grow(-1), Color(line, 0.4))
		var c := Vector2(roundf(o.get_center().x), o.position.y + 0.5)
		var d := AstralChrome.dia_pts(c + Vector2(0.5, 0), 3.5)
		rs.canvas_item_add_polygon(to, d, PackedColorArray([INK]))
		var out := d.duplicate()
		out.append(d[0])
		rs.canvas_item_add_polyline(to, out, PackedColorArray([line]), 1.0, true)

	func _frame(to: RID, r: Rect2, col: Color) -> void:
		var rs := RenderingServer
		rs.canvas_item_add_rect(to, Rect2(r.position, Vector2(r.size.x, 1)), col)
		rs.canvas_item_add_rect(to, Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
		rs.canvas_item_add_rect(to, Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
		rs.canvas_item_add_rect(to, Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)
