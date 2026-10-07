class_name ItemIcons
extends RefCounted
## One simple vector symbol per item (PLAN v0.2.0 L13: "maybe we can add to the card a symbol"), drawn with
## CanvasItem calls, no external art. Each icon is a list of shapes in a unit box (0..1, y down), scaled to the
## rect it's drawn in. Keyed by item id, so a new item only needs a row here; an unknown id gets a generic gem.
##
## A shape is a Dictionary: {"t": "line", "pts": PackedVector2Array, "w": width} (an open polyline),
## {"t": "loop", ...} (a closed polyline), {"t": "poly", "pts": ...} (filled) or {"t": "circle", "c": Vector2,
## "r": radius, "w": width (0 = filled)}. "dark": true draws it in DARK instead of the item colour.

const DARK := Color(0.05, 0.06, 0.09)
const IDS: Array[StringName] = [
	&"long_edge",
	&"twin_arc",
	&"ember_edge",
	&"splinter_shot",
	&"rapid_coil",
	&"ricochet_core",
	&"kinetic_dash",
	&"overcharge",
	&"vampiric_core",
	&"static_chain",
	&"momentum",
	&"frost_core",
	&"thorn_mantle",
	&"executioner",
	&"swift_feet",
	&"phase_strike",
	&"cinder_shot",
	&"wildfire",
	&"conductor",
	&"serrated_edge",
	&"barbed_bolts",
	&"glacial_edge",
	&"cold_snap",
	&"bulwark",
	&"heat_sink",
	&"thermal_edge",
	&"meltdown",
	&"cluster_payload",
	&"overclocked_drone",
	&"razor_orbit",
	&"afterimage",
]


static func has_icon(id: StringName) -> bool:
	return id in IDS


