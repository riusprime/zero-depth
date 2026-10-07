class_name HudFrame
extends PanelContainer
## A HUD group in the HudStyle look (v0.3.5 F15): LINE draws one hairline under its content, BARE draws nothing,
## SLATE a flat square translucent plate. `tint` colours the hairline (or the plate's edge) for a warning (the
## low-HP pulse turns it red). It lays its children out like any PanelContainer.

var style: HudStyle.Style
## Tints the frame (the low-HP warning turns it red); white is the style's own colour.
var tint := Color.WHITE:
	set(v):
		if v != tint:
			tint = v
			queue_redraw()


func _init(margin: Vector2 = Vector2(14, 6), s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxEmpty.new()
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	add_theme_stylebox_override("panel", box)


func _draw() -> void:
	var warned := tint != Color.WHITE
	match style:
		HudStyle.Style.LINE:
			var c := HudStyle.line(style)
			if warned:
				c = Color(tint, 0.85)
			draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), c, 1.0)
		HudStyle.Style.SLATE:
			draw_rect(Rect2(Vector2.ZERO, size), HudStyle.panel_bg(style))
			if warned:
				draw_rect(Rect2(Vector2.ZERO, size), Color(tint, 0.8), false, 1.0)
		_:
			if warned:
				draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(tint, 0.7))
