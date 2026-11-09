class_name GambleIconView
extends Control
## One gamble stat's symbol (GambleIcons) as a Control, on a small dark rounded tile with a stat-coloured rim.

var stat_id := &""
var tile := true
## v0.11.0 F13: the failed use's symbol (a cracked, dimmed gem) instead of a stat's icon.
var broken := false
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


func set_broken(on: bool) -> void:
	broken = on
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if broken:
		_draw_broken(r)
		return
	var c := GambleIcons.color(stat_id)
	if tile and HudStyle.current == HudStyle.Style.ASTRAL:  # v0.10.5 W3-O20: Astral's tile
		HudStyle.draw_astral_tile(self, r, c)
		r = r.grow(-size.x * 0.17)
	elif tile:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.04, 0.07, 0.8)
		box.set_corner_radius_all(0)  # v0.3.5 F16: square, like the cards
		box.border_color = Color(c, 0.9)
		box.set_border_width_all(2)
		draw_style_box(box, r)
		r = r.grow(-size.x * 0.17)
	drawn = GambleIcons.draw(self, stat_id, r, HudStyle.tone(c)) if stat_id != &"" else 0


## v0.11.0 F13: a grey tile with a dim gem split by a red crack, its two halves slipped apart.
func _draw_broken(r: Rect2) -> void:
	var grey := Color(0.55, 0.57, 0.62)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.07, 0.8)
	box.border_color = Color(grey, 0.7)
	box.set_border_width_all(2)
	draw_style_box(box, r)
	var q := r.grow(-size.x * 0.17)
	var o := q.position
	var sd := minf(q.size.x, q.size.y)
	var left := PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.1, 0.38), Vector2(0.5, 0.94)])
	var right := PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.9, 0.38), Vector2(0.5, 0.94)])
	for i in left.size():
		left[i] = o + (left[i] + Vector2(-0.04, 0.0)) * sd
		right[i] = o + (right[i] + Vector2(0.04, 0.03)) * sd
	draw_colored_polygon(left, Color(grey, 0.55))
	draw_colored_polygon(right, Color(grey, 0.4))
	var crack := PackedVector2Array(
		[
			Vector2(0.5, 0.0),
			Vector2(0.42, 0.3),
			Vector2(0.58, 0.5),
			Vector2(0.46, 0.72),
			Vector2(0.5, 1.0)
		]
	)
	for i in crack.size():
		crack[i] = o + crack[i] * sd
	draw_polyline(crack, Color("#FF5A4D"), maxf(2.0, sd * 0.07), true)
	drawn = 3
