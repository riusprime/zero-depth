class_name GambleIconView
extends Control
## One gamble stat's symbol (GambleIcons) as a Control, on a small dark rounded tile with a stat-coloured rim.

var stat_id := &""
var tile := true
## Shapes drawn the last time this redrew (tests read it).
var drawn := 0


func _init(p_id: StringName = &"", side := 40.0, p_tile := true) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(side, side)
	tile = p_tile
	set_stat(p_id)


func set_stat(id: StringName) -> void:
	stat_id = id
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := GambleIcons.color(stat_id)
	if tile:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.04, 0.07, 0.8)
		box.set_corner_radius_all(0)  # v0.3.5 F16: square, like the cards
		box.border_color = Color(c, 0.9)
		box.set_border_width_all(2)
		draw_style_box(box, r)
		r = r.grow(-size.x * 0.17)
	drawn = GambleIcons.draw(self, stat_id, r) if stat_id != &"" else 0
