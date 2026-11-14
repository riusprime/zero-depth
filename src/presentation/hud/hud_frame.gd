class_name HudFrame
extends PanelContainer
## A HUD group. The HUD is unboxed (HudStyle, v0.10.5 W3-O17), so the frame draws nothing: it pads its
## content by `margin` and lays its children out like any PanelContainer.


func _init(margin: Vector2 = Vector2(14, 6)) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxEmpty.new()
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	add_theme_stylebox_override("panel", box)
