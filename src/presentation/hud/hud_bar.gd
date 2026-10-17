class_name HudBar
extends Control
## A thin fill bar in the HudStyle look (v0.3.5 F15): a dark track, the fill, and behind it the damage chunk; no
## ticks, caps or brackets. `warn` pulses the fill red (the low-HP warning, L24). It shows the fraction it is given
## and decides nothing.
## v0.8.0 N4 (owner O56): the chunk and the fill move by the shared HealthBarTrail: the chunk holds from the burst's
## first hit, then drains; a heal grows the fill instead of jumping. The boss bar uses one too (BossBar).

## The chunk's light layer (brighter while a big hit's light lasts).
const CHUNK := Color(1, 0.97, 0.9, 0.42)
const CHUNK_BIG := Color(1, 1, 0.92, 0.78)

var style: HudStyle.Style
var color := Color.WHITE
var warn := false
var trail := HealthBarTrail.new()
var _t := 0.0


func _init(s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The sim's fraction; `snap` shows it at once (no chunk, no refill).
func set_fraction(f: float, snap: bool = false) -> void:
	if snap:
		trail.snap(f)
	else:
		trail.set_target(f)
	queue_redraw()


## The sim's fraction (what the bar shows once it settles).
func fraction() -> float:
	return trail.target


## The fill drawn now (0..1; a refill grows it).
func shown_fraction() -> float:
	return trail.fill


## The chunk's share of the bar drawn now (0 when none shows).
func chunk_fraction() -> float:
	return trail.chunk_size()


## The colour the fill is drawn in now (tests read the warning pulse through it).
func fill_color() -> Color:
	if not warn:
		return color
	return color.lerp(HudStyle.warn_pulse(style), 0.55 + 0.45 * HudStyle.pulse(_t))


func chunk_color() -> Color:
	return CHUNK_BIG if trail.big > 0.0 else CHUNK


func _process(delta: float) -> void:
	_t += delta
	if trail.moving():
		trail.advance(delta)
		queue_redraw()
	elif warn:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ember := style == HudStyle.Style.EMBER
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6) if ember else Color(0, 0, 0, 0.42))
	if trail.chunk_size() > 0.0:
		draw_rect(Rect2(w * trail.fill, 0, w * trail.chunk_size(), h), chunk_color())
	draw_rect(Rect2(0, 0, w * trail.fill, h), fill_color())
	if ember:  # v0.5.5 A5: a lit top edge on the fill and a dark sunk rim round the track
		draw_rect(Rect2(0, 0, w * trail.fill, 1), Color(1, 1, 1, 0.22))
		draw_rect(Rect2(-1, -1, w + 2, h + 2), HudStyle.STONE_EDGE, false, 1.0)
	if style == HudStyle.Style.SLATE:
		draw_rect(Rect2(0, 0, w, h), HudStyle.line(style), false, 1.0)
