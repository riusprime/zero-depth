class_name CodexGlyphs
extends RefCounted
## v0.7.5 CX: the Codex's emblems for enemies and bosses, in the item icons' style (ItemIcons: shapes in a unit box,
## y down, drawn with CanvasItem calls, no external art), and a biome's small landscape in its own palette. An enemy
## is drawn by its behaviour, a boss by its id; one this table doesn't know gets the generic emblem, so new content
## shows without code. Presentation only (EI-07).

const DARK := Color(0.05, 0.06, 0.09)
## The emblems' colours: hostile red for enemies, a hotter red-gold for bosses.
const ENEMY := Color("#FF6A5A")
const BOSS := Color("#FFB347")


static func color(page: StringName) -> Color:
	return BOSS if page == &"bosses" else ENEMY


## The shapes of an enemy (by behaviour id) or a boss (by id).
static func shapes(page: StringName, key: StringName) -> Array:
	return _boss(key) if page == &"bosses" else _enemy(key)


static func _enemy(behaviour: StringName) -> Array:
	match behaviour:
		&"charger", &"hatchling":
			var s := 1.0 if behaviour == &"charger" else 0.7
			return [
				_poly(_scaled([[0.14, 0.2], [0.62, 0.5], [0.14, 0.8], [0.32, 0.5]], s)),
				_poly(_scaled([[0.46, 0.2], [0.9, 0.5], [0.46, 0.8], [0.62, 0.5]], s)),
			]
		&"warden":
			return [
				_poly([[0.2, 0.14], [0.8, 0.14], [0.86, 0.62], [0.5, 0.9], [0.14, 0.62]]),
				_line([[0.5, 0.24], [0.5, 0.78]], 0.07, true),
				_line([[0.26, 0.42], [0.74, 0.42]], 0.07, true),
			]
		&"needle", &"lens_drone":
			if behaviour == &"lens_drone":
				return [
					_ellipse(Vector2(0.5, 0.5), Vector2(0.4, 0.24)),
					_circle(Vector2(0.5, 0.5), 0.12, 0.0, true),
				]
			return [
				_circle(Vector2(0.4, 0.58), 0.26, 0.0),
				_line([[0.5, 0.5], [0.9, 0.22]], 0.11),
				_circle(Vector2(0.4, 0.58), 0.08, 0.0, true),
			]
		&"arc_caster":
			return [
				_poly(
					[
						[0.56, 0.06],
						[0.24, 0.54],
						[0.46, 0.54],
						[0.38, 0.94],
						[0.78, 0.4],
						[0.54, 0.4]
					]
				),
			]
		&"bomb_drone":
			return [
				_circle(Vector2(0.46, 0.58), 0.3, 0.0),
				_line([[0.66, 0.36], [0.8, 0.18]], 0.06),
				_circle(Vector2(0.84, 0.14), 0.07, 0.0),
			]
		&"swarmer":
			var out := []
			for p: Array in [[0.3, 0.3], [0.7, 0.3], [0.5, 0.5], [0.3, 0.72], [0.7, 0.72]]:
				out.append(_circle(Vector2(p[0], p[1]), 0.13, 0.0))
			return out
		&"splitter":
			return [
				_circle(Vector2(0.5, 0.5), 0.38, 0.0),
				_line([[0.42, 0.14], [0.56, 0.4], [0.44, 0.6], [0.58, 0.86]], 0.07, true),
			]
		&"splitling":
			return [_poly([[0.2, 0.56], [0.3, 0.32], [0.5, 0.22], [0.7, 0.32], [0.8, 0.56]])]
		&"shield_bearer":
			return [
				_poly([[0.22, 0.12], [0.78, 0.12], [0.78, 0.5], [0.5, 0.9], [0.22, 0.5]]),
				_poly([[0.34, 0.24], [0.66, 0.24], [0.66, 0.48], [0.5, 0.72], [0.34, 0.48]], true),
			]
		&"mender":
			return [
				_poly([[0.38, 0.12], [0.62, 0.12], [0.62, 0.88], [0.38, 0.88]]),
				_poly([[0.12, 0.38], [0.88, 0.38], [0.88, 0.62], [0.12, 0.62]]),
			]
		&"mine_layer":
			return [
				_circle(Vector2(0.5, 0.5), 0.24, 0.0),
				_line([[0.5, 0.08], [0.5, 0.92]], 0.07),
				_line([[0.08, 0.5], [0.92, 0.5]], 0.07),
				_circle(Vector2(0.5, 0.5), 0.08, 0.0, true),
			]
		&"sniper":
			return [
				_circle(Vector2(0.5, 0.5), 0.32, 0.07),
				_line([[0.5, 0.06], [0.5, 0.34]], 0.06),
				_line([[0.5, 0.66], [0.5, 0.94]], 0.06),
				_line([[0.06, 0.5], [0.34, 0.5]], 0.06),
				_line([[0.66, 0.5], [0.94, 0.5]], 0.06),
			]
	return [  # any other enemy: a hostile diamond with an eye
		_poly([[0.5, 0.08], [0.9, 0.5], [0.5, 0.92], [0.1, 0.5]]),
		_circle(Vector2(0.5, 0.5), 0.12, 0.0, true),
	]


