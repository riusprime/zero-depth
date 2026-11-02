class_name DangerMeter
extends Control
## The danger meter (PLAN v0.3.0 L23: "something visual instead of numbers"). v0.10.5 O6 (owner P4, 2026-11-01: "modify
## the triangles at the top to be a line filling up as a danger hazard texture, small kinda shaped like hp but green to
## red blinking when full"; G2 overnight pick, docs/roadmap/v0.10.5/evidence/O6_DANGER_BAR.md): the ember teeth are
## gone. A thin bar shaped like the HP bar (dark track, lit top edge, stone rim) fills along the floor's danger curve,
## full at FULL_TIER (the overtime reaches it at the 10-minute mark), drawn with a diagonal hazard-stripe texture made
## here (no asset) in green → yellow → red as it fills. Full, it blinks slowly (reduced motion: steady red). A tier rise
## still brightens it for a moment, and from NUMBER_TIER the tier number stays beside it (v0.9.5 DC). It shows what
## WorldReader says (tier, tier_progress) and decides nothing.

## v0.9.5 DC (owner: "aim to a 10 minutes max per floor"): from this tier on the meter also shows the tier number
## ("×7"). v0.10.5 O6: the bar is full at FULL_TIER (data/curves/floor_N.tres: the overtime's last start, 600 s).
const NUMBER_TIER := 4
const FULL_TIER := 10
const NUMBER_W := 34.0
const NUMBER_SIZE := 13
## The rise pulse lasts this long (s).
const PULSE_S := 0.8
## The bar (the HP bar's look, thinner) and the blink when full: slow, one cycle every 1 / BLINK_HZ s.
const SIZE := Vector2(190, 9)
const BLINK_HZ := 0.7
const BLINK_LOW := 0.3
## The hazard stripes: a period of STRIPE px at 45°, the dark band at STRIPE_DARK of the colour.
const STRIPE := 10
const STRIPE_DARK := 0.45
const GREEN := Color("#4CD964")
const YELLOW := Color("#F5D020")
const RED := HudStyle.WARN

static var _stripes: ImageTexture

var style: HudStyle.Style
var bar_size := SIZE
## Whether the tier number is drawn from NUMBER_TIER (the mockups turn it off for a variant).
var show_number := true
var _tier := 0
var _progress := 0.0
var _pulse := 0.0
var _seen := false
var _clock := 0.0


func _init(s: HudStyle.Style = HudStyle.current) -> void:
	style = s
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


## v0.9.5 DC: whether the tier number is drawn.
static func shows_number(tier: int) -> bool:
	return tier >= NUMBER_TIER


## The fill's brightness at `t` s while full: 1 .. BLINK_LOW, slowly; 1 always under reduced motion.
static func blink_level(t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return lerpf(BLINK_LOW, 1.0, 0.5 + 0.5 * cos(t * TAU * BLINK_HZ))


## The hazard-stripe tile (white and STRIPE_DARK grey diagonal bands, tinted by the fill colour), made once.
static func stripes() -> ImageTexture:
	if _stripes == null:
		var img := Image.create(STRIPE, STRIPE, false, Image.FORMAT_RGBA8)
		for y in STRIPE:
			for x in STRIPE:
				var v := 1.0 if (x + y) % STRIPE < STRIPE / 2 else STRIPE_DARK
				img.set_pixel(x, y, Color(v, v, v, 1.0))
		_stripes = ImageTexture.create_from_image(img)
	return _stripes


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
	var h := bar_size.y
	var top := floorf((size.y - h) * 0.5) if size.y > h else 0.0
	draw_bar(self, Rect2(0, top, bar_size.x, h), fill(), level(), p)
	if show_number and shows_number(_tier):
		var num_col := bar_color()
		if p > 0.0:
			num_col = num_col.lerp(Color.WHITE, 0.5 * p)
		var text := tr("HUD_DANGER_TIER") % _tier
		var font := HudStyle.font(true)
		var at := Vector2(bar_size.x + 6.0, top + h * 0.5 + 5.0)
		draw_string_outline(
			font, at, text, HORIZONTAL_ALIGNMENT_LEFT, NUMBER_W, NUMBER_SIZE, 3, Color(0, 0, 0, 0.6)
		)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, NUMBER_W, NUMBER_SIZE, num_col)


## The bar on `c` in `r`: the HP bar's dark track and stone rim, the striped fill to `f` (0..1) in its colour at
## brightness `lit`, its lit top edge, and the rise pulse `p` (0..1) toward white. The G2 mockups draw it too.
static func draw_bar(c: CanvasItem, r: Rect2, f: float, lit: float, p: float = 0.0) -> void:
	if c.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:  # the stripes tile
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.draw_rect(r, Color(0, 0, 0, 0.6))
	var fw := roundf(r.size.x * clampf(f, 0.0, 1.0))
	if fw > 0.0:
		var col := color_at(f)
		if p > 0.0:
			col = col.lerp(Color.WHITE, 0.5 * p)
		col = Color(col.r * lit, col.g * lit, col.b * lit, 1.0)
		c.draw_texture_rect(stripes(), Rect2(r.position, Vector2(fw, r.size.y)), true, col)
		c.draw_rect(Rect2(r.position, Vector2(fw, 1)), Color(1, 1, 1, 0.22 * lit))
	c.draw_rect(r.grow(1.0), HudStyle.STONE_EDGE, false, 1.0)
