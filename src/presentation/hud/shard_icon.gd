class_name ShardIcon
extends Control
## The shard symbol (v0.3.0 E): a faceted violet crystal drawn with CanvasItem calls, no external art.

const LIGHT := Color("#D9C6FF")
const MID := Color("#B48CFF")
const DARK := Color("#6B4BC4")


func _init(side: float = 24.0) -> void:
	custom_minimum_size = Vector2(side * 0.8, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Vector2(w * 0.5, 0)
	var bottom := Vector2(w * 0.5, h)
	var left := Vector2(0, h * 0.4)
	var right := Vector2(w, h * 0.4)
	var mid := Vector2(w * 0.5, h * 0.48)
	draw_colored_polygon(PackedVector2Array([top, left, mid]), LIGHT)
	draw_colored_polygon(PackedVector2Array([top, mid, right]), MID)
	draw_colored_polygon(PackedVector2Array([left, bottom, mid]), MID)
	draw_colored_polygon(PackedVector2Array([mid, bottom, right]), DARK)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0, 0, 0, 0.6), 1.5)
