class_name CardPoolIcons
extends RefCounted
## The symbols of the v0.5.0 CP cards, in the item icons' style (ItemIcons: shapes in a unit box, y down, drawn with
## CanvasItem calls, no external art): the rule stat cards (AbilityIcons falls through to these). the four
## ability mods' symbols went with their cards.

## The rule stat cards and their colours.
const STAT_COLORS := {
	&"glass_cannon": Color("#DFF4FF"),
	&"onrush": Color("#FF8A5A"),
	&"overkill": Color("#FF4A6A"),
	&"hoarder": Color("#F2C14E"),
	&"fast_hands": Color("#6AF0FF"),
	&"lifesprout": Color("#7DF29C"),  # Green = healing (the card frame mapping)
	# The rule cards that replace the flat stats
	&"vent_mend": Color("#7DF29C"),
	&"heat_shield": Color("#FFB45A"),
	&"adrenaline": Color("#FFE45A"),
	&"close_quarters": Color("#FF6A4A"),
	&"third_strike": Color("#FF9A6A"),
	&"reflex": Color("#6AF0FF"),
	&"scavenger": Color("#F2C14E"),
}


static func has_icon(id: StringName) -> bool:
	return STAT_COLORS.has(id)


static func color(id: StringName) -> Color:
	return STAT_COLORS.get(id, Color.WHITE)


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
	return _rule_shapes(id)


## The seven rule cards that replace the flat stats.
static func _rule_shapes(id: StringName) -> Array:
	match id:
		&"vent_mend":  # a blast ring round a cross
			return [
				_circle(Vector2(0.5, 0.5), 0.38, 0.05),
				_line([Vector2(0.5, 0.3), Vector2(0.5, 0.7)], 0.1),
				_line([Vector2(0.3, 0.5), Vector2(0.7, 0.5)], 0.1),
			]
		&"heat_shield":  # a shield with a flame
			return [
				_poly(
					[
						Vector2(0.18, 0.14),
						Vector2(0.82, 0.14),
						Vector2(0.78, 0.6),
						Vector2(0.5, 0.9),
						Vector2(0.22, 0.6)
					]
				),
				_poly(
					[Vector2(0.5, 0.26), Vector2(0.64, 0.5), Vector2(0.5, 0.7), Vector2(0.36, 0.5)],
					true
				),
			]
		&"adrenaline":  # a bolt
			return [
				_poly(
					[
						Vector2(0.58, 0.06),
						Vector2(0.22, 0.56),
						Vector2(0.46, 0.56),
						Vector2(0.38, 0.94),
						Vector2(0.8, 0.4),
						Vector2(0.54, 0.4)
					]
				),
			]
		&"close_quarters":  # two arrows meeting
			return [
				_poly([Vector2(0.06, 0.3), Vector2(0.44, 0.5), Vector2(0.06, 0.7)]),
				_poly([Vector2(0.94, 0.3), Vector2(0.56, 0.5), Vector2(0.94, 0.7)]),
			]
		&"third_strike":  # three bars, the last one tall
			return [
				_line([Vector2(0.2, 0.62), Vector2(0.2, 0.86)], 0.12),
				_line([Vector2(0.5, 0.5), Vector2(0.5, 0.86)], 0.12),
				_line([Vector2(0.8, 0.14), Vector2(0.8, 0.86)], 0.16),
			]
		&"reflex":  # a clock hand turning back
			return [
				_circle(Vector2(0.5, 0.54), 0.34, 0.05),
				_line([Vector2(0.5, 0.54), Vector2(0.5, 0.32)], 0.06),
				_poly([Vector2(0.06, 0.2), Vector2(0.3, 0.12), Vector2(0.22, 0.36)]),
			]
		&"scavenger":  # a shard with a spark
			return [
				_poly(
					[Vector2(0.4, 0.2), Vector2(0.62, 0.5), Vector2(0.4, 0.88), Vector2(0.18, 0.5)]
				),
				_line([Vector2(0.72, 0.1), Vector2(0.72, 0.34)], 0.05),
				_line([Vector2(0.6, 0.22), Vector2(0.84, 0.22)], 0.05),
			]
	return [_circle(Vector2(0.5, 0.5), 0.3, 0.0)]


static func _line(pts: Array, w: float, dark := false) -> Dictionary:
	return {"t": "line", "pts": PackedVector2Array(pts), "w": w, "dark": dark}


static func _loop(pts: Array, w: float) -> Dictionary:
	return {"t": "loop", "pts": PackedVector2Array(pts), "w": w}


static func _poly(pts: Array, dark := false) -> Dictionary:
	return {"t": "poly", "pts": PackedVector2Array(pts), "dark": dark}


static func _circle(c: Vector2, r: float, w: float, dark := false) -> Dictionary:
	return {"t": "circle", "c": c, "r": r, "w": w, "dark": dark}
