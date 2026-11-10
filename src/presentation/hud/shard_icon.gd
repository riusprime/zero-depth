class_name ShardIcon
extends Control
## The shard symbol: a faceted violet crystal drawn with CanvasItem calls, no external art.
## `astral` draws Astral's shard instead (the shop and the altar pick): a thin outlined crystal in
## `tint` (Astral's accent, or its too-poor rose) with a lit top facet, like the reference's wallet mark.

const LIGHT := Color("#D9C6FF")
const MID := Color("#B48CFF")
const DARK := Color("#6B4BC4")

var astral := false
var tint := Color("#B5BDF0"):
	set(v):
		tint = v
		queue_redraw()


func _init(side: float = 24.0, p_astral: bool = false) -> void:
	astral = p_astral
	custom_minimum_size = Vector2(roundf(side * (0.62 if astral else 0.8)), side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if astral:
		_draw_astral()
		return
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


## Astral's shard: a tall crystal outline, its top facet lit, its facet lines fainter.
func _draw_astral() -> void:
	var w := size.x
	var h := size.y
	var cx := roundf(w * 0.5) + 0.5
	var top := Vector2(cx, 1.0)
	var bot := Vector2(cx, h - 1.0)
	var l := Vector2(1.0, roundf(h * 0.4) + 0.5)
	var r := Vector2(w - 1.0, roundf(h * 0.4) + 0.5)
	var mid := Vector2(cx, roundf(h * 0.48) + 0.5)
	draw_colored_polygon(PackedVector2Array([top, r, mid, l]), Color(tint, 0.35))
	draw_colored_polygon(PackedVector2Array([l, mid, bot]), Color(tint, 0.1))
	draw_polyline(PackedVector2Array([top, r, bot, l, top]), tint, 1.3, true)
	draw_line(l, mid, Color(tint, 0.7), 1.0, true)
	draw_line(r, mid, Color(tint, 0.7), 1.0, true)
	draw_line(mid, bot, Color(tint, 0.45), 1.0, true)
