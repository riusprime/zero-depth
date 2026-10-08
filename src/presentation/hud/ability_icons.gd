class_name AbilityIcons
extends RefCounted
## The symbols of the abilities and the stat cards (v0.4.0 BS), in the item icons' style (ItemIcons: shapes in a
## unit box, y down, drawn with CanvasItem calls, no external art). ItemIcons.shapes falls through to these, so an
## ItemIconView / ItemCard shows any card. Stats the gamble shrine shares reuse its symbols (GambleIcons).

## Ability ids and their colours: the hero's cyan for the weapons, a colour per ability card.
const ABILITY_COLORS := {
	&"combo_sword": Color("#9FE8FF"),
	&"pulse_gun": Color("#5AD8FF"),
	&"bomb_lobber": Color("#FF8A3A"),
	&"drone_buddy": Color("#2BC4E2"),
	&"orbit_blades": Color("#D6E4F0"),
	&"blink": Color("#B48CFF"),
	&"aegis": Color("#F4E27A"),
	&"arc_field": Color("#9FC8FF"),
	&"frost_nova": Color("#BFF4FF"),
	&"flame_trail": Color("#FF7A3D"),
}
## Stat card ids and their colours.
const STAT_COLORS := {
	&"max_hp": Color("#FF5A6A"),
	&"damage": Color("#FFB04A"),
	&"crit_chance": Color("#FFE14A"),
	&"crit_damage": Color("#FFD23A"),
	&"attack_speed": Color("#7CE8FF"),
	&"area": Color("#9AF0C8"),
	&"cooldowns": Color("#F4E27A"),
	&"move_speed": Color("#7CFF8A"),
	&"regen": Color("#FF8FC8"),
	&"shard_gain": Color("#C9A8FF"),
	&"pickup_range": Color("#8FB4FF"),
	&"armour": Color("#B8C2CC"),
}
## Stats drawn with the gamble shrine's symbol of the same meaning.
const GAMBLE_SHAPES := {
	&"max_hp": &"max_hp",
	&"damage": &"melee_damage",
	&"cooldowns": &"dash_cooldown",
	&"move_speed": &"move_speed",
	&"regen": &"regen",
	&"shard_gain": &"shard_gain",
}


static func has_icon(id: StringName) -> bool:
	return ABILITY_COLORS.has(id) or STAT_COLORS.has(id) or CardPoolIcons.STAT_COLORS.has(id)


static func color(id: StringName) -> Color:
	if CardPoolIcons.has_icon(id):
		return CardPoolIcons.color(id)  # v0.5.0 CP
	return ABILITY_COLORS.get(id, STAT_COLORS.get(id, Color.WHITE))


