class_name CardPoolIcons
extends RefCounted
## The symbols of the v0.5.0 CP cards, in the item icons' style (ItemIcons: shapes in a unit box, y down, drawn with
## CanvasItem calls, no external art): the five rule stat cards (AbilityIcons falls through to these) and the four
## ability mods (ItemIcons falls through to these).

## The rule stat cards and their colours.
const STAT_COLORS := {
	&"glass_cannon": Color("#DFF4FF"),
	&"onrush": Color("#FF8A5A"),
	&"overkill": Color("#FF4A6A"),
	&"hoarder": Color("#F2C14E"),
	&"fast_hands": Color("#6AF0FF"),
	&"lifesprout": Color("#7DF29C"),  # v0.5.5 EC (D9): green = healing (the card frame mapping)
}
## The ability mods and their colours (each a shade of its ability's).
const MOD_COLORS := {
	&"cluster_payload": Color("#FFA05A"),
	&"overclocked_drone": Color("#FF6A3A"),
	&"razor_orbit": Color("#E04A5E"),
	&"afterimage": Color("#D2B8FF"),
}


static func has_icon(id: StringName) -> bool:
	return STAT_COLORS.has(id) or MOD_COLORS.has(id)


static func color(id: StringName) -> Color:
	return STAT_COLORS.get(id, MOD_COLORS.get(id, Color.WHITE))


static func shapes(id: StringName) -> Array:
	match id:
		&"glass_cannon":
			return [
				_poly(
					[
						Vector2(0.5, 0.06),
						Vector2(0.78, 0.3),
						Vector2(0.7, 0.86),
						Vector2(0.3, 0.86),
						Vector2(0.22, 0.3),
					]
				),
				_line(
					[
						Vector2(0.46, 0.14),
						Vector2(0.56, 0.38),
						Vector2(0.42, 0.56),
						Vector2(0.54, 0.8)
					],
					0.05,
					true
				),
			]
		&"onrush":
			return [
				_line([Vector2(0.08, 0.32), Vector2(0.36, 0.32)], 0.06),
				_line([Vector2(0.04, 0.5), Vector2(0.4, 0.5)], 0.06),
				_line([Vector2(0.08, 0.68), Vector2(0.36, 0.68)], 0.06),
				_poly([Vector2(0.48, 0.16), Vector2(0.94, 0.5), Vector2(0.48, 0.84)]),
			]
		&"overkill":
			return [
				_circle(Vector2(0.32, 0.64), 0.22, 0.0),
				_line([Vector2(0.18, 0.5), Vector2(0.46, 0.78)], 0.06, true),
				_line([Vector2(0.46, 0.5), Vector2(0.18, 0.78)], 0.06, true),
				_line([Vector2(0.5, 0.44), Vector2(0.72, 0.26)], 0.06),
				_circle(Vector2(0.8, 0.2), 0.12, 0.05),
			]
		&"hoarder":
			var out := []
			for k in 3:
				var y := 0.78 - k * 0.2
				out.append(
					_poly(
						[
							Vector2(0.2, y - 0.08),
							Vector2(0.8, y - 0.08),
							Vector2(0.8, y + 0.08),
							Vector2(0.2, y + 0.08)
						]
					)
				)
				out.append(_line([Vector2(0.24, y + 0.08), Vector2(0.76, y + 0.08)], 0.03, true))
			out.append(_circle(Vector2(0.5, 0.18), 0.1, 0.0))
			return out
		&"fast_hands":
			return [
				_circle(Vector2(0.44, 0.54), 0.34, 0.05),
				_line([Vector2(0.44, 0.54), Vector2(0.44, 0.32)], 0.06),
				_line([Vector2(0.44, 0.54), Vector2(0.6, 0.62)], 0.06),
				_line([Vector2(0.72, 0.1), Vector2(0.92, 0.2), Vector2(0.78, 0.34)], 0.06),
			]
		&"lifesprout":
			return [
				_line([Vector2(0.5, 0.9), Vector2(0.5, 0.42)], 0.06),
				_poly(
					[Vector2(0.5, 0.5), Vector2(0.2, 0.36), Vector2(0.14, 0.14), Vector2(0.4, 0.24)]
				),
				_poly(
					[
						Vector2(0.5, 0.42),
						Vector2(0.84, 0.24),
						Vector2(0.9, 0.04),
						Vector2(0.6, 0.12)
					]
				),
				_circle(Vector2(0.5, 0.9), 0.08, 0.0),
			]
	return _mod_shapes(id)


