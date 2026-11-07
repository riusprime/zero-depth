class_name SpellLooks
extends RefCounted
## v0.11.0 O10 (SPELLS.md "Readability": every spell its element's colour and a shape no enemy attack uses): the spells'
## colours (their element's, from the status colours: never the bosses' red or purple) and their placeholder icons,
## drawn with lines on any CanvasItem (the HUD squares, the pick card's icon). Presentation only.

## By element (WorldReader.SPELL_ELEMENT_* order: frost, fire, lightning, venom, bleed).
const COLORS: Array[Color] = [
	Color("#BFF4FF"),
	Color("#FF9A3D"),
	Color("#9FC8FF"),
	Color("#8EE06A"),
	Color("#E04A5E"),
]


static func color(element: int) -> Color:
	return COLORS[clampi(element, 0, COLORS.size() - 1)]


## Spell `id`'s placeholder icon inside `r` on `ci`, in `c`: Frost Nova a six-spoked snowflake, Fireball a flame drop
## over a ring of sparks, Sky Strike a zigzag bolt. An unknown id: a small diamond.
static func draw_icon(ci: CanvasItem, id: StringName, r: Rect2, c: Color) -> void:
	var o := r.get_center()
	var h := minf(r.size.x, r.size.y) * 0.5
	var w := maxf(2.0, h * 0.14)
	match id:
		&"spell_frost_nova":
			for k in 6:
				var a := TAU * k / 6.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(o, o + d * h, c, w, true)
				var m := o + d * h * 0.6
				var side := Vector2(-d.y, d.x) * h * 0.22
				ci.draw_line(m, m + d * h * 0.22 + side, c, w * 0.7, true)
				ci.draw_line(m, m + d * h * 0.22 - side, c, w * 0.7, true)
		&"spell_fireball":
			ci.draw_colored_polygon(_drop(o, h), Color(c, 0.9))
			for k in 8:
				var d := Vector2(cos(TAU * k / 8.0), sin(TAU * k / 8.0))
				ci.draw_line(o + d * h * 0.72, o + d * h * 0.98, c, w * 0.7, true)
		&"spell_sky_strike":
			var pts := PackedVector2Array(
				[
					o + Vector2(h * 0.25, -h),
					o + Vector2(-h * 0.35, h * 0.05),
					o + Vector2(h * 0.15, h * 0.05),
					o + Vector2(-h * 0.3, h),
				]
			)
			ci.draw_polyline(pts, c, w * 1.2, true)
		_:
			ci.draw_colored_polygon(
				PackedVector2Array(
					[
						o + Vector2(0, -h * 0.5),
						o + Vector2(h * 0.5, 0),
						o + Vector2(0, h * 0.5),
						o + Vector2(-h * 0.5, 0)
					]
				),
				c
			)


## A flame drop: a round bottom and a point on top.
static func _drop(o: Vector2, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := o + Vector2(0, h * 0.2)
	for k in 13:
		var a := PI * k / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * h * 0.34)
	pts.append(o + Vector2(0, -h * 0.6))
	return pts