static func shapes(id: StringName) -> Array:
	if CardPoolIcons.STAT_COLORS.has(id):
		return CardPoolIcons.shapes(id)  # v0.5.0 CP: the rule stat cards
	if GAMBLE_SHAPES.has(id):
		return GambleIcons.shapes(GAMBLE_SHAPES[id])
	match id:
		&"combo_sword":
			return [
				_poly(
					[
						Vector2(0.2, 0.72),
						Vector2(0.28, 0.8),
						Vector2(0.86, 0.14),
						Vector2(0.78, 0.1)
					]
				),
				_line([Vector2(0.12, 0.62), Vector2(0.38, 0.88)], 0.07),
				_line([Vector2(0.24, 0.76), Vector2(0.1, 0.9)], 0.08),
				_arc(Vector2(0.5, 0.5), 0.42, 150.0, 300.0, 0.05),
			]
		&"pulse_gun":
			return [
				_poly(
					[
						Vector2(0.12, 0.38),
						Vector2(0.62, 0.38),
						Vector2(0.62, 0.54),
						Vector2(0.12, 0.54)
					]
				),
				_poly(
					[
						Vector2(0.18, 0.54),
						Vector2(0.34, 0.54),
						Vector2(0.28, 0.8),
						Vector2(0.14, 0.8)
					]
				),
				_circle(Vector2(0.74, 0.46), 0.06, 0.0),
				_circle(Vector2(0.88, 0.46), 0.04, 0.0),
			]
		&"bomb_lobber":
			return [
				_circle(Vector2(0.44, 0.6), 0.28, 0.0),
				_circle(Vector2(0.36, 0.52), 0.07, 0.0, true),
				_line([Vector2(0.62, 0.38), Vector2(0.72, 0.22), Vector2(0.84, 0.18)], 0.06),
				_circle(Vector2(0.88, 0.14), 0.05, 0.0),
			]
		&"drone_buddy":
			return [
				_line([Vector2(0.2, 0.18), Vector2(0.8, 0.18)], 0.06),
				_line([Vector2(0.5, 0.18), Vector2(0.5, 0.3)], 0.06),
				_poly(
					[Vector2(0.26, 0.3), Vector2(0.74, 0.3), Vector2(0.8, 0.62), Vector2(0.2, 0.62)]
				),
				_circle(Vector2(0.38, 0.44), 0.06, 0.0, true),
				_circle(Vector2(0.62, 0.44), 0.06, 0.0, true),
				_poly([Vector2(0.4, 0.62), Vector2(0.6, 0.62), Vector2(0.5, 0.86)]),
			]
		&"orbit_blades":
			return [
				_circle(Vector2(0.5, 0.5), 0.3, 0.035),
				_circle(Vector2(0.5, 0.5), 0.09, 0.0),
				_poly([Vector2(0.5, 0.06), Vector2(0.62, 0.22), Vector2(0.5, 0.28)]),
				_poly([Vector2(0.88, 0.72), Vector2(0.7, 0.74), Vector2(0.7, 0.62)]),
				_poly([Vector2(0.12, 0.72), Vector2(0.24, 0.58), Vector2(0.3, 0.7)]),
			]
		&"blink":
			return [
				_loop(
					[
						Vector2(0.24, 0.32),
						Vector2(0.38, 0.5),
						Vector2(0.24, 0.68),
						Vector2(0.1, 0.5)
					],
					0.05
				),
				_poly(
					[
						Vector2(0.74, 0.28),
						Vector2(0.92, 0.5),
						Vector2(0.74, 0.72),
						Vector2(0.56, 0.5)
					]
				),
				_line([Vector2(0.36, 0.5), Vector2(0.56, 0.5)], 0.05),
				_circle(Vector2(0.74, 0.5), 0.36, 0.03),
			]
		&"aegis", &"armour":
			return [
				_poly(
					[
						Vector2(0.5, 0.08),
						Vector2(0.86, 0.22),
						Vector2(0.8, 0.6),
						Vector2(0.5, 0.92),
						Vector2(0.2, 0.6),
						Vector2(0.14, 0.22),
					]
				),
				_line([Vector2(0.5, 0.2), Vector2(0.5, 0.8)], 0.06, true),
			]
		&"crit_chance":
			return [
				_circle(Vector2(0.5, 0.5), 0.32, 0.06),
				_circle(Vector2(0.5, 0.5), 0.08, 0.0),
				_line([Vector2(0.5, 0.06), Vector2(0.5, 0.26)], 0.06),
				_line([Vector2(0.5, 0.74), Vector2(0.5, 0.94)], 0.06),
				_line([Vector2(0.06, 0.5), Vector2(0.26, 0.5)], 0.06),
				_line([Vector2(0.74, 0.5), Vector2(0.94, 0.5)], 0.06),
			]
		&"crit_damage":
			var star := []
			for k in 10:
				var a := deg_to_rad(-90.0 + 36.0 * k)
				star.append(
					Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * (0.44 if k % 2 == 0 else 0.18)
				)
			return [_poly(star)]
		&"attack_speed":
			return [
				_line([Vector2(0.16, 0.2), Vector2(0.46, 0.5), Vector2(0.16, 0.8)], 0.09),
				_line([Vector2(0.5, 0.2), Vector2(0.8, 0.5), Vector2(0.5, 0.8)], 0.09),
			]
		&"area":
			return [
				_circle(Vector2(0.5, 0.5), 0.4, 0.05),
				_circle(Vector2(0.5, 0.5), 0.24, 0.05),
				_circle(Vector2(0.5, 0.5), 0.08, 0.0),
			]
		&"pickup_range":
			return [
				_line(
					[
						Vector2(0.22, 0.14),
						Vector2(0.22, 0.56),
						Vector2(0.36, 0.78),
						Vector2(0.5, 0.82),
						Vector2(0.64, 0.78),
						Vector2(0.78, 0.56),
						Vector2(0.78, 0.14),
					],
					0.12
				),
				_line([Vector2(0.16, 0.2), Vector2(0.28, 0.2)], 0.08, true),
				_line([Vector2(0.72, 0.2), Vector2(0.84, 0.2)], 0.08, true),
			]
		&"arc_field":  # v0.4.0 AB: a bolt forking into three
			return [
				_line(
					[
						Vector2(0.5, 0.06),
						Vector2(0.38, 0.36),
						Vector2(0.56, 0.42),
						Vector2(0.44, 0.62)
					],
					0.08
				),
				_line([Vector2(0.44, 0.62), Vector2(0.16, 0.9)], 0.06),
				_line([Vector2(0.44, 0.62), Vector2(0.48, 0.94)], 0.06),
				_line([Vector2(0.44, 0.62), Vector2(0.84, 0.88)], 0.06),
				_circle(Vector2(0.16, 0.9), 0.05, 0.0),
				_circle(Vector2(0.48, 0.94), 0.05, 0.0),
				_circle(Vector2(0.84, 0.88), 0.05, 0.0),
			]
		&"frost_nova":  # a six-point flake inside a ring
			var flake := [_circle(Vector2(0.5, 0.5), 0.42, 0.05)]
			for k in 3:
				var a := deg_to_rad(90.0 + 60.0 * k)
				var d := Vector2(cos(a), sin(a)) * 0.3
				flake.append(_line([Vector2(0.5, 0.5) - d, Vector2(0.5, 0.5) + d], 0.07))
			return flake
		&"flame_trail":  # three flames along a ground line
			var out := [_line([Vector2(0.06, 0.86), Vector2(0.94, 0.86)], 0.05)]
			for k in 3:
				var x := 0.2 + 0.3 * k
				var h := 0.3 + 0.12 * k
				(
					out
					. append(
						_poly(
							[
								Vector2(x - 0.11, 0.8),
								Vector2(x - 0.07, 0.8 - h * 0.5),
								Vector2(x, 0.8 - h),
								Vector2(x + 0.07, 0.8 - h * 0.5),
								Vector2(x + 0.11, 0.8),
							]
						)
					)
				)
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


## An arc as a polyline (degrees, y down: -90 is up).
static func _arc(c: Vector2, r: float, from_deg: float, to_deg: float, w: float) -> Dictionary:
	var pts := []
	for k in 13:
		var a := deg_to_rad(lerpf(from_deg, to_deg, k / 12.0))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return _line(pts, w)
