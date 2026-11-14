class_name HudBar
extends Control
## A thin fill bar in the HudStyle look (one continuous fill in a hairline frame,
## AstralHudParts.bar), and behind it the damage chunk. `warn` pulses the fill toward the warning (the low-HP warning,
## L24). It shows the fraction it is given and decides nothing.
## The chunk and the fill move by the shared HealthBarTrail: the chunk holds from the burst's
## first hit, then drains; a heal grows the fill instead of jumping. The boss bar uses one too (BossBar).

## The chunk (the damage just taken; brighter while a big hit's light lasts): silver-white leaning rose,
## apart from the moon-blue fill.
const A_CHUNK := Color("#E2ACC4", 0.42)
const A_CHUNK_BIG := Color("#E3C2DA", 0.8)

var color := Color.WHITE:
	set(v):
		if v != color:
			color = v
			queue_redraw()
var warn := false:
	set(v):
		if v != warn:
			warn = v
			queue_redraw()
## A small star past the bar's end.
var end_star := true
var trail := HealthBarTrail.new()
var _t := 0.0
var _drawn_fill := Color.TRANSPARENT


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The sim's fraction; `snap` shows it at once (no chunk, no refill). Redraws only when what the bar draws changed:
## each tick sets the same fraction most of the time.
func set_fraction(f: float, snap: bool = false) -> void:
	var was := [trail.fill, trail.chunk_size(), trail.big > 0.0]
	if snap:
		trail.snap(f)
	else:
		trail.set_target(f)
	if trail.moving() or [trail.fill, trail.chunk_size(), trail.big > 0.0] != was:
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
	return color.lerp(HudStyle.warn_pulse(), 0.55 + 0.45 * HudStyle.pulse(_t))


func chunk_color() -> Color:
	return A_CHUNK_BIG if trail.big > 0.0 else A_CHUNK


func _process(delta: float) -> void:
	_t += delta
	if trail.moving():
		trail.advance(delta)
		queue_redraw()
	elif warn and fill_color() != _drawn_fill:  # the pulse (steady under reduced motion)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# One continuous fill in a hairline frame (AstralHudParts)
	var f0 := w * trail.fill
	_drawn_fill = fill_color()
	AstralHudParts.bar(
		self,
		Rect2(0, 0, w, h),
		f0,
		fill_color(),
		f0,
		f0 + w * trail.chunk_size(),
		chunk_color(),
		end_star
	)
