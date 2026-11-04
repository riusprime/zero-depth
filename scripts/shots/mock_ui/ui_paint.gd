extends Control
## v0.10.5 W3-O13 G2 mockups (scripts/shots/mock_ui_styles.gd): the drawing kit of the three UI styles: type,
## shapes, runes, the shard, pad buttons, panels, buttons, cards, price tags, the wallet. A prototype, not game code.
## ui_screens.gd lays the four screens out with it.

const VIEW := Vector2(1920, 1080)

## Each style's palette (see W3_O13_UI_STYLE_G2.md).
const PALETTES := {
	"veil":
	{
		"fill": Color(0.039, 0.075, 0.133, 0.55),
		"line": Color("#6FE7FF"),
		"line2": Color("#A98BFF"),
		"text": Color("#EAF6FF"),
		"dim": Color("#93ADC6"),
		"focus": Color("#8FF6FF"),
		"hp": Color("#FF5D78"),
		"heat": Color("#FF9F5A"),
		"good": Color("#8CF5C0"),
		"poor": Color("#FF6B7A"),
	},
	"obsidian":
	{
		"fill": Color("#0B0A10"),
		"fill2": Color("#1A1722"),
		"line": Color("#E3B65A"),
		"line2": Color("#FFE3A1"),
		"deep": Color("#7A5A24"),
		"text": Color("#F4ECD8"),
		"dim": Color("#A39882"),
		"focus": Color("#F2C66A"),
		"hp": Color("#C8384A"),
		"heat": Color("#E8742C"),
		"good": Color("#9BD88A"),
		"poor": Color("#FF5A4D"),
	},
	"sigil":
	{
		"line": Color("#8CFFE0"),
		"line2": Color("#FF9BD2"),
		"text": Color("#F5FFFC"),
		"dim": Color("#A6DCCF"),
		"focus": Color("#D9FFF5"),
		"hp": Color("#FF7A9C"),
		"heat": Color("#FFC26B"),
		"good": Color("#8CFFE0"),
		"poor": Color("#FF6B7A"),
	},
}

static var _fonts := {}
var style := "veil"
var kind := "hud"
var d := {}
var p := {}
## The glass panels drawn on the last draw: [Rect2, corner radius] (glass.gd blurs behind them).
var glass: Array = []


func _init(p_style: String, p_kind: String, p_data: Dictionary) -> void:
	style = p_style
	kind = p_kind
	d = p_data
	p = PALETTES[style]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = VIEW


# --- Type ---------------------------------------------------------------------------------------------------
func _font(bold: bool, track: int) -> FontVariation:
	var key := "%s_%d" % [bold, track]
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	v.base_font = HudStyle.font(bold)
	v.spacing_glyph = track
	_fonts[key] = v
	return v


## Per style: the tracking of headings and how text lifts off the frame.
func _track(heading: bool) -> int:
	match style:
		"veil":
			return 4 if heading else 0
		"obsidian":
			return 1 if heading else 0
	return 2 if heading else 0


func _tw(s: String, fs: int, bold := false, track := 0) -> float:
	return _font(bold, track).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Text with its top-left at `at` (or centred in `width` when `align` says so).
func _t(
	s: String,
	at: Vector2,
	fs: int,
	col: Color,
	bold := false,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0,
	track := 0
) -> void:
	var f := _font(bold, track)
	var base := at + Vector2(0, f.get_ascent(fs))
	match style:
		"obsidian":
			if col.get_luminance() < 0.3:  # dark type on gold: no shadow
				draw_string(f, base, s, align, width, fs, col)
				return
			draw_string(f, base + Vector2(0, 2), s, align, width, fs, Color(0, 0, 0, 0.95))
			draw_string_outline(f, base, s, align, width, fs, 3, Color(0, 0, 0, 0.8))
		"sigil":
			draw_string_outline(f, base, s, align, width, fs, 12, Color(col, 0.12))
			draw_string_outline(f, base, s, align, width, fs, 5, Color(0, 0.03, 0.04, 0.85))
		_:
			draw_string_outline(f, base, s, align, width, fs, 4, Color(0, 0.02, 0.06, 0.55))
	draw_string(f, base, s, align, width, fs, col)


