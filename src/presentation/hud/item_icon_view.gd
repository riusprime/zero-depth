class_name ItemIconView
extends Control
## One item's symbol (ItemIcons) as a Control, optionally on a small dark rounded tile.

var item_id := &""
var color := Color.WHITE
var tile := false
## Shapes drawn the last time this redrew (tests read it).
var drawn := 0


func _init(p_id: StringName = &"", p_color: Color = Color.WHITE, p_tile := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_item(p_id, p_color)
	tile = p_tile


func set_item(id: StringName, c: Color) -> void:
	item_id = id
	color = c
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if tile:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.04, 0.07, 0.72)
		box.set_corner_radius_all(0)  # v0.3.5 F16: square, like the cards
		box.border_color = Color(color, 0.85)
		box.border_width_bottom = 2
		draw_style_box(box, r)
		r = r.grow(-size.x * 0.16)
	drawn = ItemIcons.draw(self, item_id, r, color)
