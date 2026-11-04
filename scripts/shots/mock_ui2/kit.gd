extends Control
## v0.10.5 W3-O13b G2, round 2 (scripts/shots/mock_ui_refs.gd): the drawing kit of the four UI styles made after the
## owner's references (docs/roadmap/v0.10.5/ui_refs/): type, crisp hairlines, shapes, ornaments, panels and cards
## (parts.gd adds the buttons, bars and controls). A prototype for the G2, not game code. screens.gd lays the
## screens out with it. Straight lines are 1 px rects on whole pixels; only diagonals and curves are antialiased.

const VIEW := Vector2(1920, 1080)
const CINZEL := "res://assets/fonts/cinzel/Cinzel-Variable.ttf"
## The Futhark rune on the HP medallion (RunicGlyphs index).
const HP_RUNE := 14

## Each style's palette (W3_O13_UI_STYLE_G2.md, Round 2).
const PALETTES := {
	"slate":
	{
		"fill": Color("#101824", 0.86),
		"fill_hi": Color("#1A2536", 0.95),
		"line": Color("#33435A"),
		"line_hi": Color("#AFC3DC"),
		"accent": Color("#8FB8E8"),
		"metal": Color("#A7B4C6"),
		"text": Color("#E3E9F1"),
		"dim": Color("#8593A8"),
		"faint": Color("#3E4C60"),
		"hp": Color("#8DB4E2"),
		"heat": Color("#CFA06E"),
		"poor": Color("#D07C86"),
		"ink": Color("#090E16"),
	},
	"eclipse":
	{
		"fill": Color("#141920", 0.93),
		"fill_hi": Color("#1C222B", 0.96),
		"line": Color("#6A7686"),
		"line_hi": Color("#DCE8F7"),
		"accent": Color("#A9C7EC"),
		"metal": Color("#B9C4D2"),
		"text": Color("#E9EDF2"),
		"dim": Color("#8E97A4"),
		"faint": Color("#46505E"),
		"hp": Color("#9CC0E8"),
		"heat": Color("#D4A26C"),
		"poor": Color("#D07C86"),
		"ink": Color("#07090D"),
	},
	"astral":
	{
		"fill": Color("#0D1120", 0.84),
		"fill_hi": Color("#141A2F", 0.92),
		"line": Color("#6E76A0"),
		"line_hi": Color("#E4E6FF"),
		"accent": Color("#B5BDF0"),
		"metal": Color("#C9CCE6"),
		"text": Color("#ECEEFA"),
		"dim": Color("#9095B4"),
		"faint": Color("#3F4566"),
		"hp": Color("#B4BFF0"),
		"heat": Color("#D6A878"),
		"poor": Color("#D88A9A"),
		"ink": Color("#070913"),
	},
	"observatory":
	{
		"fill": Color("#0E1523", 0.88),
		"fill_hi": Color("#152034", 0.95),
		"line": Color("#53627B"),
		"line_hi": Color("#CBD9EE"),
		"accent": Color("#8DB6E6"),
		"metal": Color("#A3AEBF"),
		"text": Color("#E2E8F1"),
		"dim": Color("#7E8BA0"),
		"faint": Color("#34415A"),
		"hp": Color("#93BCEA"),
		"heat": Color("#D0A06C"),
		"poor": Color("#D07C86"),
		"ink": Color("#080C14"),
	},
}

## The small rarity diamond: common, rare, epic, ability, legendary (CardFrames.LEGENDARY_TIER is 4).
const RARITY := [
	Color("#8C98A8"), Color("#8FB8E8"), Color("#B4A2E6"), Color("#C9D8EE"), Color("#E2CB8E")
]

static var _fonts := {}
static var _cinzel: Font = null
static var _stone_tex: Texture2D = null
var style := "slate"
var kind := "hud"
var d := {}
var p := {}
## The panels drawn on the last draw: [Rect2, corner cut] (glass2.gd blurs the world behind them).
var glass: Array = []


func _init(p_style: String, p_kind: String, p_data: Dictionary) -> void:
	style = p_style
	kind = p_kind
	d = p_data
	p = PALETTES[style]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	position = Vector2.ZERO
	size = VIEW


# --- Type ---------------------------------------------------------------------------------------------------
static func _cinzel_base() -> Font:
	if _cinzel == null:
		if ResourceLoader.exists(CINZEL):
			_cinzel = load(CINZEL)
		else:
			var f := FontFile.new()
			f.load_dynamic_font(ProjectSettings.globalize_path(CINZEL))
			_cinzel = f
	return _cinzel


