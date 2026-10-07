class_name GambleIcons
extends RefCounted
## The gamble shrine's stat symbols and lines (v0.3.0 L19), drawn with CanvasItem calls, no external art. Each icon
## is a list of shapes in a unit box (0..1, y down), like ItemIcons: {"t": "line"|"loop"|"poly", "pts", "w"} or
## {"t": "circle", "c", "r", "w" (0 = filled)}; "dark": true draws it in DARK.

const DARK := Color(0.05, 0.06, 0.09)
## The shrine's core colour (its glow, the stats panel's rim).
const CORE := Color("#3FF2D0")
## Per stat id: the icon colour.
const COLORS := {
	&"max_hp": Color("#FF5A6A"),
	&"melee_damage": Color("#FFB04A"),
	&"shot_damage": Color("#5AD8FF"),
	&"move_speed": Color("#7CFF8A"),
	&"dash_cooldown": Color("#F4E27A"),
	&"regen": Color("#FF8FC8"),
	&"heat_capacity": Color("#FF7A3A"),
	&"shard_gain": Color("#C9A8FF"),
}
## Per stat id: its line's locale key.
const KEYS := {
	&"max_hp": "UI_GAMBLE_MAX_HP",
	&"melee_damage": "UI_GAMBLE_MELEE_DAMAGE",
	&"shot_damage": "UI_GAMBLE_SHOT_DAMAGE",
	&"move_speed": "UI_GAMBLE_MOVE_SPEED",
	&"dash_cooldown": "UI_GAMBLE_DASH_COOLDOWN",
	&"regen": "UI_GAMBLE_REGEN",
	&"heat_capacity": "UI_GAMBLE_HEAT_CAPACITY",
	&"shard_gain": "UI_GAMBLE_SHARD_GAIN",
}


static func color(id: StringName) -> Color:
	return COLORS.get(id, Color.WHITE)


## The translated line for `value` of stat `id` (HP for max_hp, per mille otherwise): "+6 % melee damage".
static func line(ci: Object, id: StringName, value: int) -> String:
	var key: String = KEYS.get(id, "UI_GAMBLE_MAX_HP")
	if id == &"max_hp":
		return ci.tr(key) % value
	return ci.tr(key) % percent(value)


## Per mille as a percent string: 60 -> "6", 5 -> "0.5", 125 -> "12.5".
static func percent(permille: int) -> String:
	if permille % 10 == 0:
		return str(permille / 10)
	return "%d.%d" % [permille / 10, permille % 10]


