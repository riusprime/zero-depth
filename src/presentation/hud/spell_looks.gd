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

const ROSTER_ICONS: Array[StringName] = [
	&"spell_blizzard",
	&"spell_ice_lances",
	&"spell_burning_ground",
	&"spell_meteor",
	&"spell_ball_lightning",
	&"spell_static_field",
	&"spell_venom_orb",
	&"spell_toxic_cloud",
	&"spell_spitter_vine",
	&"spell_blood_thorns",
	&"spell_hemorrhage",
	&"spell_leech",
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
			if not _draw_roster(ci, id, o, h, w, c):
				_diamond(ci, o, h, c)


## v0.11.0 O11: the twelve spells O11 added have an icon (placeholders, each its own shape).
static func has_icon(id: StringName) -> bool:
	return (
		[&"spell_frost_nova", &"spell_fireball", &"spell_sky_strike"].has(id)
		or ROSTER_ICONS.has(id)
	)


static func _draw_roster(
	ci: CanvasItem, id: StringName, o: Vector2, h: float, w: float, c: Color
) -> bool:
	match id:
		&"spell_blizzard":  # a hexagon and three slanting streaks
			ci.draw_polyline(_ring(o, h * 0.85, 6, 0.0), c, w * 0.8, true)
			for k in 3:
				var p := o + Vector2(-h * 0.35 + k * h * 0.35, -h * 0.35)
				ci.draw_line(p, p + Vector2(-h * 0.2, h * 0.6), c, w * 0.7, true)
		&"spell_ice_lances":  # three shards flying up and right
			for k in 3:
				var a := o + Vector2(-h * 0.8, h * 0.2 + (k - 1) * h * 0.45)
				var b := a + Vector2(h * 1.4, -h * 0.7)
				ci.draw_line(a, b, c, w * 0.8, true)
				ci.draw_colored_polygon(_tip(b, (b - a).normalized(), h * 0.22), c)
		&"spell_burning_ground":  # three flame tongues on the ground line
			ci.draw_line(o + Vector2(-h, h * 0.7), o + Vector2(h, h * 0.7), c, w, true)
			for k in 3:
				var x := (k - 1) * h * 0.6
				var hh := h * (1.2 if k == 1 else 0.85)
				ci.draw_colored_polygon(
					PackedVector2Array(
						[
							o + Vector2(x - h * 0.22, h * 0.7),
							o + Vector2(x, h * 0.7 - hh),
							o + Vector2(x + h * 0.22, h * 0.7)
						]
					),
					c
				)
		&"spell_meteor":  # a rock and its trail falling
			ci.draw_colored_polygon(_ring(o + Vector2(h * 0.3, h * 0.3), h * 0.42, 7, 0.3), c)
			for k in 3:
				var p := o + Vector2(h * 0.05 + k * h * 0.2, h * 0.05 - k * h * 0.2)
				ci.draw_line(p, p + Vector2(-h * 0.7, -h * 0.7), c, w * 0.6, true)
		&"spell_ball_lightning":  # a ball with a crackle around it
			ci.draw_colored_polygon(_ring(o, h * 0.4, 12, 0.0), c)
			ci.draw_polyline(_ring(o, h * 0.85, 7, 0.4), c, w * 0.5, true)
		&"spell_static_field":  # a dashed ring
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a)) * h * 0.85
				var t := Vector2(-d.y, d.x).normalized() * h * 0.25
				ci.draw_line(o + d - t, o + d + t, c, w, true)
		&"spell_venom_orb":  # a falling drop over three bubbles
			ci.draw_colored_polygon(_drop(o + Vector2(0, -h * 0.2), h * 0.8), c)
			for k in 3:
				ci.draw_circle(o + Vector2((k - 1) * h * 0.5, h * 0.75), h * 0.13, c)
		&"spell_toxic_cloud":  # three puffs
			for k in 3:
				ci.draw_circle(
					o + Vector2((k - 1) * h * 0.45, (k % 2) * -h * 0.25), h * 0.38, Color(c, 0.85)
				)
		&"spell_spitter_vine":  # a curling stalk and its head
			var pts := PackedVector2Array(
				[o + Vector2(0, h), o + Vector2(h * 0.3, h * 0.3), o + Vector2(-h * 0.2, -h * 0.2)]
			)
			ci.draw_polyline(pts, c, w * 1.1, true)
			ci.draw_circle(o + Vector2(-h * 0.2, -h * 0.45), h * 0.3, c)
		&"spell_blood_thorns":  # six spikes in a ring
			for k in 6:
				var a := TAU * k / 6.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(_tip(o + d * h * 0.95, d, h * 0.45), c)
		&"spell_hemorrhage":  # a diamond mark over a drop
			ci.draw_polyline(_ring(o + Vector2(0, -h * 0.45), h * 0.38, 4, 0.0), c, w * 0.8, true)
			ci.draw_colored_polygon(_drop(o + Vector2(0, h * 0.3), h * 0.55), c)
		&"spell_leech":  # a drop and an arrow up (the heal)
			ci.draw_colored_polygon(_drop(o + Vector2(-h * 0.3, h * 0.1), h * 0.7), c)
			ci.draw_line(o + Vector2(h * 0.5, h * 0.7), o + Vector2(h * 0.5, -h * 0.5), c, w, true)
			ci.draw_colored_polygon(_tip(o + Vector2(h * 0.5, -h * 0.8), Vector2.UP, h * 0.3), c)
		_:
			return false
	return true


## `n` points round `o` at radius `r` (closed: the first repeated).
static func _ring(o: Vector2, r: float, n: int, turn: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := turn + TAU * k / n
		pts.append(o + Vector2(cos(a), sin(a)) * r)
	return pts


## A small triangle pointing along `d` with its tip at `tip`.
static func _tip(tip: Vector2, d: Vector2, s: float) -> PackedVector2Array:
	var side := Vector2(-d.y, d.x) * s * 0.5
	return PackedVector2Array([tip, tip - d * s + side, tip - d * s - side])


static func _diamond(ci: CanvasItem, o: Vector2, h: float, c: Color) -> void:
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
