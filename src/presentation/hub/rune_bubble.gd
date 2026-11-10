class_name RuneBubble
extends Control
## RUNIC_STONE.md S2, S4: the speech bubble over the Runic Stone, a Control drawn in code. Locked, it is a
## faint "..." (three dots); awake, it shows one line in Elder Futhark glyphs (RunicGlyphs, line strokes, no font) in a
## violet glow, each glyph fading in FADE_GAP_S after the one before it. It never shows the English. `anchor_px` is
## the bubble's tail, where the stone's top is on the screen (HubRunic moves it every frame). Reads and draws only.

enum Mode { CLOSED, DOTS, LINE }

const VIOLET := Color("#9B6BFF")
const FADE_GAP_S := 0.05
const FADE_S := 0.12
const GLYPH_W := 14.0
const GLYPH_H := 28.0
const GLYPH_GAP := 8.0
const ROW_GAP := 14.0
const PAD := 16.0

var mode := Mode.CLOSED
var rows: Array = []
## Where the tail points, in this Control's own pixels.
var anchor_px := Vector2(640, 360)
var _t := 0.0


func _init() -> void:
	name = "RuneBubble"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_open() -> bool:
	return mode != Mode.CLOSED


## The faint "..." of a locked stone.
func show_dots() -> void:
	mode = Mode.DOTS
	rows = []
	_t = 0.0
	visible = true
	queue_redraw()


## One line (glyph ids from RuneCipher.encode), wrapped at ~14 glyphs, fading in glyph by glyph.
func show_line(glyphs: Array[int]) -> void:
	mode = Mode.LINE
	rows = RuneCipher.wrap(glyphs, 14)
	_t = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	mode = Mode.CLOSED
	rows = []
	visible = false


## The glyphs on show now: the line's glyphs the fade has begun on (RuneCipher.GAP not counted).
func glyph_count() -> int:
	var n := 0
	for r: Array in rows:
		for g: int in r:
			if g != RuneCipher.GAP:
				n += 1
	return n


func shown_count() -> int:
	return mini(glyph_count(), int(_t / FADE_GAP_S) + 1) if mode == Mode.LINE else 0


func _process(delta: float) -> void:
	if mode == Mode.CLOSED:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	match mode:
		Mode.DOTS:
			_draw_dots()
		Mode.LINE:
			_draw_line()


## An Astral panel: an ink fill, a 1 px frame in
## Astral's line with an inner frame 4 px in, a small diamond on its top edge, the tail outlined in the same line.
func _panel(box: Rect2) -> void:
	var o := Rect2(box.position.round(), box.size.round())
	var fill := Color(AstralChrome.INK, 0.82)
	var line := Color(AstralCardArt.LINE, 0.95)
	draw_rect(o, fill)
	var tip := Vector2(roundf(clampf(anchor_px.x, o.position.x + 14, o.end.x - 14)), o.end.y)
	var tail := PackedVector2Array([tip + Vector2(-8, -1), tip + Vector2(8, -1), anchor_px])
	draw_colored_polygon(tail, fill)
	draw_rect(o.grow(-0.5), line, false, 1.0)
	draw_rect(o.grow(-4.5), Color(line, 0.28), false, 1.0)
	draw_rect(Rect2(tip.x - 7, o.end.y - 1, 15, 1), fill)
	draw_polyline(
		PackedVector2Array([tip + Vector2(-8, -0.5), anchor_px, tip + Vector2(8, -0.5)]),
		line,
		1.0,
		true
	)
	AstralChrome.dia(
		self,
		Vector2(roundf(o.get_center().x) + 0.5, o.position.y + 0.5),
		3.5,
		AstralCardArt.METAL,
		AstralChrome.INK
	)


func _draw_dots() -> void:
	var box := Rect2(anchor_px + Vector2(-34, -62), Vector2(68, 30))
	draw_rect(box, Color(AstralChrome.INK, 0.6))  # Astral's ink, three faint diamonds
	draw_rect(box.grow(-0.5), Color(AstralCardArt.LINE, 0.5), false, 1.0)
	for i in 3:
		AstralChrome.dia(
			self,
			box.position + Vector2(17.5 + i * 17, 15.5),
			3.0,
			Color(0, 0, 0, 0),
			Color(AstralCardArt.METAL, 0.5)
		)


func _draw_line() -> void:
	var widest := 0
	for r: Array in rows:
		widest = maxi(widest, r.size())
	var size := Vector2(
		widest * (GLYPH_W + GLYPH_GAP) - GLYPH_GAP + PAD * 2.0,
		rows.size() * (GLYPH_H + ROW_GAP) - ROW_GAP + PAD * 2.0
	)
	var box := Rect2(anchor_px + Vector2(-size.x * 0.5, -size.y - 24.0), size)
	box.position.y = maxf(box.position.y, 8.0)  # a tall line stays on the screen
	_panel(box)
	var order := 0
	for ri in rows.size():
		var row: Array = rows[ri]
		var x0 := box.position.x + (size.x - (row.size() * (GLYPH_W + GLYPH_GAP) - GLYPH_GAP)) * 0.5
		var y0 := box.position.y + PAD + ri * (GLYPH_H + ROW_GAP)
		for ci in row.size():
			var g: int = row[ci]
			if g == RuneCipher.GAP:
				continue
			var a := clampf((_t - order * FADE_GAP_S) / FADE_S, 0.0, 1.0)
			order += 1
			if a > 0.0:
				_glyph(g, Vector2(x0 + ci * (GLYPH_W + GLYPH_GAP), y0), a)


func _glyph(g: int, at: Vector2, a: float) -> void:
	var sx := GLYPH_W / RunicGlyphs.W
	var sy := GLYPH_H / RunicGlyphs.H
	for s: PackedVector2Array in RunicGlyphs.strokes(g):
		var pts := PackedVector2Array()
		for p in s:
			pts.append(at + Vector2(p.x * sx, p.y * sy))
		draw_polyline(pts, Color(VIOLET.lerp(AstralCardArt.ACCENT, 0.55), a), 1.6, true)  # No glow
