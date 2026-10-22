class_name SlotGlyph
extends Control
## v0.9.0 AS (owner Q5: "reads 'Replaces <card>' with its slot icon"; Q14): a wand slot category's small mark, drawn in
## code beside the slot tag: Form a full orb (the shot), Pattern three dots in a fan (copies), Secondary a diamond (what
## rides on the shot), Element a drop. Presentation only (EI-07).

var slot := WorldReader.SLOT_NONE:
	set(v):
		slot = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _init(px: float = 14.0) -> void:
	name = "SlotGlyph"
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	match slot:
		WorldReader.SLOT_FORM:
			draw_circle(c, r * 0.8, color)
		WorldReader.SLOT_PATTERN:  # three copies in a fan: the middle one ahead
			for p: Vector2 in [Vector2(-0.62, 0.25), Vector2(0.0, -0.3), Vector2(0.62, 0.25)]:
				draw_circle(c + p * r, r * 0.3, color)
		WorldReader.SLOT_SECONDARY:
			var pts := PackedVector2Array(
				[
					c + Vector2(0, -r * 0.85),
					c + Vector2(r * 0.7, 0),
					c + Vector2(0, r * 0.85),
					c + Vector2(-r * 0.7, 0),
					c + Vector2(0, -r * 0.85)
				]
			)
			draw_polyline(pts, color, maxf(1.5, r * 0.22), true)
		WorldReader.SLOT_ELEMENT:
			draw_circle(c + Vector2(0, r * 0.25), r * 0.55, color)
			draw_colored_polygon(
				PackedVector2Array(
					[
						c + Vector2(0, -r * 0.9),
						c + Vector2(r * 0.5, r * 0.05),
						c + Vector2(-r * 0.5, r * 0.05)
					]
				),
				color
			)
