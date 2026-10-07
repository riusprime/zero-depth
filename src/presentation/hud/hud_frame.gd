class_name HudFrame
extends PanelContainer
## A HUD plate in the HudStyle look (v0.3.0 UI): TERMINAL draws a dark box with corner brackets and scanlines,
## HOLO_ECHO a translucent cyan panel with a bright top edge, end caps and faint scan rows, INDUSTRIAL a
## chamfered gunmetal plate with a hazard strip and bolts. It lays its children out like any PanelContainer.

const CUT := 9.0

var style: HudStyle.Style
## Tints the frame's accent (the low-HP warning turns it red).
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
	var r := Rect2(Vector2.ZERO, size)
	var a := HudStyle.accent(style) * tint
	var bg := HudStyle.panel_bg(style)
	match style:
		HudStyle.Style.TERMINAL:
			draw_rect(r, bg)
			for y in range(1, int(size.y), 3):
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.05))
			_brackets(r, Color(a, 0.9), 10.0)
		HudStyle.Style.INDUSTRIAL:
			var p := _chamfer(r, CUT)
			draw_colored_polygon(p, bg)
			var edge := p.duplicate()
			edge.append(p[0])
			draw_polyline(edge, Color(0.45, 0.47, 0.5, 0.9), 1.5)
			draw_rect(Rect2(CUT * 0.4, CUT, 4, size.y - CUT * 2), Color(a, 0.95))
			for x in [size.x - 10.0, size.x - 20.0]:
				draw_circle(Vector2(x, size.y - 7), 1.8, Color(0.6, 0.62, 0.65, 0.9))
		_:
			draw_rect(r, bg)
			for y in range(3, int(size.y), 4):
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(a, 0.04))
			draw_line(Vector2(0, 1), Vector2(size.x, 1), Color(a, 0.9), 2.0)
			draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(a, 0.35), 1.0)
			var h := size.y * 0.5
			draw_rect(Rect2(0, 0, 3, h), Color(a, 0.9))
			draw_rect(Rect2(size.x - 3, 0, 3, h), Color(a, 0.9))
			for x in range(12, int(size.x) - 8, 14):
				draw_line(Vector2(x, size.y - 1), Vector2(x, size.y - 4), Color(a, 0.3))


func _brackets(r: Rect2, c: Color, n: float) -> void:
	var w := 2.0
	var tl := r.position
	var br := r.end
	draw_polyline([tl + Vector2(0, n), tl, tl + Vector2(n, 0)], c, w)
	draw_polyline([Vector2(br.x - n, tl.y), Vector2(br.x, tl.y), Vector2(br.x, tl.y + n)], c, w)
	draw_polyline([Vector2(tl.x, br.y - n), Vector2(tl.x, br.y), Vector2(tl.x + n, br.y)], c, w)
	draw_polyline([Vector2(br.x - n, br.y), br, Vector2(br.x, br.y - n)], c, w)


## A rectangle with its top-left and bottom-right corners cut.
static func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var e := r.end
	return PackedVector2Array(
		[
			Vector2(r.position.x + cut, r.position.y),
			Vector2(e.x, r.position.y),
			Vector2(e.x, e.y - cut),
			Vector2(e.x - cut, e.y),
			Vector2(r.position.x, e.y),
			Vector2(r.position.x, r.position.y + cut),
		]
	)