func _wrap(s: String, r: Rect2, fs: int, col: Color, lines := 4) -> void:
	var f := _font(false, 0)
	var base := r.position + Vector2(0, f.get_ascent(fs))
	var al := HORIZONTAL_ALIGNMENT_CENTER
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var oc := Color(0, 0.02, 0.05, 0.7)
	draw_multiline_string_outline(f, base, s, al, r.size.x, fs, lines, 4, oc, flags)
	draw_multiline_string(f, base, s, al, r.size.x, fs, lines, col, flags)


# --- Shapes -------------------------------------------------------------------------------------------------
static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


static func _rrect(r: Rect2, rad: float, seg := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [
		[r.position + Vector2(rad, rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for c: Array in cs:
		for k in seg + 1:
			var a: float = c[1] + PI * 0.5 * float(k) / seg
			out.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return out


static func _cham(r: Rect2, c: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array(
		[
			Vector2(a.x + c, a.y),
			Vector2(b.x - c, a.y),
			Vector2(b.x, a.y + c),
			Vector2(b.x, b.y - c),
			Vector2(b.x - c, b.y),
			Vector2(a.x + c, b.y),
			Vector2(a.x, b.y - c),
			Vector2(a.x, a.y + c),
		]
	)


## A tall hexagon pointed at top and bottom (the sigil card).
static func _hex(r: Rect2, tip: float) -> PackedVector2Array:
	var cx := r.get_center().x
	return PackedVector2Array(
		[
			Vector2(cx, r.position.y),
			Vector2(r.end.x, r.position.y + tip),
			Vector2(r.end.x, r.end.y - tip),
			Vector2(cx, r.end.y),
			Vector2(r.position.x, r.end.y - tip),
			Vector2(r.position.x, r.position.y + tip),
		]
	)


## A wide hexagon pointed at left and right (the sigil button).
static func _lozenge(r: Rect2, tip: float) -> PackedVector2Array:
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


static func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array(
		[c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]
	)


func _glow(pts: PackedVector2Array, col: Color, w: float, k := 1.0) -> void:
	draw_polyline(pts, Color(col, 0.05 * k), w * 9.0, true)
	draw_polyline(pts, Color(col, 0.12 * k), w * 4.0, true)
	draw_polyline(pts, col, w, true)


func _ring(c: Vector2, r: float, col: Color, w: float, k := 1.0) -> void:
	draw_arc(c, r, 0, TAU, 72, Color(col, 0.05 * k), w * 9.0, true)
	draw_arc(c, r, 0, TAU, 72, Color(col, 0.13 * k), w * 4.0, true)
	draw_arc(c, r, 0, TAU, 72, col, w, true)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array(
			[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		),
		PackedColorArray([top, top, bottom, bottom])
	)


## A gradient inside any convex outline, from `top` to `bottom` by height.
func _poly_grad(pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for q in pts:
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bottom, (q.y - y0) / maxf(1.0, y1 - y0)))
	draw_polygon(pts, cols)


# --- Runes, shard, pad buttons ------------------------------------------------------------------------------
func _rune(g: int, at: Vector2, h: float, col: Color, w := 1.5) -> void:
	var k := h / RunicGlyphs.H
	for line: PackedVector2Array in RunicGlyphs.strokes(g):
		var pts := PackedVector2Array()
		for q in line:
			pts.append(at + q * k)
		draw_polyline(pts, col, w, true)


## A word written in runes from `at` (top-left); returns its width.
func _runes(s: String, at: Vector2, h: float, col: Color, w := 1.5) -> float:
	var x := 0.0
	var step := h * 0.5 + h * 0.35
	for g in RuneCipher.encode(s.to_upper()):
		if g != RuneCipher.GAP:
			_rune(g, at + Vector2(x, 0), h, col, w)
		x += step
	return x


## Runes around a circle, upright to the rim, starting at the top.
func _rune_ring(c: Vector2, r: float, s: String, h: float, col: Color, w := 1.4) -> void:
	var word := RuneCipher.encode(s.to_upper())
	word.append(RuneCipher.GAP)
	var gs: Array[int] = []
	while gs.size() < 14:  # a short word repeats round the ring
		gs.append_array(word)
	var n := gs.size()
	for k in n:
		if gs[k] == RuneCipher.GAP:
			continue
		var a := -PI * 0.5 + TAU * float(k) / n
		draw_set_transform(c + Vector2(cos(a), sin(a)) * r, a + PI * 0.5, Vector2.ONE)
		_rune(gs[k], Vector2(-h * 0.25, -h * 0.5), h, col, w)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The shard (ShardIcon's crystal) centred on `c`, `h` tall.
func _shard(c: Vector2, h: float) -> void:
	var w := h * 0.8
	var o := c - Vector2(w, h) * 0.5
	var top := o + Vector2(w * 0.5, 0)
	var bottom := o + Vector2(w * 0.5, h)
	var left := o + Vector2(0, h * 0.4)
	var right := o + Vector2(w, h * 0.4)
	var mid := o + Vector2(w * 0.5, h * 0.48)
	draw_colored_polygon(PackedVector2Array([top, left, mid]), ShardIcon.LIGHT)
	draw_colored_polygon(PackedVector2Array([top, mid, right]), ShardIcon.MID)
	draw_colored_polygon(PackedVector2Array([left, bottom, mid]), ShardIcon.MID)
	draw_colored_polygon(PackedVector2Array([mid, bottom, right]), ShardIcon.DARK)


## A price (shard + number) centred on `c`; returns its width.
func _price(amount: int, c: Vector2, fs: int, ok := true) -> float:
	var s := str(amount)
	var tw := _tw(s, fs, true)
	var sh := fs * 0.95
	var w := sh * 0.8 + 8.0 + tw
	var x := c.x - w * 0.5
	_shard(Vector2(x + sh * 0.4, c.y), sh)
	var f := _font(true, 0)
	var top := c.y - (f.get_ascent(fs) + f.get_descent(fs)) * 0.5
	_t(s, Vector2(x + sh * 0.8 + 8.0, top), fs, p["text"] if ok else p["poor"], true)
	return w


## A pad button in the style's shape, centred on `c`.
func _pad(letter: String, c: Vector2, r: float, tint: Color) -> void:
	var f := _font(true, 0)
	var fs := int(r * 1.05)
	match style:
		"obsidian":
			var dm := _diamond(c, r * 1.15)
			draw_colored_polygon(dm, Color(0.02, 0.02, 0.03))
			draw_polyline(_closed(dm), p["line"], 2.0, true)
		"sigil":
			_ring(c, r, tint, 1.6, 0.8)
		_:
			draw_circle(c, r, Color(0.02, 0.05, 0.1, 0.8))
			draw_arc(c, r - 1.0, 0, TAU, 40, tint, 2.0, true)
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), letter, 0, -1, fs, tint)


# --- Panels, buttons ----------------------------------------------------------------------------------------
## A big framed panel (the shop's window, the pause column, the HUD's plates when `small`).
func _panel(r: Rect2, small := false) -> void:
	match style:
		"veil":
			var rad := 10.0 if small else 18.0
			glass.append([r, rad])
			var pts := _rrect(r, rad)
			draw_colored_polygon(pts, p["fill"])
			_vgrad(
				Rect2(r.position + Vector2(rad, 1), Vector2(r.size.x - rad * 2, 2)),
				Color(1, 1, 1, 0.18),
				Color(1, 1, 1, 0.0)
			)
			var edge := Color(p["line"], 0.45 if small else 0.6)
			_glow(_closed(pts), edge, 1.2, 0.6 if small else 1.0)
			if not small:  # violet light on the lower edge
				draw_line(
					r.position + Vector2(r.size.x * 0.25, r.size.y),
					r.position + Vector2(r.size.x * 0.75, r.size.y),
					Color(p["line2"], 0.8),
					2.0,
					true
				)
		"obsidian":
			var c := 10.0 if small else 22.0
			var pts := _cham(r, c)
			_poly_grad(pts, p["fill2"], p["fill"])
			draw_polyline(_closed(pts), p["line"], 2.0 if small else 2.5, true)
			if not small:
				var inner := _cham(r.grow(-9), c - 5)
				draw_polyline(_closed(inner), Color(p["line"], 0.45), 1.0, true)
				_engrave(r)
		_:
			# The sigil style has no panel: a light line above and below with the runes along it.
			var y0 := r.position.y
			var y1 := r.end.y
			for y in [y0, y1]:
				var a := Vector2(r.position.x + 40, y)
				var b := Vector2(r.end.x - 40, y)
				_glow(PackedVector2Array([a, b]), Color(p["line"], 0.75), 1.2, 0.7)
				for x in [a, b]:
					_ring(x, 5, p["line"], 1.4)


## The obsidian frame's gold engraving: corner brackets and a rune band on the top and bottom edges.
func _engrave(r: Rect2) -> void:
	var g: Color = p["line"]
	var words: String = d.get("engrave", "ZERO DEPTH")
	var w := _runes(words, Vector2(-10000, 0), 14, g)
	for y in [r.position.y - 7.0, r.end.y - 7.0]:
		var x := r.get_center().x - w * 0.5
		draw_rect(Rect2(x - 18, y - 2, w + 36, 18), p["fill"])
		_runes(words, Vector2(x, y), 14, Color(g, 0.9), 1.3)
	for corner in [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
	]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		var o: Vector2 = corner + Vector2(sx, sy) * 4.0
		draw_polyline(
			PackedVector2Array(
				[
					o + Vector2(0, sy * 46),
					o + Vector2(0, sy * 22),
					o + Vector2(sx * 22, 0),
					o + Vector2(sx * 46, 0)
				]
			),
			p["line2"],
			3.0,
			true
		)


## A wide button: a pad glyph at the left, its name, the price large at the right. `accent` names the service.
func _button(
	r: Rect2, glyph: String, gtint: Color, title: String, price: int, accent: Color, focused: bool
) -> void:
	var tc: Color = p["text"]
	match style:
		"veil":
			var pts := _rrect(r, r.size.y * 0.5, 8)
			glass.append([r, r.size.y * 0.5])
			draw_colored_polygon(
				pts, Color(accent, 0.16) if not focused else Color(p["focus"], 0.28)
			)
			_glow(
				_closed(pts),
				accent if not focused else p["focus"],
				2.0 if not focused else 3.0,
				1.0 if not focused else 1.8
			)
		"obsidian":
			var pts := _cham(r, 14)
			if focused:
				_poly_grad(pts, p["line2"], p["line"])
				tc = Color("#120E08")
			else:
				_poly_grad(pts, Color("#24202C"), Color("#121016"))
			draw_polyline(_closed(pts), p["line"], 2.5, true)
			draw_line(
				r.position + Vector2(16, 4),
				Vector2(r.end.x - 16, r.position.y + 4),
				Color(accent, 0.9),
				2.0
			)
		_:
			var k := 1.8 if focused else 1.0
			var pts := _lozenge(r, r.size.y * 0.42)
			_poly_grad(pts, Color(accent, 0.06 * k), Color(accent, 0.26 * k))
			_glow(_closed(pts), accent if not focused else p["focus"], 1.6, k)
			_rune(
				15,
				Vector2(r.end.x - r.size.y * 0.42 - 20, r.position.y + 10),
				r.size.y - 20,
				Color(accent, 0.35),
				1.2
			)
	var pc := Vector2(r.position.x + r.size.y * 0.5 + 4, r.get_center().y)
	_pad(
		glyph,
		pc,
		r.size.y * 0.24,
		gtint if style != "obsidian" or not focused else Color("#120E08")
	)
	_t(title, Vector2(pc.x + r.size.y * 0.42, r.get_center().y - 14), 24, tc, true)
	var pr := Vector2(r.end.x - 70, r.get_center().y)
	if style == "obsidian" and focused:
		var s := str(price)
		_shard(Vector2(pr.x - 30, pr.y), 30)
		draw_string(_font(true, 0), Vector2(pr.x - 8, pr.y + 12), s, 0, -1, 34, tc)
	elif style == "sigil":
		_price(price, Vector2(r.end.x - r.size.y * 0.42 - 70, pr.y), 34)
	else:
		_price(price, pr, 34)


# --- Cards --------------------------------------------------------------------------------------------------
## A card face in the style: name, the item's icon in its frame, the element glyph, the sentence, the tier line.
func _card(r: Rect2, face: Dictionary, focused: bool) -> void:
	var col: Color = face.get("color", p["line"])
	var s := r.size.x / 250.0
	if focused:
		r = Rect2(r.position - Vector2(0, 12 * s), r.size)
	var icon_c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.34)
	var icon_r := 46.0 * s
	var title_y := r.position.y + 20 * s
	var title_c: Color = p["text"]
	match style:
		"veil":
			var pts := _rrect(r, 14 * s)
			glass.append([r, 14 * s])
			draw_colored_polygon(pts, Color("#081020", 0.55))
			_vgrad(
				Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.45)),
				Color(col, 0.28),
				Color(col, 0.0)
			)
			if focused:
				_glow(_closed(pts), p["focus"], 3.0, 2.2)
			else:
				_glow(_closed(pts), Color(col, 0.7), 1.4, 0.5)
			draw_arc(icon_c, icon_r, 0, TAU, 64, Color(col, 0.85), 1.6, true)
			draw_arc(
				icon_c, icon_r + 6 * s, -PI * 0.8, -PI * 0.2, 24, Color(p["line2"], 0.6), 1.2, true
			)
		"obsidian":
			var pts := _cham(r, 16 * s)
			_poly_grad(pts, Color("#1C1924"), Color("#0A090D"))
			var band := Rect2(
				r.position + Vector2(10 * s, 10 * s), Vector2(r.size.x - 20 * s, 40 * s)
			)
			if focused:
				draw_colored_polygon(_cham(band, 6 * s), p["line"])
				title_c = Color("#120E08")
			else:
				draw_polyline(_closed(_cham(band, 6 * s)), Color(col, 0.8), 1.5, true)
			draw_polyline(
				_closed(pts),
				p["line2"] if focused else Color(p["line"], 0.8),
				4.0 if focused else 2.0,
				true
			)
			draw_polyline(_closed(_cham(r.grow(-5 * s), 13 * s)), Color(col, 0.75), 1.5, true)
			var dm := _diamond(icon_c, icon_r * 1.25)
			draw_colored_polygon(dm, Color(0, 0, 0, 0.6))
			draw_polyline(_closed(dm), p["line"], 2.0, true)
			draw_polyline(_closed(_diamond(icon_c, icon_r * 1.12)), Color(col, 0.7), 1.2, true)
			if focused:  # outer brackets
				for k in [-1.0, 1.0]:
					var x: float = r.get_center().x + k * (r.size.x * 0.5 + 12)
					draw_polyline(
						PackedVector2Array(
							[
								Vector2(x - k * 10, r.position.y + 30),
								Vector2(x, r.position.y + 30),
								Vector2(x, r.end.y - 30),
								Vector2(x - k * 10, r.end.y - 30)
							]
						),
						p["line2"],
						3.0,
						true
					)
			title_y += 3 * s
		_:
			var tip := 26.0 * s
			var pts := _hex(r, tip)
			_poly_grad(pts, Color(0.0, 0.025, 0.04, 0.84), Color(col.darkened(0.75), 0.72))
			_glow(
				_closed(pts),
				col if not focused else p["focus"],
				1.6 if not focused else 2.4,
				0.9 if not focused else 2.0
			)
			if focused:
				_glow(_closed(_hex(r.grow(9), tip + 5)), Color(col, 0.6), 1.0, 0.8)
				draw_polygon(
					PackedVector2Array(
						[
							Vector2(r.get_center().x - 60, r.end.y + 6),
							Vector2(r.get_center().x + 60, r.end.y + 6),
							Vector2(r.get_center().x + 10, r.end.y + 40),
							Vector2(r.get_center().x - 10, r.end.y + 40)
						]
					),
					PackedColorArray(
						[Color(col, 0.35), Color(col, 0.35), Color(col, 0.0), Color(col, 0.0)]
					)
				)
			_ring(icon_c, icon_r, col, 1.4, 1.4 if focused else 0.8)
			_rune_ring(
				icon_c,
				icon_r + 13 * s,
				String(face.get("title", "")),
				13 * s,
				Color(col, 0.85 if focused else 0.45),
				1.2
			)
			title_y += tip * 0.55
	var title := String(face.get("title", "")).to_upper()
	var fs := int(21 * s)
	var tw := r.size.x - 24 * s
	while fs > 12 and _tw(title, fs, true, _track(true) / 2) > tw:
		fs -= 1
	_t(
		title,
		Vector2(r.position.x + 12 * s, title_y),
		fs,
		title_c if style == "obsidian" else (col.lightened(0.45) if style == "sigil" else title_c),
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		tw,
		_track(true) / 2
	)
	var icon_rect := Rect2(icon_c - Vector2.ONE * icon_r * 0.62, Vector2.ONE * icon_r * 1.24)
	ItemIcons.draw(self, face.get("id", &""), icon_rect, col.lightened(0.25))
	var glyph := ElementGlyphs.glyph_of(face.get("id", &""))
	if glyph != &"":
		var gc := icon_c + Vector2(icon_r * 0.8, icon_r * 0.65)
		draw_circle(gc, 14 * s, Color(0, 0, 0, 0.75))
		ElementGlyphs.draw(self, glyph, Rect2(gc - Vector2.ONE * 13 * s, Vector2.ONE * 26 * s))
	var lv := String(face.get("level_text", ""))
	if lv != "":
		_t(
			lv,
			Vector2(
				r.end.x - 16 * s - _tw(lv, int(13 * s), true),
				r.position.y + (60 if style == "obsidian" else 8) * s
			),
			int(13 * s),
			p["dim"],
			true
		)
	var y := icon_c.y + icon_r + 20 * s
	var gain: Dictionary = face.get("gain", {})
	if CardGain.shows(gain):
		_t(
			CardGain.final_text(self, gain),
			Vector2(r.position.x, y),
			int(15 * s),
			p["good"],
			true,
			HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x
		)
		y += 22 * s
	_wrap(
		String(face.get("sentence", "")),
		Rect2(r.position.x + 18 * s, y, r.size.x - 36 * s, r.end.y - y - 50 * s),
		int(17 * s),
		p["text"]
	)
	var tier := String(face.get("tier_text", ""))
	var ty := r.end.y - (58 if style == "sigil" else 34) * s
	var tfs := int(13 * s)
	while tfs > 9 and _tw(tier, tfs, true, 1) > r.size.x - 28:
		tfs -= 1
	_t(
		tier,
		Vector2(r.position.x + 8, ty),
		tfs,
		Color(col.lightened(0.3), 0.9),
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 16,
		1
	)


