class_name CardMark
extends Control
## A card's small faceted mark (v0.3.5 F16): a little diamond, split into a lit and a shaded facet like the game's
## low-poly gems, in a colour that means something (the rarity on a pick card, a curse's mark). v0.8.0 MU (Ember
## stone): carved into the stone, a dark setting round it and a soft glow of its colour. It draws the colour it is
## given.

var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _init(px: float = 12.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	for k in 3:
		draw_circle(c, r * (1.9 - k * 0.3), Color(color, 0.07))
	var setting := _diamond(c, r + maxf(1.5, r * 0.18))
	draw_colored_polygon(setting, Color(EmberStone.GROOVE, 0.9))
	var d := _diamond(c, r)
	draw_colored_polygon(PackedVector2Array([d[0], d[1], d[2]]), color.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([d[0], d[2], d[3]]), color.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([d[0], d[1], c]), color.lightened(0.4))


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array(
		[c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]
	)