## The shapes of `id`'s icon (the gem for an unknown id).
static func shapes(id: StringName) -> Array:
	if not id in IDS and AbilityIcons.has_icon(id):
		return AbilityIcons.shapes(id)  # v0.4.0 BS: abilities and stat cards
	match id:
		&"long_edge":
			return [
				_poly([Vector2(0.24, 0.68), Vector2(0.32, 0.76), Vector2(0.88, 0.12)]),
				_line([Vector2(0.16, 0.58), Vector2(0.42, 0.84)], 0.07),
				_line([Vector2(0.28, 0.72), Vector2(0.12, 0.88)], 0.08),
			]
		&"twin_arc":
			return [
				_arc(Vector2(0.5, 0.72), 0.4, -160.0, -20.0, 0.08),
				_arc(Vector2(0.5, 0.72), 0.24, -160.0, -20.0, 0.08),
			]
		&"ember_edge":
			var outer := [
				Vector2(0.5, 0.06),
				Vector2(0.7, 0.34),
				Vector2(0.78, 0.6),
				Vector2(0.68, 0.82),
				Vector2(0.5, 0.92),
				Vector2(0.32, 0.82),
				Vector2(0.22, 0.6),
				Vector2(0.3, 0.38),
				Vector2(0.4, 0.5),
				Vector2(0.42, 0.28),
			]
			var inner := [
				Vector2(0.52, 0.48),
				Vector2(0.62, 0.66),
				Vector2(0.58, 0.8),
				Vector2(0.5, 0.84),
				Vector2(0.42, 0.8),
				Vector2(0.4, 0.66),
			]
			return [_poly(outer), _poly(inner, true)]
		&"splinter_shot":
			var o := Vector2(0.16, 0.84)
			return (
				_dart(o, Vector2(0.86, 0.14))
				+ _dart(o, Vector2(0.92, 0.56))
				+ _dart(o, Vector2(0.44, 0.08))
			)
		&"rapid_coil":
			return [
				_line([Vector2(0.18, 0.22), Vector2(0.44, 0.5), Vector2(0.18, 0.78)], 0.11),
				_line([Vector2(0.52, 0.22), Vector2(0.78, 0.5), Vector2(0.52, 0.78)], 0.11),
			]
		&"ricochet_core":
			return [
				_line([Vector2(0.14, 0.88), Vector2(0.62, 0.88)], 0.06),
				_line([Vector2(0.12, 0.2), Vector2(0.38, 0.8), Vector2(0.66, 0.3)], 0.08),
				_poly([Vector2(0.84, 0.0), Vector2(0.56, 0.2), Vector2(0.78, 0.38)]),
			]
		&"kinetic_dash":
			return [
				_line([Vector2(0.08, 0.3), Vector2(0.46, 0.3)], 0.07),
				_line([Vector2(0.16, 0.5), Vector2(0.52, 0.5)], 0.07),
				_line([Vector2(0.08, 0.7), Vector2(0.46, 0.7)], 0.07),
				_circle(Vector2(0.72, 0.5), 0.17, 0.0),
			]
		&"overcharge":
			return [
				_poly(
					[
						Vector2(0.6, 0.04),
						Vector2(0.24, 0.56),
						Vector2(0.47, 0.56),
						Vector2(0.38, 0.96),
						Vector2(0.78, 0.4),
						Vector2(0.54, 0.4),
						Vector2(0.68, 0.04),
					]
				)
			]
		&"vampiric_core":
			var drop := [Vector2(0.5, 0.06)]
			for k in 13:
				var a := deg_to_rad(-30.0 + 240.0 * k / 12.0)
				drop.append(Vector2(0.5, 0.62) + Vector2(cos(a), sin(a)) * 0.28)
			return [_poly(drop), _circle(Vector2(0.42, 0.62), 0.07, 0.0, true)]
		&"static_chain":
			return [
				_loop(_ellipse(Vector2(0.36, 0.62), Vector2(0.24, 0.12), -45.0), 0.08),
				_loop(_ellipse(Vector2(0.64, 0.38), Vector2(0.24, 0.12), -45.0), 0.08),
			]
		&"momentum":
			return [
				_poly([Vector2(0.24, 0.3), Vector2(0.92, 0.38), Vector2(0.24, 0.46)]),
				_line([Vector2(0.24, 0.18), Vector2(0.24, 0.58)], 0.07),
				_line([Vector2(0.06, 0.38), Vector2(0.24, 0.38)], 0.08),
				_line([Vector2(0.12, 0.78), Vector2(0.68, 0.78)], 0.07),
				_poly([Vector2(0.66, 0.66), Vector2(0.9, 0.78), Vector2(0.66, 0.9)]),
			]
		&"frost_core":
			var out := []
			var c := Vector2(0.5, 0.5)
			for k in 6:
				var a := deg_to_rad(60.0 * k - 90.0)
				var dir := Vector2(cos(a), sin(a))
				out.append(_line([c, c + dir * 0.42], 0.06))
				var at := c + dir * 0.26
				out.append(
					_line([at + dir.rotated(-2.4) * 0.12, at, at + dir.rotated(2.4) * 0.12], 0.05)
				)
			return out
		&"thorn_mantle":
			var out := [_circle(Vector2(0.5, 0.5), 0.22, 0.08)]
			for k in 8:
				var a := deg_to_rad(45.0 * k)
				var dir := Vector2(cos(a), sin(a))
				var side := dir.orthogonal() * 0.07
				var base := Vector2(0.5, 0.5) + dir * 0.25
				out.append(_poly([base - side, Vector2(0.5, 0.5) + dir * 0.46, base + side]))
			return out
		&"executioner":
			return [
				_line([Vector2(0.5, 0.02), Vector2(0.5, 0.18)], 0.09),
				_line([Vector2(0.26, 0.2), Vector2(0.74, 0.2)], 0.08),
				_poly(
					[
						Vector2(0.38, 0.26),
						Vector2(0.62, 0.26),
						Vector2(0.62, 0.66),
						Vector2(0.5, 0.94),
						Vector2(0.38, 0.66),
					]
				),
			]
		&"swift_feet":
			return [
				_poly(
					[
						Vector2(0.4, 0.16),
						Vector2(0.62, 0.16),
						Vector2(0.62, 0.6),
						Vector2(0.88, 0.68),
						Vector2(0.9, 0.86),
						Vector2(0.4, 0.86),
					]
				),
				_line([Vector2(0.38, 0.32), Vector2(0.1, 0.18)], 0.06),
				_line([Vector2(0.38, 0.44), Vector2(0.06, 0.38)], 0.06),
				_line([Vector2(0.38, 0.56), Vector2(0.12, 0.58)], 0.06),
			]
		&"phase_strike":
			var star := []
			for k in 16:
				var a := deg_to_rad(22.5 * k - 90.0)
				star.append(
					Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * (0.24 if k % 2 == 0 else 0.09)
				)
			return [_circle(Vector2(0.5, 0.5), 0.4, 0.06), _poly(star)]
	return _engine_shapes(id)