static func _boss(id: StringName) -> Array:
	match id:
		&"gatekeeper":
			return [
				_poly([[0.12, 0.92], [0.12, 0.3], [0.5, 0.08], [0.88, 0.3], [0.88, 0.92]]),
				_poly([[0.32, 0.92], [0.32, 0.46], [0.5, 0.34], [0.68, 0.46], [0.68, 0.92]], true),
			]
		&"brood_mother":
			return [
				_circle(Vector2(0.5, 0.42), 0.3, 0.0),
				_circle(Vector2(0.22, 0.8), 0.11, 0.0),
				_circle(Vector2(0.5, 0.86), 0.11, 0.0),
				_circle(Vector2(0.78, 0.8), 0.11, 0.0),
			]
		&"siege_engine":
			return [
				_poly([[0.1, 0.5], [0.62, 0.5], [0.62, 0.86], [0.1, 0.86]]),
				_line([[0.4, 0.56], [0.92, 0.2]], 0.16),
				_circle(Vector2(0.24, 0.86), 0.09, 0.0, true),
				_circle(Vector2(0.5, 0.86), 0.09, 0.0, true),
			]
		&"warlord":
			return [
				_line([[0.12, 0.88], [0.86, 0.14]], 0.07),
				_line([[0.88, 0.88], [0.14, 0.14]], 0.07),
				_poly([[0.3, 0.3], [0.7, 0.3], [0.7, 0.6], [0.5, 0.82], [0.3, 0.6]]),
			]
		&"hive_lens":
			var out := []
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a))
				out.append(
					_line([Vector2(0.5, 0.5) + d * 0.36, Vector2(0.5, 0.5) + d * 0.46], 0.05)
				)
			out.append(_circle(Vector2(0.5, 0.5), 0.3, 0.0))
			out.append(_circle(Vector2(0.5, 0.5), 0.12, 0.0, true))
			return out
		&"foundry":
			return [
				_poly([[0.12, 0.62], [0.88, 0.62], [0.76, 0.92], [0.24, 0.92]]),
				_poly([[0.5, 0.08], [0.7, 0.36], [0.62, 0.56], [0.38, 0.56], [0.3, 0.36]]),
				_poly([[0.5, 0.3], [0.58, 0.44], [0.5, 0.54], [0.42, 0.44]], true),
			]
	return [  # any other boss: a crown
		_poly(
			[
				[0.12, 0.8],
				[0.12, 0.3],
				[0.32, 0.5],
				[0.5, 0.2],
				[0.68, 0.5],
				[0.88, 0.3],
				[0.88, 0.8]
			]
		),
		_line([[0.12, 0.8], [0.88, 0.8]], 0.06, true),
	]