## Cinzel at weight `wght` (its variable axis) with `track` px between letters.
func _serif(wght: int, track: int) -> FontVariation:
	var key := "s%d_%d" % [wght, track]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = _cinzel_base()
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
		v.spacing_glyph = track
		_fonts[key] = v
	return _fonts[key]


## Atkinson Hyperlegible (the game's body font) with `track`.
func _sans(bold: bool, track: int) -> FontVariation:
	var key := "a%s_%d" % [bold, track]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = HudStyle.font(bold).base_font
		v.spacing_glyph = track
		_fonts[key] = v
	return _fonts[key]


## The drawn width (without the tracking after the last letter).
func _width(f: Font, s: String, fs: int) -> float:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if f is FontVariation:
		w -= (f as FontVariation).spacing_glyph
	return w


## Text on the baseline `base`; `align` 0 starts at x, 1 centres on x, 2 ends at x. `halo` (over the world) rings
## it with ink; else a 1 px drop shadow. Returns the width.
func _text(
	f: Font, s: String, x: float, base: float, fs: int, col: Color, align := 0, halo := false
) -> float:
	var w := _width(f, s, fs)
	var at := Vector2(roundf(x - w * 0.5 * align), roundf(base))
	if halo:
		draw_string_outline(
			f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(p["ink"], 0.72 * col.a)
		)
	else:
		draw_string(
			f,
			at + Vector2(0, 1),
			s,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color(0, 0, 0, 0.55 * col.a)
		)
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return w


## An uppercase serif caption (titles, labels, menu items).
func _cap(
	s: String,
	x: float,
	base: float,
	fs: int,
	col: Color,
	track: int,
	align := 0,
	wght := 600,
	halo := false
) -> float:
	return _text(_serif(wght, track), s.to_upper(), x, base, fs, col, align, halo)


## Body text in Atkinson.
func _body(
	s: String, x: float, base: float, fs: int, col: Color, align := 0, bold := false, halo := false
) -> float:
	return _text(_sans(bold, 0), s, x, base, fs, col, align, halo)


## Wrapped body text centred in `r` (the first baseline at r.y + ascent).
func _wrap(s: String, r: Rect2, fs: int, col: Color, lines := 4) -> void:
	var f := _sans(false, 0)
	var at := Vector2(roundf(r.position.x), roundf(r.position.y + f.get_ascent(fs)))
	var al := HORIZONTAL_ALIGNMENT_CENTER
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	draw_multiline_string(
		f, at + Vector2(0, 1), s, al, r.size.x, fs, lines, Color(0, 0, 0, 0.55), flags
	)
	draw_multiline_string(f, at, s, al, r.size.x, fs, lines, col, flags)


## The largest size <= fs at which `s` fits in `w`.
func _fit(f: Font, s: String, fs: int, w: float, smallest := 10) -> int:
	while fs > smallest and _width(f, s, fs) > w:
		fs -= 1
	return fs


# --- Crisp lines --------------------------------------------------------------------------------------------
func _h(x0: float, x1: float, y: float, col: Color, w := 1.0) -> void:
	var a := roundf(minf(x0, x1))
	draw_rect(Rect2(a, roundf(y), roundf(maxf(x0, x1)) - a, w), col)


func _v(x: float, y0: float, y1: float, col: Color, w := 1.0) -> void:
	var a := roundf(minf(y0, y1))
	draw_rect(Rect2(roundf(x), a, w, roundf(maxf(y0, y1)) - a), col)


## A 1 px rectangle outline on whole pixels.
func _frame(r: Rect2, col: Color) -> void:
	var x0 := roundf(r.position.x)
	var y0 := roundf(r.position.y)
	var x1 := roundf(r.end.x) - 1.0
	var y1 := roundf(r.end.y) - 1.0
	_h(x0, x1 + 1, y0, col)
	_h(x0, x1 + 1, y1, col)
	_v(x0, y0 + 1, y1, col)
	_v(x1, y0 + 1, y1, col)


## A hairline fading out both ways from `cx` (six steps), leaving `gap` clear in the middle.
func _rule(cx: float, y: float, half: float, col: Color, gap := 0.0) -> void:
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		var c0 := gap + (half - gap) * k / 6.0
		var c1 := gap + (half - gap) * (k + 1) / 6.0
		_h(cx - c1, cx - c0, y, Color(col, a))
		_h(cx + c0, cx + c1, y, Color(col, a))


## A hairline from `x0` fading out over `length` (negative: leftwards).
func _rule1(x0: float, y: float, length: float, col: Color) -> void:
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		_h(x0 + length * k / 6.0, x0 + length * (k + 1) / 6.0, y, Color(col, a))


