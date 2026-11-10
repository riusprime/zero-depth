class_name DangerMeter
extends Control
## The danger meter (PLAN v0.3.0 L23: "something visual instead of numbers"). v0.10.5 O6 (owner P4, 2026-11-01: "modify
## the triangles at the top to be a line filling up as a danger hazard texture, small kinda shaped like hp but green to
## red blinking when full"; G2 overnight pick, docs/roadmap/v0.10.5/evidence/O6_DANGER_BAR.md): the ember teeth are
## gone. A thin bar fills along the floor's danger curve, full at FULL_TIER (the overtime reaches it at the 10-minute
## mark), in green → yellow → red as it fills. Full, it blinks slowly (reduced motion: steady red). A tier rise still
## brightens it for a moment, and from NUMBER_TIER the tier number stays beside it. It shows what
## WorldReader says (tier, tier_progress) and decides nothing.
## UI style Astral; owner: "and what about the rest of the UI? it should match the new style": the
## round-2 mock's danger line: a slim ink bed in a hairline frame, a fill 3 px line in the ramp (Astral's muted tones:
## sage, pale gold, rose-red), a tick under the bed for each tier, a diamond marker at the fill's end (filled and
## blinking once full) and the tier number in Cinzel.

## From this tier on the meter also shows the tier number
## ("×7"). the bar is full at FULL_TIER (data/curves/floor_N.tres: the overtime's last start, 600 s).
const NUMBER_TIER := 4
const FULL_TIER := 10
const NUMBER_W := 34.0
## The rise pulse lasts this long (s).
const PULSE_S := 0.8
## The bar's width (and its height for the layout) and the blink when full: slow, one cycle every 1 / BLINK_HZ s.
const SIZE := Vector2(190, 9)
const BLINK_HZ := 0.7
const BLINK_LOW := 0.3
## The ramp in Astral's muted tones (no saturated green, no orange): sage, pale gold, rose-red.
const GREEN := Color("#8CC9A6")
const YELLOW := Color("#E2CB8E")
const RED := HudStyle.A_WARN
## The tier number's size (Cinzel).
const A_NUMBER_SIZE := 16

var bar_size := SIZE
## Whether the tier number is drawn from NUMBER_TIER (the mockups turn it off for a variant).
var show_number := true
var _tier := 0
var _progress := 0.0
var _pulse := 0.0
var _seen := false
var _clock := 0.0


func _init() -> void:
	name = "DangerMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resize_to(SIZE)


## Sets the bar's size (and the room for the number to its right).
func resize_to(bar: Vector2) -> void:
	bar_size = bar
	custom_minimum_size = Vector2(bar.x + (NUMBER_W if show_number else 0.0), maxf(bar.y, 14.0))
	queue_redraw()


## 0..1: how full the bar is at this tier and progress (tier + progress over FULL_TIER).
static func fill_of(tier: int, progress: float) -> float:
	return clampf((maxi(0, tier) + clampf(progress, 0.0, 1.0)) / FULL_TIER, 0.0, 1.0)


static func is_full(tier: int) -> bool:
	return tier >= FULL_TIER


## Green at empty, yellow halfway, red at full.
static func color_at(f: float) -> Color:
	var x := clampf(f, 0.0, 1.0)
	if x <= 0.5:
		return GREEN.lerp(YELLOW, x * 2.0)
	return YELLOW.lerp(RED, (x - 0.5) * 2.0)


## Whether the tier number is drawn.
static func shows_number(tier: int) -> bool:
	return tier >= NUMBER_TIER


## The fill's brightness at `t` s while full: 1 .. BLINK_LOW, slowly; 1 always under reduced motion.
static func blink_level(t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return lerpf(BLINK_LOW, 1.0, 0.5 + 0.5 * cos(t * TAU * BLINK_HZ))


func set_danger(tier: int, progress: float) -> void:
	if _seen and tier > _tier:
		_pulse = 1.0
	_tier = maxi(0, tier)
	_progress = clampf(progress, 0.0, 1.0)
	_seen = true
	queue_redraw()


func tier_shown() -> int:
	return _tier


func fill() -> float:
	return fill_of(_tier, _progress)


func full() -> bool:
	return is_full(_tier)


## The fill's colour now (red when full).
func bar_color() -> Color:
	return color_at(fill())


## True while the full bar blinks (never under reduced motion).
func blinking() -> bool:
	return full() and not HudStyle.reduced_motion


## The fill's brightness this frame (1 unless blinking).
func level() -> float:
	return blink_level(_clock, HudStyle.reduced_motion) if full() else 1.0


func pulsing() -> bool:
	return _pulse > 0.0


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_S)
		queue_redraw()
	if full():
		_clock += delta
		queue_redraw()
	else:
		_clock = 0.0


func _draw() -> void:
	var p := 0.0 if HudStyle.reduced_motion else _pulse
	var top := floorf((size.y - 14.0) * 0.5) if size.y > 14.0 else 0.0
	draw_astral(self, Rect2(0, top, bar_size.x, 14.0), fill(), level(), p, FULL_TIER)
	if show_number and shows_number(_tier):
		var num_col := bar_color()
		if p > 0.0:
			num_col = num_col.lerp(Color.WHITE, 0.5 * p)
		var text := tr("HUD_DANGER_TIER") % _tier
		var base := Vector2(bar_size.x + 8.0, top + 13.0)
		AstralHudParts.serif_text(
			self, text, base, A_NUMBER_SIZE, num_col, HORIZONTAL_ALIGNMENT_LEFT, NUMBER_W, 0, 700
		)


## The danger line on `c` in `r` (14 px tall): the slim bed in its hairline frame with end ticks,
## a tick under it per tier (`tiers`; the passed ones lit), the fill a 3 px line in the ramp's colour at brightness
## `lit` to `f`, and the diamond marker at its end, filled once full (it blinks with `lit`). `p` is the rise pulse.
static func draw_astral(
	c: CanvasItem, r: Rect2, f: float, lit: float, p: float = 0.0, tiers := FULL_TIER
) -> void:
	var x0 := roundf(r.position.x) + 4.0
	var x1 := roundf(r.end.x) - 4.0
	var y := roundf(r.position.y) + 4.0
	var bed := Rect2(x0, y, x1 - x0, 5)
	AstralHudParts.slim_bed(c, bed, 0.4)
	var metal := HudStyle.A_METAL
	AstralChrome.vline(c, x0 - 2, y - 3, y + 8, Color(metal, 0.6))
	AstralChrome.vline(c, x1 + 1, y - 3, y + 8, Color(metal, 0.6))
	var fx := roundf(x0 + (x1 - x0) * clampf(f, 0.0, 1.0))
	for k in range(1, tiers):
		var tx := roundf(x0 + (x1 - x0) * float(k) / tiers)
		AstralChrome.vline(c, tx, y + 6, y + 9, Color(metal, 0.7 if tx <= fx else 0.28))
	var col := color_at(f)
	if p > 0.0:
		col = col.lerp(Color.WHITE, 0.5 * p)
	col = Color(col.r * lit, col.g * lit, col.b * lit, 1.0)
	if fx > x0 + 1.0:
		c.draw_rect(Rect2(x0 + 1, y + 1, fx - x0 - 1, 3), col)
	var full := f >= 1.0
	var mk := Vector2(fx + 0.5, y + 2.5)
	AstralChrome.dia(
		c, mk, 4.5, HudStyle.A_LINE_HI if not full else col, col if full else HudStyle.A_INK
	)