## Draws `shapes` (unit box, y down) into `rect` of `ci` in `color`; returns the number drawn.
static func draw(ci: CanvasItem, shapes_list: Array, rect: Rect2, c: Color) -> int:
	var side := minf(rect.size.x, rect.size.y)
	var origin := rect.position + (rect.size - Vector2(side, side)) * 0.5
	var n := 0
	for s: Dictionary in shapes_list:
		var col := DARK if s.get("dark", false) else c
		match s["t"]:
			"line":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(origin + p * side)
				ci.draw_polyline(pts, col, maxf(1.0, float(s["w"]) * side), true)
			"poly":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(origin + p * side)
				ci.draw_colored_polygon(pts, col)
			"circle":
				var w: float = s["w"]
				ci.draw_circle(
					origin + s["c"] * side,
					s["r"] * side,
					col,
					w <= 0.0,
					-1.0 if w <= 0.0 else maxf(1.0, w * side),
					true
				)
		n += 1
	return n


## A biome's small landscape in its palette (BiomeDefinition.PALETTE_KEYS order: ground, ground_alt, cover, accent,
## edge, ambient, outline): its light above, its ground in two tones, cover stones and accent marks, outlined.
static func draw_biome(ci: CanvasItem, palette: Array[Color], rect: Rect2, locked: bool) -> void:
	var p := palette.duplicate()
	while p.size() < 7:
		p.append(Color.GRAY)
	if locked:
		for k in p.size():
			p[k] = Color(0.12, 0.14, 0.18).lerp(Color(0.2, 0.22, 0.27), p[k].get_luminance())
	var r := rect
	var horizon := r.position.y + r.size.y * 0.46
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, horizon - r.position.y)), p[5].darkened(0.55))
	ci.draw_circle(r.position + r.size * Vector2(0.76, 0.24), r.size.y * 0.09, p[3].lightened(0.2))
	ci.draw_rect(Rect2(r.position.x, horizon, r.size.x, r.end.y - horizon), p[0])
	for k in 3:
		var y := horizon + (r.end.y - horizon) * (0.22 + 0.26 * k)
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, (r.end.y - horizon) * 0.1), p[1])
	for k in 3:
		var cx := r.position.x + r.size.x * (0.18 + 0.3 * k)
		var base := horizon + r.size.y * (0.08 + 0.06 * (k % 2))
		var h := r.size.y * (0.26 - 0.05 * k)
		var stone := PackedVector2Array(
			[
				Vector2(cx - r.size.x * 0.1, base),
				Vector2(cx - r.size.x * 0.06, base - h),
				Vector2(cx + r.size.x * 0.05, base - h * 0.86),
				Vector2(cx + r.size.x * 0.1, base),
			]
		)
		ci.draw_colored_polygon(stone, p[2])
		ci.draw_polyline(stone, p[4], 2.0, true)
	ci.draw_rect(r, p[6], false, 3.0)


static func _pts(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Variant in pts:
		out.append(q if q is Vector2 else Vector2(q[0], q[1]))
	return out


static func _scaled(pts: Array, s: float) -> Array:
	var out := []
	for q: Array in pts:
		out.append([0.5 + (q[0] - 0.5) * s, 0.5 + (q[1] - 0.5) * s])
	return out


static func _line(pts: Array, w: float, dark := false) -> Dictionary:
	return {"t": "line", "pts": _pts(pts), "w": w, "dark": dark}


static func _poly(pts: Array, dark := false) -> Dictionary:
	return {"t": "poly", "pts": _pts(pts), "dark": dark}


static func _circle(c: Vector2, r: float, w: float, dark := false) -> Dictionary:
	return {"t": "circle", "c": c, "r": r, "w": w, "dark": dark}


static func _ellipse(c: Vector2, radii: Vector2) -> Dictionary:
	var pts := []
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return _poly(pts)
