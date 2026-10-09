class_name HudBar
extends Control
## A thin fill bar in the HudStyle look (v0.3.5 F15): a dark track, the fill, and a fading echo of lost fill that
## catches up; no ticks, caps or brackets. `warn` pulses the fill red (the low-HP warning, L24). It shows the
## fraction it is given and decides nothing.

## The damage echo catches up at this share of the bar per second.
const ECHO_RATE := 0.6

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
	return color.lerp(HudStyle.warn_pulse(style), 0.55 + 0.45 * HudStyle.pulse(_t))


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
	var ember := style == HudStyle.Style.EMBER
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6) if ember else Color(0, 0, 0, 0.42))
	draw_rect(Rect2(0, 0, w * _echo, h), Color(1, 1, 1, 0.3))
	draw_rect(Rect2(0, 0, w * _fraction, h), fill_color())
	if ember:  # v0.5.5 A5: a lit top edge on the fill and a dark sunk rim round the track
		draw_rect(Rect2(0, 0, w * _fraction, 1), Color(1, 1, 1, 0.22))
		draw_rect(Rect2(-1, -1, w + 2, h + 2), HudStyle.STONE_EDGE, false, 1.0)
	if style == HudStyle.Style.SLATE:
		draw_rect(Rect2(0, 0, w, h), HudStyle.line(style), false, 1.0)