func _ln(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	draw_line(a, b, col, w, true)


func _poly(pts: PackedVector2Array, col: Color, w := 1.0) -> void:
	draw_polyline(_closed(pts), col, w, true)


func _arc(c: Vector2, r: float, a0: float, a1: float, col: Color, w := 1.0) -> void:
	draw_arc(c, r, a0, a1, maxi(8, int(absf(a1 - a0) * r / 3.0)), col, w, true)


# --- Shapes -------------------------------------------------------------------------------------------------
static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## A rectangle on half pixels (so 1 px antialiased outlines fall on whole pixels).
static func _px(r: Rect2) -> Rect2:
	return Rect2(
		Vector2(roundf(r.position.x) + 0.5, roundf(r.position.y) + 0.5),
		Vector2(roundf(r.size.x) - 1.0, roundf(r.size.y) - 1.0)
	)


## The rectangle with its four corners cut by `c`.
static func _cut(r: Rect2, c: float) -> PackedVector2Array:
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


## A long plate pointed at both ends (`tip` deep).
static func _hexplate(r: Rect2, tip: float) -> PackedVector2Array:
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


## A chipped stone tablet: the corners cut unevenly and small breaks along the edges, fixed by `seed`.
static func _carve(r: Rect2, c: float, seed: int) -> PackedVector2Array:
	var h := func(k: int) -> float:
		return fposmod(sin(float(seed * 37 + k * 11) * 1.37) * 4375.85, 1.0)
	var a := r.position
	var b := r.end
	var cs: Array[float] = []
	for k in 4:
		cs.append(roundf(c * (0.65 + 0.7 * float(h.call(k)))))
	var pts: Array[Vector2] = []
	var edges := [
		[Vector2(a.x + cs[0], a.y), Vector2(b.x - cs[1], a.y), Vector2(0, 1)],
		[Vector2(b.x, a.y + cs[1]), Vector2(b.x, b.y - cs[2]), Vector2(-1, 0)],
		[Vector2(b.x - cs[2], b.y), Vector2(a.x + cs[3], b.y), Vector2(0, -1)],
		[Vector2(a.x, b.y - cs[3]), Vector2(a.x, a.y + cs[0]), Vector2(1, 0)],
	]
	for e in 4:
		var p0: Vector2 = edges[e][0]
		var p1: Vector2 = edges[e][1]
		var n: Vector2 = edges[e][2]
		pts.append(p0)
		for t: float in [
			0.2 + 0.3 * float(h.call(e * 5 + 1)), 0.6 + 0.25 * float(h.call(e * 5 + 2))
		]:
			pts.append(p0.lerp(p1, t) + n * roundf(-1.0 + 2.0 * float(h.call(e * 5 + 3))))
		pts.append(p1)
	return PackedVector2Array(pts)


## The astral style's card: a crest whose shoulders sweep up to the finial's point (`sh` deep), straight sides, and
## a keel at the bottom.
static func _arch(r: Rect2, sh: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	var cx := r.get_center().x
	var pts: Array[Vector2] = []
	var curve := func(p0: Vector2, p2: Vector2, ctrl: Vector2) -> void:
		for k in 13:
			var t := k / 12.0
			pts.append(p0.lerp(ctrl, t).lerp(ctrl.lerp(p2, t), t))
	curve.call(
		Vector2(a.x, a.y + sh), Vector2(cx - 16, a.y), Vector2(cx - r.size.x * 0.12, a.y + sh)
	)
	pts.append(Vector2(cx, a.y - 10))
	curve.call(
		Vector2(cx + 16, a.y), Vector2(b.x, a.y + sh), Vector2(cx + r.size.x * 0.12, a.y + sh)
	)
	curve.call(
		Vector2(b.x, b.y - sh * 0.8),
		Vector2(cx + 18, b.y),
		Vector2(cx + r.size.x * 0.12, b.y - sh * 0.8)
	)
	pts.append(Vector2(cx, b.y + 12))
	curve.call(
		Vector2(cx - 18, b.y),
		Vector2(a.x, b.y - sh * 0.8),
		Vector2(cx - r.size.x * 0.12, b.y - sh * 0.8)
	)
	return PackedVector2Array(pts)


static func _dia_pts(c: Vector2, rx: float, ry := -1.0) -> PackedVector2Array:
	if ry < 0.0:
		ry = rx
	return PackedVector2Array(
		[c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)]
	)


## A diamond: outlined in `col`, filled with `fill` when it has alpha.
func _dia(c: Vector2, r: float, col: Color, fill := Color(0, 0, 0, 0), w := 1.0) -> void:
	var pts := _dia_pts(c, r)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	if col.a > 0.0:
		_poly(pts, col, w)


## A four-point star (the separator spark).
func _star4(c: Vector2, r: float, col: Color, inner := 0.22) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI * 0.5 + PI * 0.25 * k
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * inner))
	draw_colored_polygon(pts, col)


