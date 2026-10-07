class_name DangerMeter
extends Control
## The danger meter (PLAN v0.3.0 L23: "something visual instead of numbers"). No digits: a row of CHEVRONS shows
## the tier (one lit per tier reached, from tier 1), and a bar of SEGMENTS under it fills toward the next tier
## (one 30 s tier per bar, the spawn director's tier_ticks). Colours run cool to hot as the tier rises; when the
## tier goes up the chevrons flash and a ring of echo pulses out. Past the last chevron it reads "overdrive": every
## chevron lit hot and flickering. It shows what WorldReader says (tier, tier_progress) and decides nothing.

const CHEVRONS := 6
const SEGMENTS := 10
## The rise pulse lasts this long (s).
const PULSE_S := 0.8
const SIZE := Vector2(196, 30)

var style: HudStyle.Style
var _tier := 0
var _progress := 0.0
var _pulse := 0.0
var _t := 0.0
var _seen := false


func _init(s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	name = "DangerMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE


## Chevrons lit at this tier (0-based, as WorldReader.tier).
static func lit_chevrons(tier: int) -> int:
	return clampi(tier + 1, 1, CHEVRONS)


## Bar segments lit at this progress (0..1) toward the next tier.
static func lit_segments(progress: float) -> int:
	return clampi(floori(progress * SEGMENTS), 0, SEGMENTS)


## 0 (tier 1, cool) .. 1 (the last chevron, hot).
static func heat(tier: int) -> float:
	return clampf(float(tier) / (CHEVRONS - 1), 0.0, 1.0)


static func overdrive(tier: int) -> bool:
	return tier >= CHEVRONS


func set_danger(tier: int, progress: float) -> void:
	if _seen and tier > _tier:
		_pulse = 1.0
	_seen = true
	_tier = maxi(0, tier)
	_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


func tier_shown() -> int:
	return _tier


func chevrons_lit() -> int:
	return lit_chevrons(_tier)


func segments_lit() -> int:
	return lit_segments(_progress)


func pulsing() -> bool:
	return _pulse > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_S)
	queue_redraw()


func _draw() -> void:
	var calm := HudStyle.reduced_motion
	var p := 0.0 if calm else _pulse
	var hot := HudStyle.danger_color(heat(_tier))
	var lit := lit_chevrons(_tier)
	var over := overdrive(_tier)
	var cw := 24.0
	var gap := (SIZE.x - CHEVRONS * cw) / (CHEVRONS - 1)
	var ch := 16.0
	if p > 0.0:
		var grow := (1.0 - p) * 10.0
		draw_rect(
			Rect2(-grow, -grow, SIZE.x + grow * 2, ch + grow * 2), Color(hot, 0.5 * p), false, 2.0
		)
	for k in CHEVRONS:
		var x := k * (cw + gap)
		var on := k < lit
		var c := HudStyle.danger_color(heat(k)) if on else HudStyle.dim(style)
		if over and not calm:
			c = HudStyle.WARN.lerp(Color.WHITE, 0.35 * float(int(_t * 8.0) % 2))
		if on and p > 0.0:
			c = c.lerp(Color.WHITE, 0.6 * p)
		_chevron(Rect2(x, 0, cw, ch), c, on)
	var y := ch + 6.0
	var sh := SIZE.y - y
	var sw := (SIZE.x - (SEGMENTS - 1) * 3.0) / SEGMENTS
	var full := lit_segments(_progress)
	var part := _progress * SEGMENTS - full
	for k in SEGMENTS:
		var r := Rect2(k * (sw + 3.0), y, sw, sh)
		draw_rect(r, Color(0, 0, 0, 0.45))
		if k < full:
			draw_rect(r, hot)
		elif k == full:
			draw_rect(Rect2(r.position, Vector2(sw * part, sh)), Color(hot, 0.55))


func _chevron(r: Rect2, c: Color, on: bool) -> void:
	var a := r.position
	var w := r.size.x
	var h := r.size.y
	var t := w * 0.42
	match style:
		HudStyle.Style.INDUSTRIAL:
			var plate := PackedVector2Array(
				[a + Vector2(4, 0), a + Vector2(w, 0), a + Vector2(w - 4, h), a + Vector2(0, h)]
			)
			if on:
				draw_colored_polygon(plate, c)
			else:
				var edge := plate.duplicate()
				edge.append(plate[0])
				draw_polyline(edge, c, 1.5)
		_:
			var pts := PackedVector2Array(
				[
					a,
					a + Vector2(w - t, 0),
					a + Vector2(w, h * 0.5),
					a + Vector2(w - t, h),
					a + Vector2(0, h),
					a + Vector2(t, h * 0.5),
				]
			)
			if on and style == HudStyle.Style.HOLO_ECHO:
				var echo := PackedVector2Array()
				for q in pts:
					echo.append(q + Vector2(4, 0))
				draw_colored_polygon(echo, Color(c, 0.3))
			if on and style != HudStyle.Style.TERMINAL:
				draw_colored_polygon(pts, c)
			else:
				var edge := pts.duplicate()
				edge.append(pts[0])
				draw_polyline(edge, c, 2.0 if on else 1.2)
				if on:
					draw_colored_polygon(pts, Color(c, 0.35))