## The v0.3.0 G engine items' symbols (the gem for an unknown id).
static func _engine_shapes(id: StringName) -> Array:
	match id:
		&"cinder_shot":
			return (
				_dart(Vector2(0.42, 0.58), Vector2(0.9, 0.1)) + [_flame(Vector2(0.26, 0.74), 0.5)]
			)
		&"wildfire":
			return [
				_flame(Vector2(0.24, 0.66), 0.5),
				_flame(Vector2(0.5, 0.5), 0.75),
				_flame(Vector2(0.76, 0.66), 0.5),
			]
		&"conductor":
			return [
				_line([Vector2(0.14, 0.86), Vector2(0.86, 0.14)], 0.07),
				_line(
					[
						Vector2(0.2, 0.3),
						Vector2(0.42, 0.42),
						Vector2(0.36, 0.56),
						Vector2(0.62, 0.66),
						Vector2(0.56, 0.8),
						Vector2(0.84, 0.88),
					],
					0.07
				),
				_circle(Vector2(0.86, 0.14), 0.09, 0.0),
			]
		&"serrated_edge":
			var saw := [Vector2(0.14, 0.86), Vector2(0.8, 0.08), Vector2(0.9, 0.18)]
			for k in 5:
				var t := (4 - k) / 5.0
				var base := Vector2(0.9, 0.18).lerp(Vector2(0.24, 0.94), 1.0 - t)
				saw.append(base + Vector2(0.06, 0.08))
				saw.append(base.lerp(Vector2(0.24, 0.94), 0.12))
			return [_poly(saw)]
		&"barbed_bolts":
			return [
				_line([Vector2(0.12, 0.88), Vector2(0.72, 0.28)], 0.07),
				_poly([Vector2(0.92, 0.08), Vector2(0.62, 0.22), Vector2(0.78, 0.38)]),
				_line([Vector2(0.5, 0.5), Vector2(0.34, 0.42)], 0.06),
				_line([Vector2(0.5, 0.5), Vector2(0.58, 0.66)], 0.06),
				_line([Vector2(0.32, 0.68), Vector2(0.16, 0.6)], 0.06),
				_line([Vector2(0.32, 0.68), Vector2(0.4, 0.84)], 0.06),
			]
		&"glacial_edge":
			return [
				_poly([Vector2(0.22, 0.7), Vector2(0.3, 0.78), Vector2(0.86, 0.14)]),
				_line([Vector2(0.14, 0.6), Vector2(0.4, 0.86)], 0.07),
				_poly(
					[
						Vector2(0.72, 0.5),
						Vector2(0.84, 0.66),
						Vector2(0.72, 0.9),
						Vector2(0.6, 0.66),
					]
				),
			]
		&"cold_snap":
			var out := [
				_line([Vector2(0.06, 0.34), Vector2(0.34, 0.34)], 0.06),
				_line([Vector2(0.02, 0.52), Vector2(0.3, 0.52)], 0.06),
				_line([Vector2(0.06, 0.7), Vector2(0.34, 0.7)], 0.06),
			]
			var c := Vector2(0.64, 0.52)
			for k in 3:
				var a := deg_to_rad(60.0 * k + 90.0)
				var dir := Vector2(cos(a), sin(a)) * 0.3
				out.append(_line([c - dir, c + dir], 0.07))
			return out
		&"bulwark":
			return [
				_poly(
					[
						Vector2(0.5, 0.06),
						Vector2(0.86, 0.18),
						Vector2(0.82, 0.58),
						Vector2(0.5, 0.94),
						Vector2(0.18, 0.58),
						Vector2(0.14, 0.18),
					]
				),
				_circle(Vector2(0.34, 0.4), 0.07, 0.0, true),
				_circle(Vector2(0.5, 0.4), 0.07, 0.0, true),
				_circle(Vector2(0.66, 0.4), 0.07, 0.0, true),
			]
		&"heat_sink", &"thermal_edge", &"meltdown":
			return _heat_icon(id)
	if CardPoolIcons.MOD_COLORS.has(id):
		return CardPoolIcons.shapes(id)  # v0.5.0 CP: the ability mods
	return gem()


