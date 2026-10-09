class_name DangerMeter
extends Control
## The danger meter (PLAN v0.3.0 L23: "something visual instead of numbers"; v0.3.5 F15: calmer). No digits: a row
## of short MARKS shows the tier (one lit per tier reached, from tier 1), and a thin line under them fills toward
## the next tier (one 30 s tier per line, the spawn director's tier_ticks; SEGMENTS is how finely it is read).
## Colours run cool to hot as the tier rises; when the tier goes up the lit marks brighten for a moment. Past the
## last mark it reads "overdrive": every mark lit red. It shows what WorldReader says (tier, tier_progress) and
## decides nothing.
## v0.5.5 A5 (Ember stone): in HudStyle.EMBER the marks are small ember teeth (triangles), as in the B mockup.

## The tier marks (named chevrons in v0.3.0; the API keeps the name).
const CHEVRONS := 6
const SEGMENTS := 10
## The rise pulse lasts this long (s).
const PULSE_S := 0.8
const SIZE := Vector2(132, 14)
const MARK := Vector2(16, 4)

var style: HudStyle.Style
var _tier := 0
var _progress := 0.0
var _pulse := 0.0
var _seen := false


func _init(s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	name = "DangerMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE


## Marks lit at this tier (0-based, as WorldReader.tier).
static func lit_chevrons(tier: int) -> int:
	return clampi(tier + 1, 1, CHEVRONS)


## Progress steps lit at this progress (0..1) toward the next tier.
static func lit_segments(progress: float) -> int:
	return clampi(floori(progress * SEGMENTS), 0, SEGMENTS)


## 0 (tier 1, cool) .. 1 (the last mark, hot).
static func heat(tier: int) -> float:
	return clampf(float(tier) / (CHEVRONS - 1), 0.0, 1.0)


static func overdrive(tier: int) -> bool:
	return tier >= CHEVRONS


func set_danger(tier: int, progress: float) -> void:
	if _seen and tier > _tier:
		_pulse = 1.0
	_tier = maxi(0, tier)
	_progress = clampf(progress, 0.0, 1.0)
	_seen = true
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
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_S)
		queue_redraw()


func _draw() -> void:
	var p := 0.0 if HudStyle.reduced_motion else _pulse
	var hot := HudStyle.danger_color(heat(_tier))
	var lit := lit_chevrons(_tier)
	var over := overdrive(_tier)
	var gap := (SIZE.x - CHEVRONS * MARK.x) / (CHEVRONS - 1)
	for k in CHEVRONS:
		var on := k < lit
		var c := HudStyle.danger_color(heat(k)) if on else HudStyle.dim(style)
		if over:
			c = HudStyle.WARN
		if on and p > 0.0:
			c = c.lerp(Color.WHITE, 0.5 * p)
		var x := k * (MARK.x + gap)
		if style == HudStyle.Style.EMBER:
			var tooth := PackedVector2Array(
				[Vector2(x + 1, 10), Vector2(x + MARK.x * 0.5, 0), Vector2(x + MARK.x - 1, 10)]
			)
			draw_colored_polygon(tooth, c)
		else:
			draw_rect(Rect2(x, 0, MARK.x, MARK.y), c)
	var y := SIZE.y - 2.0
	draw_rect(Rect2(0, y, SIZE.x, 2), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(0, y, SIZE.x * _progress, 2), Color(hot, 0.85))
