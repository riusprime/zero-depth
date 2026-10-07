class_name HudBar
extends Control
## A fill bar in the HudStyle look (v0.3.0 UI): TERMINAL a bracketed bar with scan gaps, HOLO_ECHO a translucent
## bar with tick marks, INDUSTRIAL a row of blocks. Lost fill leaves a fading echo that catches up; `warn` pulses
## the fill and its frame red (the low-HP warning, L24). It shows the fraction it is given and decides nothing.

## The damage echo catches up at this share of the bar per second.
const ECHO_RATE := 0.6
const BLOCKS := 20

var style: HudStyle.Style
var color := Color.WHITE
var warn := false
var _fraction := 1.0
var _echo := 1.0
var _t := 0.0


func _init(s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if f > _echo:
		_echo = f
	_fraction = f
	queue_redraw()


func fraction() -> float:
	return _fraction


## The colour the fill is drawn in now (tests read the warning pulse through it).
func fill_color() -> Color:
	if not warn:
		return color
	return color.lerp(HudStyle.WARN, 0.55 + 0.45 * HudStyle.pulse(_t))


func _process(delta: float) -> void:
	_t += delta
	if _echo > _fraction:
		_echo = maxf(_fraction, _echo - ECHO_RATE * delta)
		queue_redraw()
	elif warn:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var fill := fill_color()
	var frame := HudStyle.accent(style)
	if warn:
		frame = frame.lerp(HudStyle.WARN, 0.4 + 0.6 * HudStyle.pulse(_t))
	var ghost := Color(1, 1, 1, 0.45)
	match style:
		HudStyle.Style.INDUSTRIAL:
			draw_rect(Rect2(-3, -3, w + 6, h + 6), HudStyle.panel_bg(style))
			var bw := (w - (BLOCKS - 1) * 2.0) / BLOCKS
			for k in BLOCKS:
				var x := k * (bw + 2.0)
				var mid := (k + 0.5) / BLOCKS
				var c := Color(0.3, 0.31, 0.33, 0.9)
				if mid <= _fraction:
					c = fill
				elif mid <= _echo:
					c = ghost
				draw_rect(Rect2(x, 0, bw, h), c)
			draw_rect(Rect2(-3, -3, 4, h + 6), Color(frame, 0.95))
		HudStyle.Style.TERMINAL:
			draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(0, 0, w * _echo, h), ghost)
			draw_rect(Rect2(0, 0, w * _fraction, h), fill)
			for y in range(2, int(h), 3):
				draw_line(Vector2(0, y), Vector2(w * _echo, y), Color(0, 0, 0, 0.35))
			_brackets(Color(frame, 0.85))
		_:
			draw_rect(Rect2(0, 0, w, h), HudStyle.panel_bg(style))
			draw_rect(Rect2(0, 0, w * _echo, h), ghost)
			draw_rect(Rect2(0, 0, w * _fraction, h), fill)
			draw_rect(Rect2(0, 0, w * _fraction, 3), Color(1, 1, 1, 0.35))
			for k in range(1, 10):
				draw_line(
					Vector2(w * k / 10.0, h - 5), Vector2(w * k / 10.0, h), Color(0, 0, 0, 0.45)
				)
			draw_line(Vector2(0, -3), Vector2(w, -3), Color(frame, 0.8), 1.5)
			draw_rect(Rect2(-5, -3, 3, h + 3), Color(frame, 0.9))
			draw_rect(Rect2(w + 2, -3, 3, h + 3), Color(frame, 0.9))


func _brackets(c: Color) -> void:
	var n := 6.0
	var x0 := -3.0
	var y0 := -3.0
	var x1 := size.x + 3.0
	var y1 := size.y + 3.0
	draw_polyline(
		[Vector2(x0 + n, y0), Vector2(x0, y0), Vector2(x0, y1), Vector2(x0 + n, y1)], c, 1.5
	)
	draw_polyline(
		[Vector2(x1 - n, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x1 - n, y1)], c, 1.5
	)