## An eight-point compass star with lit and shaded facets (the observatory's mark).
func _compass(c: Vector2, r: float, col: Color) -> void:
	var tips: Array[Vector2] = []
	var sh: Array[Vector2] = []
	for k in 8:
		var a := -PI * 0.5 + PI * 0.25 * k
		tips.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.52))
		var b := a + PI * 0.125
		sh.append(c + Vector2(cos(b), sin(b)) * r * 0.13)
	for k in 8:
		var prev: Vector2 = sh[(k + 7) % 8]
		draw_colored_polygon(PackedVector2Array([c, prev, tips[k]]), Color(col, col.a * 0.95))
		draw_colored_polygon(PackedVector2Array([c, tips[k], sh[k]]), Color(col, col.a * 0.4))


## Tick marks round a circle between radii r0 and r1.
func _ticks(c: Vector2, r0: float, r1: float, n: int, col: Color, a0 := -PI * 0.5) -> void:
	for k in n:
		var a := a0 + TAU * k / n
		var u := Vector2(cos(a), sin(a))
		_ln(c + u * r0, c + u * r1, col)


## A thin crescent moon on `c`, its lit side facing `facing` (radians).
func _crescent(c: Vector2, r: float, col: Color, facing := -PI * 0.5) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var a := facing - 1.75 + 3.5 * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var ic := c - Vector2(cos(facing), sin(facing)) * r * 0.32
	for k in 17:
		var a := facing + 1.45 - 2.9 * k / 16.0
		pts.append(ic + Vector2(cos(a), sin(a)) * r * 0.86)
	draw_colored_polygon(pts, col)


