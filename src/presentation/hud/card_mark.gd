class_name CardMark
extends Control
## A card's small faceted mark (v0.3.5 F16): a little diamond, split into a lit and a shaded facet like the game's
## low-poly gems, in a colour that means something (the rarity on a pick card). It draws the colour it is given.

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
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r * 0.8, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r * 0.8, 0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([top, bottom, left]), color.lightened(0.15))
