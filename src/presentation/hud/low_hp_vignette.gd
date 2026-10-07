class_name LowHpVignette
extends Control
## The low-HP screen-edge warning (PLAN v0.3.0 L24): while `active`, a subtle red glow hugs the screen's edges and
## pulses with the HP bar (steady in calm mode, HudStyle.reduced_motion). Drawn as four gradient strips (no
## shader); it never takes mouse input.

## The glow reaches this share of the shorter screen side inwards (starting value).
const DEPTH := 0.16
## Edge alpha at the pulse's low and high (starting values).
const ALPHA_LOW := 0.12
const ALPHA_HIGH := 0.38

var active := false:
	set(v):
		if v != active:
			active = v
			visible = v
var _t := 0.0


func _init() -> void:
	name = "LowHpVignette"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func edge_alpha() -> float:
	return lerpf(ALPHA_LOW, ALPHA_HIGH, HudStyle.pulse(_t))


func _process(delta: float) -> void:
	if active:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var d := minf(w, h) * DEPTH
	var edge := Color(HudStyle.WARN, edge_alpha())
	var clear := Color(HudStyle.WARN, 0.0)
	var o := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	var i := [Vector2(d, d), Vector2(w - d, d), Vector2(w - d, h - d), Vector2(d, h - d)]
	for k in 4:
		var n := (k + 1) % 4
		draw_polygon(
			PackedVector2Array([o[k], o[n], i[n], i[k]]),
			PackedColorArray([edge, edge, clear, clear])
		)
