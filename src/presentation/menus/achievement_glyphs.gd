class_name AchievementGlyphs
extends RefCounted
## v0.7.5 AC: the achievements' pictures, drawn in code (AchievementDefinition.GLYPHS): a few strokes and flat shapes
## on a unit square, scaled into the rect given, in one colour. Draws only.

const STROKE := 0.075


## Draws glyph `g` on `ci` inside `r` in `c`; returns the number of shapes drawn (0: an unknown glyph, which draws a
## plain diamond).
static func draw(ci: CanvasItem, g: StringName, r: Rect2, c: Color) -> int:
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	var w := maxf(1.5, s * STROKE)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match g:
		&"floor":  # stairs going down
			_line(
				ci,
				[p.call(0.15, 0.25), p.call(0.4, 0.25), p.call(0.4, 0.5), p.call(0.65, 0.5)],
				c,
				w
			)
			_line(ci, [p.call(0.65, 0.5), p.call(0.65, 0.75), p.call(0.88, 0.75)], c, w)
			return 2
		&"crown":
			_poly(
				ci,
				[
					p.call(0.15, 0.72),
					p.call(0.15, 0.32),
					p.call(0.33, 0.5),
					p.call(0.5, 0.22),
					p.call(0.67, 0.5),
					p.call(0.85, 0.32),
					p.call(0.85, 0.72)
				],
				c
			)
			return 1
		&"skull":
			ci.draw_circle(p.call(0.5, 0.42), s * 0.28, c)
			ci.draw_rect(Rect2(p.call(0.34, 0.55), Vector2(0.32, 0.22) * s), c)
			var dark := Color(0, 0, 0, 0.75)
			ci.draw_circle(p.call(0.4, 0.43), s * 0.07, dark)
			ci.draw_circle(p.call(0.6, 0.43), s * 0.07, dark)
			return 3
		&"compass":
			ci.draw_arc(p.call(0.5, 0.5), s * 0.36, 0.0, TAU, 32, c, w, true)
			_poly(ci, [p.call(0.5, 0.2), p.call(0.58, 0.5), p.call(0.5, 0.8), p.call(0.42, 0.5)], c)
			return 2
		&"globe":
			ci.draw_arc(p.call(0.5, 0.5), s * 0.36, 0.0, TAU, 32, c, w, true)
			_line(ci, [p.call(0.14, 0.5), p.call(0.86, 0.5)], c, w)
			ci.draw_arc(p.call(0.5, 0.5), s * 0.36, -PI * 0.5, PI * 0.5, 16, c, w * 0.8, true)
			return 3
		&"wand":
			_line(ci, [p.call(0.2, 0.82), p.call(0.62, 0.4)], c, w * 1.4)
			_star(ci, p.call(0.7, 0.3), s * 0.17, c)
			return 2
		&"star":
			_star(ci, p.call(0.5, 0.52), s * 0.38, c)
			return 1
		&"chain":
			ci.draw_arc(p.call(0.36, 0.5), s * 0.17, 0.0, TAU, 20, c, w, true)
			ci.draw_arc(p.call(0.64, 0.5), s * 0.17, 0.0, TAU, 20, c, w, true)
			return 2
		&"blade":
			_poly(
				ci,
				[p.call(0.78, 0.14), p.call(0.86, 0.22), p.call(0.4, 0.68), p.call(0.32, 0.6)],
				c
			)
			_line(ci, [p.call(0.22, 0.52), p.call(0.48, 0.78)], c, w)
			_line(ci, [p.call(0.34, 0.66), p.call(0.16, 0.84)], c, w * 1.2)
			return 3
		&"shield":
			_poly(
				ci,
				[
					p.call(0.5, 0.14),
					p.call(0.82, 0.26),
					p.call(0.76, 0.6),
					p.call(0.5, 0.86),
					p.call(0.24, 0.6),
					p.call(0.18, 0.26)
				],
				c
			)
			return 1
		&"gate":
			_line(ci, [p.call(0.2, 0.85), p.call(0.2, 0.35), p.call(0.5, 0.15)], c, w)
			_line(ci, [p.call(0.5, 0.15), p.call(0.8, 0.35), p.call(0.8, 0.85)], c, w)
			_line(
				ci,
				[p.call(0.38, 0.85), p.call(0.38, 0.5), p.call(0.62, 0.5), p.call(0.62, 0.85)],
				c,
				w
			)
			return 3
		&"wave":
			for k in 3:
				var y := 0.3 + k * 0.2
				_line(
					ci,
					[
						p.call(0.15, y),
						p.call(0.32, y - 0.08),
						p.call(0.5, y),
						p.call(0.68, y - 0.08)
					],
					c,
					w
				)
			return 3
		&"curse":
			ci.draw_arc(p.call(0.5, 0.46), s * 0.26, PI * 0.15, PI * 1.85, 24, c, w, true)
			ci.draw_circle(p.call(0.5, 0.46), s * 0.08, c)
			_line(ci, [p.call(0.5, 0.72), p.call(0.5, 0.88)], c, w)
			return 3
		&"core":
			_poly(ci, [p.call(0.5, 0.14), p.call(0.8, 0.5), p.call(0.5, 0.86), p.call(0.2, 0.5)], c)
			ci.draw_circle(p.call(0.5, 0.5), s * 0.1, Color(1, 1, 1, 0.7))
			return 2
		&"shard":
			_poly(
				ci,
				[p.call(0.42, 0.12), p.call(0.66, 0.4), p.call(0.56, 0.88), p.call(0.32, 0.52)],
				c
			)
			return 1
		&"book":
			_poly(
				ci,
				[p.call(0.14, 0.26), p.call(0.48, 0.32), p.call(0.48, 0.82), p.call(0.14, 0.76)],
				c
			)
			_poly(
				ci,
				[p.call(0.52, 0.32), p.call(0.86, 0.26), p.call(0.86, 0.76), p.call(0.52, 0.82)],
				c
			)
			return 2
		&"eye":
			ci.draw_arc(p.call(0.5, 0.78), s * 0.42, -PI * 0.82, -PI * 0.18, 20, c, w, true)
			ci.draw_arc(p.call(0.5, 0.22), s * 0.42, PI * 0.18, PI * 0.82, 20, c, w, true)
			ci.draw_circle(p.call(0.5, 0.5), s * 0.12, c)
			return 3
		&"ascend":
			_poly(ci, [p.call(0.5, 0.12), p.call(0.8, 0.44), p.call(0.2, 0.44)], c)
			_poly(
				ci, [p.call(0.5, 0.42), p.call(0.8, 0.74), p.call(0.2, 0.74)], Color(c, c.a * 0.6)
			)
			return 2
	_poly(ci, [p.call(0.5, 0.2), p.call(0.8, 0.5), p.call(0.5, 0.8), p.call(0.2, 0.5)], c)
	return 0


static func _line(ci: CanvasItem, pts: Array, c: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array(pts), c, w, true)


static func _poly(ci: CanvasItem, pts: Array, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), c)


static func _star(ci: CanvasItem, at: Vector2, radius: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rr := radius if k % 2 == 0 else radius * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, c)