static func _mod_shapes(id: StringName) -> Array:
	match id:
		&"cluster_payload":
			return [
				_circle(Vector2(0.5, 0.36), 0.22, 0.0),
				_circle(Vector2(0.42, 0.3), 0.05, 0.0, true),
				_circle(Vector2(0.18, 0.8), 0.09, 0.0),
				_circle(Vector2(0.5, 0.88), 0.09, 0.0),
				_circle(Vector2(0.82, 0.8), 0.09, 0.0),
				_line([Vector2(0.38, 0.56), Vector2(0.24, 0.72)], 0.04),
				_line([Vector2(0.5, 0.6), Vector2(0.5, 0.78)], 0.04),
				_line([Vector2(0.62, 0.56), Vector2(0.76, 0.72)], 0.04),
			]
		&"overclocked_drone":
			return [
				_poly(
					[
						Vector2(0.14, 0.4),
						Vector2(0.58, 0.4),
						Vector2(0.64, 0.72),
						Vector2(0.08, 0.72)
					]
				),
				_circle(Vector2(0.24, 0.55), 0.05, 0.0, true),
				_circle(Vector2(0.46, 0.55), 0.05, 0.0, true),
				_line([Vector2(0.14, 0.28), Vector2(0.58, 0.28)], 0.05),
				_line(
					[
						Vector2(0.74, 0.84),
						Vector2(0.84, 0.66),
						Vector2(0.74, 0.48),
						Vector2(0.84, 0.3)
					],
					0.05
				),
				_line(
					[
						Vector2(0.86, 0.76),
						Vector2(0.94, 0.6),
						Vector2(0.86, 0.44),
						Vector2(0.94, 0.28)
					],
					0.04
				),
			]
		&"razor_orbit":
			return [
				_circle(Vector2(0.5, 0.5), 0.32, 0.035),
				_poly([Vector2(0.5, 0.04), Vector2(0.66, 0.2), Vector2(0.5, 0.26)]),
				_poly([Vector2(0.92, 0.66), Vector2(0.72, 0.72), Vector2(0.74, 0.58)]),
				_poly([Vector2(0.1, 0.72), Vector2(0.22, 0.54), Vector2(0.3, 0.68)]),
				_poly(
					[
						Vector2(0.5, 0.34),
						Vector2(0.62, 0.56),
						Vector2(0.5, 0.66),
						Vector2(0.38, 0.56)
					]
				),
			]
		&"afterimage":
			var out := [
				_loop(
					[Vector2(0.3, 0.3), Vector2(0.46, 0.5), Vector2(0.3, 0.7), Vector2(0.14, 0.5)],
					0.05
				),
				_poly(
					[
						Vector2(0.78, 0.36),
						Vector2(0.9, 0.5),
						Vector2(0.78, 0.64),
						Vector2(0.66, 0.5)
					]
				),
			]
			for k in 6:
				var a := deg_to_rad(60.0 * k)
				var d := Vector2(cos(a), sin(a))
				out.append(_line([Vector2(0.3, 0.5) + d * 0.3, Vector2(0.3, 0.5) + d * 0.42], 0.04))
			return out
	return [_circle(Vector2(0.5, 0.5), 0.3, 0.0)]


static func _line(pts: Array, w: float, dark := false) -> Dictionary:
	return {"t": "line", "pts": PackedVector2Array(pts), "w": w, "dark": dark}


static func _loop(pts: Array, w: float) -> Dictionary:
	return {"t": "loop", "pts": PackedVector2Array(pts), "w": w}


static func _poly(pts: Array, dark := false) -> Dictionary:
	return {"t": "poly", "pts": PackedVector2Array(pts), "dark": dark}


static func _circle(c: Vector2, r: float, w: float, dark := false) -> Dictionary:
	return {"t": "circle", "c": c, "r": r, "w": w, "dark": dark}