## The polygon grown (+) or shrunk (-) by `delta`.
static func _contour(pts: PackedVector2Array, delta: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(pts, delta, Geometry2D.JOIN_MITER)
	return out[0] if not out.is_empty() else pts


## The light catching a carved edge: the inner contour's top-left edges lit, its bottom-right edges shaded.
func _bevel(pts: PackedVector2Array, inset: float, light: Color, dark: Color) -> void:
	var q := _contour(pts, -inset)
	var cen := Vector2.ZERO
	for v in q:
		cen += v
	cen /= q.size()
	for k in q.size():
		var a := q[k]
		var b := q[(k + 1) % q.size()]
		var n := Vector2(b.y - a.y, a.x - b.x).normalized()
		if n.dot((a + b) * 0.5 - cen) < 0.0:
			n = -n
		_ln(a, b, light if n.x * 0.5 + n.y < 0.0 else dark)


## A dark wash just inside a rectangle (the recessed look), crisp.
func _inset(r: Rect2, depth: int, alpha: float) -> void:
	for k in depth:
		_frame(r.grow(-1.0 - k), Color(0, 0, 0, alpha * (1.0 - float(k) / depth)))


## Fine stone grain (the eclipse style's tablets).
static func _stone() -> Texture2D:
	if _stone_tex == null:
		var n := FastNoiseLite.new()
		n.seed = 7
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 5
		_stone_tex = ImageTexture.create_from_image(n.get_seamless_image(256, 256))
	return _stone_tex


func _stone_fill(pts: PackedVector2Array, base: Color) -> void:
	draw_colored_polygon(pts, base)
	var uvs := PackedVector2Array()
	for q in pts:
		uvs.append(q / 256.0)
	draw_colored_polygon(pts, Color(0.6, 0.68, 0.8, 0.1), uvs, _stone())


## A Futhark rune `g` (RunicGlyphs) centred on `c`, `h` tall.
func _rune(g: int, c: Vector2, h: float, col: Color, w := 1.4) -> void:
	var k := h / RunicGlyphs.H
	var at := c - Vector2(h * 0.25, h * 0.5)
	for line: PackedVector2Array in RunicGlyphs.strokes(g):
		var pts := PackedVector2Array()
		for q in line:
			pts.append(at + q * k)
		draw_polyline(pts, col, w, true)


# --- Small parts --------------------------------------------------------------------------------------------
## The shard as line art (an outlined crystal) centred on `c`.
func _shard(c: Vector2, h: float, col: Color) -> void:
	var rx := h * 0.34
	var top := c + Vector2(0, -h * 0.5)
	var bot := c + Vector2(0, h * 0.5)
	var l := c + Vector2(-rx, -h * 0.08)
	var r := c + Vector2(rx, -h * 0.08)
	draw_colored_polygon(
		PackedVector2Array([top, r, c + Vector2(0, -h * 0.02), l]), Color(col, 0.28)
	)
	_poly(PackedVector2Array([top, r, bot, l]), col, 1.2)
	_ln(l, c + Vector2(0, -h * 0.02), Color(col, 0.7))
	_ln(r, c + Vector2(0, -h * 0.02), Color(col, 0.7))
	_ln(c + Vector2(0, -h * 0.02), bot, Color(col, 0.5))


func _price_w(n: int, fs: int) -> float:
	return fs * 0.86 * 0.7 + 10.0 + _width(_serif(600, 1), str(n), fs)


## A price: the shard and the number, centred on `cx` (or starting at it when `align` is 0) on baseline `base`.
func _price(n: int, cx: float, base: float, fs: int, ok := true, align := 1) -> float:
	var s := str(n)
	var f := _serif(600, 1)
	var tw := _width(f, s, fs)
	var sh := fs * 0.86
	var w := sh * 0.7 + 10.0 + tw
	var x := cx - w * 0.5 * align
	_shard(Vector2(roundf(x + sh * 0.34), base - fs * 0.36), sh, p["accent"] if ok else p["poor"])
	_text(f, s, x + sh * 0.7 + 10.0, base, fs, p["text"] if ok else p["poor"])
	return w


## The section mark before a title, in the style's ornament.
func _mark(c: Vector2, sz: float, col: Color) -> void:
	match style:
		"slate":
			_rune(17, c, sz * 1.6, col, 1.3)
		"eclipse":
			_ln(c + Vector2(0, -sz), c + Vector2(0, sz), col, 1.4)
			_ln(c + Vector2(0, -sz * 0.2), c + Vector2(-sz * 0.55, -sz * 0.75), col, 1.2)
			_ln(c + Vector2(0, -sz * 0.2), c + Vector2(sz * 0.55, -sz * 0.75), col, 1.2)
			_arc(c + Vector2(0, sz * 0.2), sz * 0.55, PI * 0.15, PI * 0.85, Color(col, 0.6))
		"astral":
			_star4(c, sz, col, 0.16)
			_crescent(c + Vector2(0, -sz * 1.25), sz * 0.42, Color(col, 0.8))
		_:
			_compass(c, sz, col)
			draw_arc(c, sz * 0.62, 0, TAU, 32, Color(col, 0.45), 1.0, true)


## A heading: the mark, the title in letter-spaced caps, and a quieter subtitle after a separator.
func _heading(title: String, x: float, base: float, fs: int, sub := "", align := 0) -> float:
	var f := _serif(600, int(fs * 0.38))
	var tw := _width(f, title.to_upper(), fs)
	var sf := _serif(500, int(fs * 0.22))
	var sfs := int(fs * 0.46)
	var sw := _width(sf, sub.to_upper(), sfs) + 56.0 if sub != "" else 0.0
	var lead := roundf(fs * 1.25)
	var total := lead + tw + sw
	var x0 := x - total * 0.5 * align
	_mark(Vector2(x0 + fs * 0.4, base - fs * 0.36), fs * 0.42, p["metal"])
	_text(f, title.to_upper(), x0 + lead, base, fs, p["text"])
	if sub != "":
		var sx := x0 + lead + tw + 30
		_dia(Vector2(sx, base - fs * 0.36), 3.0, Color(p["metal"], 0.7), Color(p["metal"], 0.7))
		_text(sf, sub.to_upper(), sx + 26, base, sfs, p["dim"])
	return total


## The separator: a fading hairline with the style's centre jewel.
func _sep(cx: float, y: float, half: float, col: Color) -> void:
	_rule(cx, y, half, col, 10.0)
	match style:
		"slate":
			_h(cx - 3, cx + 3, y, col)
		"eclipse":
			_dia(Vector2(cx, y + 0.5), 4.0, col)
		"astral":
			_star4(Vector2(cx, y + 0.5), 6.0, col, 0.2)
		_:
			_dia(Vector2(cx, y + 0.5), 4.5, col)
			_dia(Vector2(cx, y + 0.5), 1.5, col, col)


## A key cap (the bound key's short name) centred on `c`.
func _key(s: String, c: Vector2) -> void:
	var f := _sans(true, 1)
	var fs := 13
	var w := maxf(22.0, _width(f, s, fs) + 12.0)
	var r := Rect2(Vector2(roundf(c.x - w * 0.5), roundf(c.y - 11)), Vector2(roundf(w), 22))
	draw_rect(r, Color(p["ink"], 0.8))
	_frame(r, Color(p["metal"], 0.7))
	if style == "eclipse" or style == "observatory":
		_frame(r.grow(-2), Color(p["metal"], 0.18))
	_text(f, s, c.x, r.position.y + 16, fs, p["text"], 1)


## A soft ink wash from alpha `a0` at y0 to `a1` at y1 (behind the HUD's top and bottom rows).
func _scrim(r: Rect2, a0: float, a1: float, horizontal := false) -> void:
	var c0 := Color(p["ink"], a0)
	var c1 := Color(p["ink"], a1)
	var cols := (
		PackedColorArray([c0, c1, c1, c0]) if horizontal else PackedColorArray([c0, c0, c1, c1])
	)
	draw_polygon(
		PackedVector2Array(
			[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		),
		cols
	)


# --- Panels -------------------------------------------------------------------------------------------------
## A framed panel: fill, frame, inner line, ornaments. `deco` adds the style's large ornaments.
func _panel(r: Rect2, deco := true) -> void:
	match style:
		"slate":
			glass.append([r, 0.0])
			draw_rect(r, p["fill"])
			_h(r.position.x + 1, r.end.x - 1, r.position.y + 1, Color(1, 1, 1, 0.05))
			_inset(r, 5, 0.3)
			_frame(r, p["line"])
		"eclipse":
			glass.append([r, 10.0])
			var pts := _carve(r, 18.0, int(r.position.x + r.size.y))
			_stone_fill(pts, p["fill"])
			_bevel(pts, 3.0, Color(1, 1, 1, 0.1), Color(0, 0, 0, 0.55))
			_poly(pts, p["line"])
			_poly(_contour(pts, -7.0), Color(p["line"], 0.28))
		"astral":  # no border: a light ink veil between two fading hairlines
			glass.append([r, 0.0])
			draw_rect(r, Color(p["ink"], 0.5))
			var top := r.position.y
			_rule(r.get_center().x, top, r.size.x * 0.5, Color(p["line"], 0.9), 0.0)
			_rule(r.get_center().x, r.end.y - 1, r.size.x * 0.5, Color(p["line"], 0.6), 0.0)
		_:
			glass.append([r, 12.0])
			var o := _px(r)
			var pts := _cut(o, 12.0)
			draw_colored_polygon(pts, p["fill"])
			_poly(pts, p["line"])
			var inner := _cut(o.grow(-5), 8.0)
			_poly(inner, Color(p["line"], 0.45))
			for k in 4:  # corner ornaments: a diamond on each cut, a short bracket inside
				var sx := 1.0 if k % 2 == 0 else -1.0
				var sy := 1.0 if k < 2 else -1.0
				var cn := Vector2(
					o.position.x if sx > 0 else o.end.x, o.position.y if sy > 0 else o.end.y
				)
				_dia(cn + Vector2(sx, sy) * 6.0, 3.5, p["metal"], p["ink"])
				_h(cn.x + sx * 14, cn.x + sx * 34, cn.y + sy * 9, Color(p["metal"], 0.55))
				_v(cn.x + sx * 9, cn.y + sy * 14, cn.y + sy * 34, Color(p["metal"], 0.55))
			if deco:
				_astrolabe(o.position + Vector2(0, 0), 0.0, 120.0)
				_astrolabe(o.end, PI, 120.0)


## The observatory's engraved instrument in a panel corner: arcs, a degree scale, a pointer.
func _astrolabe(c: Vector2, a0: float, r: float) -> void:
	var col := Color(p["metal"], 0.16)
	for rr in [r * 0.62, r * 0.8, r]:
		_arc(c, rr, a0, a0 + PI * 0.5, col)
	for k in 19:
		var a := a0 + PI * 0.5 * k / 18.0
		var u := Vector2(cos(a), sin(a))
		_ln(c + u * r * (0.93 if k % 3 else 0.86), c + u * r, col)
	var a1 := a0 + PI * 0.3
	_ln(c, c + Vector2(cos(a1), sin(a1)) * r * 1.08, Color(p["metal"], 0.22))
	draw_circle(c + Vector2(cos(a1), sin(a1)) * r * 0.8, 2.5, Color(p["metal"], 0.3))


# --- Cards --------------------------------------------------------------------------------------------------
## A card's frame (no content) in `r`; the caller has already lifted a focused card.
func _card_frame(r: Rect2, focused: bool) -> void:
	var line: Color = p["line_hi"] if focused else p["line"]
	match style:
		"slate":
			draw_rect(r, p["fill_hi"] if focused else p["fill"])
			_h(r.position.x + 1, r.end.x - 1, r.position.y + 1, Color(1, 1, 1, 0.06))
			_inset(r, 6, 0.28 if focused else 0.4)
			_frame(r, Color(line, 0.85) if focused else line)
			if focused:
				draw_rect(Rect2(r.position, Vector2(3, r.size.y)), p["accent"])
		"eclipse":
			var pts := _carve(r, 22.0, int(r.position.x * 3.0))
			_stone_fill(pts, p["fill_hi"] if focused else p["fill"])
			_bevel(pts, 3.0, Color(1, 1, 1, 0.14 if focused else 0.08), Color(0, 0, 0, 0.6))
			_poly(_contour(pts, -9.0), Color(line, 0.22))
			if focused:
				_poly(pts, p["line_hi"], 2.0)
				_poly(_contour(pts, 5.0), Color(p["line_hi"], 0.3))
				_star4(r.position + Vector2(10, 6), 9.0, p["line_hi"], 0.14)
				_star4(r.end - Vector2(10, 6), 7.0, Color(p["line_hi"], 0.8), 0.14)
			else:
				_poly(pts, p["line"])
		"astral":
			var pts := _arch(r, 34.0)
			draw_colored_polygon(pts, p["fill_hi"] if focused else p["fill"])
			_poly(_contour(pts, -6.0), Color(line, 0.35 if focused else 0.22))
			_poly(pts, line, 1.4 if focused else 1.0)
			var fin := Vector2(r.get_center().x, r.position.y - 20)
			_crescent(fin, 8.0, Color(line, 1.0 if focused else 0.6), PI * 0.5)
			if focused:
				_poly(_contour(pts, 6.0), Color(p["line_hi"], 0.25))
				_star4(Vector2(r.position.x - 4, r.position.y + 26), 8.0, p["line_hi"], 0.14)
				_star4(Vector2(r.end.x + 4, r.end.y - 30), 6.0, Color(p["line_hi"], 0.7), 0.14)
				_ln(fin + Vector2(0, 9), fin + Vector2(0, 30), Color(p["line_hi"], 0.0))
		_:
			var o := _px(r)
			var pts := _cut(o, 10.0)
			draw_colored_polygon(pts, p["fill_hi"] if focused else p["fill"])
			_poly(pts, line)
			_poly(_cut(o.grow(-5), 6.0), Color(line, 0.5 if focused else 0.3))
			for k in 4:
				var sx := 1.0 if k % 2 == 0 else -1.0
				var sy := 1.0 if k < 2 else -1.0
				var cn := Vector2(
					o.position.x if sx > 0 else o.end.x, o.position.y if sy > 0 else o.end.y
				)
				_ln(cn + Vector2(sx * 5, sy * 18), cn + Vector2(sx * 5, sy * 10), Color(line, 0.7))
				_ln(cn + Vector2(sx * 10, sy * 5), cn + Vector2(sx * 18, sy * 5), Color(line, 0.7))
			if focused:
				var g := Vector2(o.get_center().x, o.position.y)
				_h(g.x - 44, g.x - 14, g.y - 4, Color(p["line_hi"], 0.7))
				_h(g.x + 14, g.x + 44, g.y - 4, Color(p["line_hi"], 0.7))
				_dia(g, 10.0, p["line_hi"], p["ink"])
				_dia(g, 5.0, Color(0, 0, 0, 0), p["accent"])
				_dia(Vector2(g.x, o.end.y), 6.0, p["line_hi"], p["ink"])


## The icon medallion on a card.
func _card_medal(c: Vector2, r: float, focused: bool) -> void:
	var line: Color = p["line_hi"] if focused else p["line"]
	match style:
		"slate":
			_h(c.x - 18, c.x + 18, c.y + r + 12, Color(p["accent"] if focused else p["faint"], 0.9))
		"eclipse":
			draw_circle(c, r, Color(p["ink"], 0.6))
			_arc(c, r, PI * 0.75, PI * 1.75, Color(0, 0, 0, 0.7), 2.0)
			_arc(c, r - 1.5, -PI * 0.25, PI * 0.75, Color(1, 1, 1, 0.12))
			_arc(c, r + 7, 0, TAU, Color(line, 0.35))
			_arc(c, r + 7, -PI * 0.62, 0.05, Color(p["line_hi"], 0.95 if focused else 0.5), 1.6)
		"astral":
			draw_circle(c, r, Color(p["ink"], 0.45))
			_arc(c, r, 0, TAU, line, 1.0)
			for k in 36:
				var a := TAU * k / 36.0
				var q := c + Vector2(cos(a), sin(a)) * (r - 7)
				draw_rect(Rect2(q.round(), Vector2.ONE), Color(line, 0.55))
			if focused:
				for k in 4:
					var a := PI * 0.25 + PI * 0.5 * k
					_star4(c + Vector2(cos(a), sin(a)) * (r + 12), 4.0, Color(p["line_hi"], 0.8))
		_:
			draw_circle(c, r, Color(p["ink"], 0.55))
			_compass(c, r * 0.95, Color(p["metal"], 0.1))
			_arc(c, r, 0, TAU, line)
			_arc(c, r - 5, 0, TAU, Color(line, 0.4))
			_ticks(c, r + 2, r + 5, 48, Color(p["metal"], 0.35))
			_ticks(c, r + 2, r + 11, 4, Color(p["metal"], 0.8))


## A card: frame, title, icon medallion, the gain line, the sentence, the rarity line and (when `price` >= 0) the
## price at the bottom. Focus lifts it 10 px and lights it.
func _card(r: Rect2, face: Dictionary, focused: bool, price := -1, ok := true) -> void:
	var s := r.size.x / 300.0
	if focused:
		r = Rect2(r.position - Vector2(0, roundf(10 * s)), r.size)
	_card_frame(r, focused)
	var cx := r.get_center().x
	var y0 := r.position.y
	var dim_k := 1.0 if focused else 0.82
	# Title
	var title := String(face.get("title", ""))
	var tf := _serif(600, 3)
	var tfs := _fit(tf, title.to_upper(), int(19 * s), r.size.x - 40 * s, 12)
	_text(
		tf,
		title.to_upper(),
		cx,
		y0 + (52 if style == "astral" else 44) * s,
		tfs,
		Color(p["text"], dim_k),
		1
	)
	var lv := String(face.get("level_text", ""))
	if lv != "":
		_body(lv, cx, y0 + (74 if style == "astral" else 66) * s, int(13 * s), p["dim"], 1, true)
	# Medallion and icon
	var mc := Vector2(cx, roundf(y0 + 140 * s))
	var mr := roundf(58 * s)
	_card_medal(mc, mr, focused)
	var col: Color = face.get("color", p["accent"])
	var icol: Color = p["metal"].lerp(col, 0.32)
	if focused:
		icol = icol.lightened(0.25)
	var ir := mr * 0.72
	ItemIcons.draw(
		self, face.get("id", &""), Rect2(mc - Vector2.ONE * ir, Vector2.ONE * ir * 2), icol
	)
	var glyph := ElementGlyphs.glyph_of(face.get("id", &""))
	if glyph != &"":
		var gc := mc + Vector2(mr * 0.78, mr * 0.7)
		_dia(gc, 13 * s, Color(p["metal"], 0.7), p["ink"])
		ElementGlyphs.draw(self, glyph, Rect2(gc - Vector2.ONE * 9 * s, Vector2.ONE * 18 * s))
	# Gain line and sentence
	var y := mc.y + mr + 36 * s
	var gain: Dictionary = face.get("gain", {})
	if CardGain.shows(gain):
		var gt := CardGain.final_text(self, gain)
		var gfs := _fit(_sans(true, 0), gt, int(14 * s), r.size.x - 32 * s)
		_body(gt, cx, y, gfs, p["accent"], 1, true)
		y += 8 * s
	var bottom := r.end.y - (92 if price >= 0 else 50) * s
	_wrap(
		String(face.get("sentence", "")),
		Rect2(r.position.x + 22 * s, y, r.size.x - 44 * s, bottom - y),
		int(16 * s),
		Color(p["text"], 0.92 * dim_k),
		4
	)
	# Rarity line
	var ry := r.end.y - (70 if price >= 0 else 30) * s
	var tier := String(face.get("tier_text", "")).to_upper()
	var rf := _sans(true, 2)
	var rfs := _fit(rf, tier, int(12 * s), r.size.x - 56 * s, 9)
	var rw := _width(rf, tier, rfs)
	var rcol: Color = RARITY[clampi(int(face.get("tier", 0)), 0, 4)]
	_dia(Vector2(cx - rw * 0.5 - 10, ry - rfs * 0.36), 3.5, rcol, rcol)
	_text(rf, tier, cx + 6, ry, rfs, p["dim"], 1)
	if price >= 0:
		_sep(
			cx,
			r.end.y - 52 * s,
			r.size.x * 0.36,
			Color(p["line"] if not focused else p["metal"], 0.8)
		)
		_price(price, cx, r.end.y - 18 * s, int(24 * s), ok)
