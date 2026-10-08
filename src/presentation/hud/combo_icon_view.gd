class_name ComboIconView
extends Control
## A named combo's symbol (v0.3.0 G): its two items' (v0.4.0 AB: or abilities') icons (ItemIcons), the first up-left
## and the second down-right on a dark disc, optionally on a tile framed in the combo's colour with a corner notch on
## each side. Used by the combo card and the HUD combo badges.

var item_a := &""
var item_b := &""
var color := Color.WHITE
var tile := false
## Shapes drawn the last time this redrew (tests read it).
var drawn := 0


func _init(
	p_a: StringName = &"", p_b: StringName = &"", p_color := Color.WHITE, p_tile := false
) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile = p_tile
	set_combo(p_a, p_b, p_color)


func set_combo(a: StringName, b: StringName, c: Color) -> void:
	item_a = a
	item_b = b
	color = c
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if tile:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.04, 0.07, 0.8)
		box.set_corner_radius_all(0)  # v0.3.5 F16: square, like the cards
		box.border_color = color
		box.set_border_width_all(2)
		draw_style_box(box, r)
		var n := size.x * 0.22
		for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
			var into := (r.get_center() - corner).sign()
			draw_colored_polygon(
				PackedVector2Array(
					[corner, corner + Vector2(into.x * n, 0), corner + Vector2(0, into.y * n)]
				),
				color
			)
		r = r.grow(-size.x * 0.1)
	var side := minf(r.size.x, r.size.y) * 0.64
	var first := Rect2(r.position, Vector2(side, side))
	var second := Rect2(r.end - Vector2(side, side), Vector2(side, side))
	drawn = ItemIcons.draw(self, item_a, first, _color(item_a))
	draw_circle(second.get_center(), side * 0.56, Color(0.03, 0.04, 0.07, 0.9))
	drawn += ItemIcons.draw(self, item_b, second.grow(-side * 0.08), _color(item_b))


## An item's colour, or (v0.4.0 AB: an ability combo) the ability's.
static func _color(id: StringName) -> Color:
	if not ItemIcons.has_icon(id) and AbilityIcons.has_icon(id):
		return AbilityIcons.color(id)
	return ItemLooks.color_of_id(id)