## A card's price tag under it.
func _tag(c: Vector2, price: int, ok: bool) -> void:
	var r := Rect2(c - Vector2(66, 22), Vector2(132, 44))
	match style:
		"veil":
			glass.append([r, 22.0])
			var pts := _rrect(r, 22)
			draw_colored_polygon(pts, Color("#081020", 0.5))
			draw_polyline(_closed(pts), Color(p["line"], 0.5), 1.2, true)
		"obsidian":
			draw_line(c - Vector2(0, 34), c - Vector2(0, 22), p["line"], 2.0)
			var pts := _cham(r, 8)
			draw_colored_polygon(pts, p["fill"])
			draw_polyline(_closed(pts), p["line"], 2.0, true)
		_:
			draw_arc(
				c + Vector2(0, -60), 70, PI * 0.3, PI * 0.7, 24, Color(p["line"], 0.5), 1.2, true
			)
	_price(price, c, 26, ok)


## The shop's buys-left: the line and one mark per buy (the spent ones faint).
func _pips(right: Vector2, fs: int) -> float:
	var left := int(d["buys_left"])
	var cap := int(d["max_buys"])
	var x := right.x
	for k in range(cap - 1, -1, -1):
		var c := Vector2(x - 9, right.y)
		var on := k < left
		match style:
			"veil":
				draw_circle(c, 6, Color(p["line"], 0.9) if on else Color(p["line"], 0.15))
				if on:
					draw_circle(c, 11, Color(p["line"], 0.12))
			"obsidian":
				var dm := _diamond(c, 8)
				if on:
					draw_colored_polygon(dm, p["line"])
				draw_polyline(_closed(dm), p["line"], 1.5, true)
			_:
				_rune(14, c - Vector2(5, 10), 20, Color(p["line"], 1.0 if on else 0.2), 1.8)
		x -= 24
	var s: String = d["buys_text"]
	var w := _tw(s, fs)
	_t(s, Vector2(x - 12 - w, right.y - fs * 0.62), fs, p["dim"])
	return right.x - (x - 12 - w)


## The wallet: the shards held, large.
func _wallet(r: Rect2, fs: int) -> void:
	match style:
		"veil":
			glass.append([r, r.size.y * 0.5])
			var pts := _rrect(r, r.size.y * 0.5, 8)
			draw_colored_polygon(pts, Color(ShardIcon.DARK, 0.25))
			_glow(_closed(pts), Color(ShardIcon.MID, 0.8), 1.4, 0.8)
		"obsidian":
			var pts := _cham(r, 10)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.7))
			draw_polyline(_closed(pts), p["line"], 2.0, true)
		_:
			var pts := _lozenge(r, r.size.y * 0.4)
			_poly_grad(pts, Color(ShardIcon.DARK, 0.1), Color(ShardIcon.DARK, 0.35))
			_glow(_closed(pts), ShardIcon.MID, 1.4, 0.8)
	_price(int(d["wallet"]), r.get_center(), fs)