## The Overclock heat items (v0.3.0 L18): radiator fins, a thermometer, a burst.
static func _heat_icon(id: StringName) -> Array:
	match id:
		&"heat_sink":
			var out := [
				_poly(
					[
						Vector2(0.12, 0.7),
						Vector2(0.88, 0.7),
						Vector2(0.88, 0.86),
						Vector2(0.12, 0.86)
					]
				)
			]
			for x: float in [0.22, 0.4, 0.6, 0.78]:
				out.append(_line([Vector2(x, 0.72), Vector2(x, 0.32)], 0.09))
			out.append(_arc(Vector2(0.5, 0.2), 0.12, 200.0, 340.0, 0.05))
			return out
		&"thermal_edge":
			return [
				_loop(
					[
						Vector2(0.42, 0.62),
						Vector2(0.42, 0.14),
						Vector2(0.5, 0.06),
						Vector2(0.58, 0.14),
						Vector2(0.58, 0.62),
					],
					0.05
				),
				_circle(Vector2(0.5, 0.76), 0.15, 0.0),
				_line([Vector2(0.5, 0.7), Vector2(0.5, 0.3)], 0.08),
				_line([Vector2(0.66, 0.24), Vector2(0.8, 0.24)], 0.05),
				_line([Vector2(0.66, 0.38), Vector2(0.76, 0.38)], 0.05),
				_line([Vector2(0.66, 0.52), Vector2(0.8, 0.52)], 0.05),
			]
		_:
			var star := []
			for k in 16:
				var a := TAU * k / 16.0 - PI * 0.5
				var r := 0.44 if k % 2 == 0 else 0.2
				star.append(Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * r)
			return [_poly(star), _circle(Vector2(0.5, 0.52), 0.1, 0.0, true)]


## The generic icon: a cut gem.
static func gem() -> Array:
	return [
		_poly([Vector2(0.5, 0.08), Vector2(0.82, 0.4), Vector2(0.5, 0.92), Vector2(0.18, 0.4)]),
		_line([Vector2(0.18, 0.4), Vector2(0.82, 0.4)], 0.05, true),
		_line([Vector2(0.36, 0.24), Vector2(0.5, 0.4), Vector2(0.64, 0.24)], 0.04, true),
	]


## Draws `id`'s icon into `rect` of `ci` (call it from _draw). Returns the number of shapes drawn.
static func draw(ci: CanvasItem, id: StringName, rect: Rect2, color: Color) -> int:
	var n := 0
	var side := minf(rect.size.x, rect.size.y)
	var origin := rect.position + (rect.size - Vector2(side, side)) * 0.5
	for s: Dictionary in shapes(id):
		var col := DARK if s.get("dark", false) else color
		match s["t"]:
			"line", "loop":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(origin + p * side)
				if s["t"] == "loop":
					pts.append(pts[0])
				ci.draw_polyline(pts, col, maxf(1.0, s["w"] * side), true)
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


static func _line(pts: Array, w: float, dark := false) -> Dictionary:
	return {"t": "line", "pts": PackedVector2Array(pts), "w": w, "dark": dark}


static func _loop(pts: Array, w: float) -> Dictionary:
	return {"t": "loop", "pts": PackedVector2Array(pts), "w": w}


static func _poly(pts: Array, dark := false) -> Dictionary:
	return {"t": "poly", "pts": PackedVector2Array(pts), "dark": dark}


static func _circle(c: Vector2, r: float, w: float, dark := false) -> Dictionary:
	return {"t": "circle", "c": c, "r": r, "w": w, "dark": dark}


## An arc as a polyline (degrees, y down: -90 is up).
static func _arc(c: Vector2, r: float, from_deg: float, to_deg: float, w: float) -> Dictionary:
	var pts := []
	for k in 13:
		var a := deg_to_rad(lerpf(from_deg, to_deg, k / 12.0))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return _line(pts, w)


static func _ellipse(c: Vector2, radii: Vector2, rot_deg: float) -> Array:
	var pts := []
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(c + (Vector2(cos(a) * radii.x, sin(a) * radii.y)).rotated(deg_to_rad(rot_deg)))
	return pts


## A small flame (a filled teardrop pointing up) centred at `c`, `scale` of the full icon height.
static func _flame(c: Vector2, scale: float) -> Dictionary:
	var pts := []
	for p: Vector2 in [
		Vector2(0.0, -0.44),
		Vector2(0.2, -0.16),
		Vector2(0.28, 0.1),
		Vector2(0.18, 0.32),
		Vector2(0.0, 0.42),
		Vector2(-0.18, 0.32),
		Vector2(-0.28, 0.1),
		Vector2(-0.2, -0.12),
		Vector2(-0.08, 0.0),
	]:
		pts.append(c + p * scale)
	return _poly(pts)


## A dart from `from` to `to`: a shaft and a head.
static func _dart(from: Vector2, to: Vector2) -> Array:
	var dir := (to - from).normalized()
	var side := dir.orthogonal() * 0.07
	var back := to - dir * 0.16
	return [_line([from + dir * 0.06, back], 0.06), _poly([back - side, to, back + side])]