static func shapes(id: StringName) -> Array:
	match id:
		&"max_hp":
			return [
				_poly(
					[
						Vector2(0.5, 0.9),
						Vector2(0.12, 0.5),
						Vector2(0.12, 0.3),
						Vector2(0.28, 0.14),
						Vector2(0.42, 0.16),
						Vector2(0.5, 0.26),
						Vector2(0.58, 0.16),
						Vector2(0.72, 0.14),
						Vector2(0.88, 0.3),
						Vector2(0.88, 0.5),
					]
				),
				_line([Vector2(0.5, 0.34), Vector2(0.5, 0.66)], 0.08, true),
				_line([Vector2(0.34, 0.5), Vector2(0.66, 0.5)], 0.08, true),
			]
		&"melee_damage":
			return [
				_poly(
					[
						Vector2(0.18, 0.74),
						Vector2(0.26, 0.82),
						Vector2(0.78, 0.22),
						Vector2(0.72, 0.16)
					]
				),
				_line([Vector2(0.12, 0.66), Vector2(0.34, 0.88)], 0.07),
				_line([Vector2(0.58, 0.9), Vector2(0.74, 0.7), Vector2(0.9, 0.9)], 0.07),
			]
		&"shot_damage":
			return [
				_line([Vector2(0.12, 0.62), Vector2(0.62, 0.62)], 0.08),
				_poly([Vector2(0.58, 0.48), Vector2(0.86, 0.62), Vector2(0.58, 0.76)]),
				_line([Vector2(0.3, 0.36), Vector2(0.48, 0.14), Vector2(0.66, 0.36)], 0.07),
			]
		&"move_speed":
			return [
				_line([Vector2(0.16, 0.2), Vector2(0.46, 0.5), Vector2(0.16, 0.8)], 0.1),
				_line([Vector2(0.48, 0.2), Vector2(0.78, 0.5), Vector2(0.48, 0.8)], 0.1),
			]
		&"dash_cooldown":
			return [
				_circle(Vector2(0.5, 0.54), 0.34, 0.08),
				_line([Vector2(0.5, 0.54), Vector2(0.5, 0.32)], 0.07),
				_line([Vector2(0.5, 0.54), Vector2(0.66, 0.62)], 0.07),
				_line([Vector2(0.4, 0.1), Vector2(0.6, 0.1)], 0.08),
			]
		&"regen":
			return [
				_poly(
					[
						Vector2(0.5, 0.08),
						Vector2(0.76, 0.46),
						Vector2(0.8, 0.64),
						Vector2(0.68, 0.84),
						Vector2(0.5, 0.9),
						Vector2(0.32, 0.84),
						Vector2(0.2, 0.64),
						Vector2(0.24, 0.46),
					]
				),
				_line([Vector2(0.5, 0.48), Vector2(0.5, 0.78)], 0.08, true),
				_line([Vector2(0.35, 0.63), Vector2(0.65, 0.63)], 0.08, true),
			]
		&"heat_capacity":
			return [
				_poly(
					[
						Vector2(0.5, 0.06),
						Vector2(0.72, 0.38),
						Vector2(0.78, 0.62),
						Vector2(0.66, 0.84),
						Vector2(0.5, 0.92),
						Vector2(0.34, 0.84),
						Vector2(0.22, 0.62),
						Vector2(0.3, 0.4),
						Vector2(0.42, 0.5),
						Vector2(0.44, 0.28),
					]
				),
				_poly(
					[
						Vector2(0.5, 0.5),
						Vector2(0.6, 0.66),
						Vector2(0.56, 0.8),
						Vector2(0.44, 0.8),
						Vector2(0.4, 0.66),
					],
					true
				),
			]
		&"shard_gain":
			return [
				_poly(
					[
						Vector2(0.42, 0.1),
						Vector2(0.7, 0.42),
						Vector2(0.42, 0.9),
						Vector2(0.14, 0.42)
					]
				),
				_line([Vector2(0.14, 0.42), Vector2(0.7, 0.42)], 0.05, true),
				_line([Vector2(0.8, 0.12), Vector2(0.8, 0.36)], 0.07),
				_line([Vector2(0.68, 0.24), Vector2(0.92, 0.24)], 0.07),
			]
	return [_circle(Vector2(0.5, 0.5), 0.3, 0.0)]


## Draws stat `id`'s icon into `rect` of `ci` (call it from _draw) in `col` (the stat's colour by default).
## Returns the number of shapes drawn.
static func draw(
	ci: CanvasItem, id: StringName, rect: Rect2, col: Color = Color(0, 0, 0, 0)
) -> int:
	var c := color(id) if col.a == 0.0 else col
	var side := minf(rect.size.x, rect.size.y)
	var origin := rect.position + (rect.size - Vector2(side, side)) * 0.5
	var n := 0
	for s: Dictionary in shapes(id):
		var sc := DARK if s.get("dark", false) else c
		match s["t"]:
			"line":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(origin + p * side)
				ci.draw_polyline(pts, sc, maxf(1.0, s["w"] * side), true)
			"poly":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(origin + p * side)
				ci.draw_colored_polygon(pts, sc)
			"circle":
				var w: float = s["w"]
				ci.draw_circle(
					origin + s["c"] * side,
					s["r"] * side,
					sc,
					w <= 0.0,
					-1.0 if w <= 0.0 else maxf(1.0, w * side),
					true
				)
		n += 1
	return n


static func _line(pts: Array, w: float, dark := false) -> Dictionary:
	return {"t": "line", "pts": PackedVector2Array(pts), "w": w, "dark": dark}


static func _poly(pts: Array, dark := false) -> Dictionary:
	return {"t": "poly", "pts": PackedVector2Array(pts), "dark": dark}


static func _circle(c: Vector2, r: float, w: float, dark := false) -> Dictionary:
	return {"t": "circle", "c": c, "r": r, "w": w, "dark": dark}
