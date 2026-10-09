class_name HeatMeter
extends Control
## The Overclock heat meter (v0.3.0 PLAN L18; v0.3.5 F2, owner: "the overclock heat should be an straight bar, way
## more minimalistic"). A thin straight bar at the bottom centre of the HUD, filling left to right; no frame, no
## segments, colour carries the state:
## - the fill takes the heat colour of the current heat (cool steel, amber Hot, red-orange Overclock, white-hot);
## - two small ticks mark the Hot and Overclock thresholds and a short red cap marks the overheat end, all placed
##   from the sim's heat table (WorldReader.heat_state), never from numbers of their own;
## - crossing a threshold brightens the fill for a moment; the cap pulses once heat passes WARN_SHARE of it;
## - overheated, the whole bar pulses red while the stall lasts;
## - a small word over the bar's left end names the zone, and "VENT: DASH" shows over its middle while a dash (or
##   blink) would vent.
## Reads WorldReader.heat_state() only (EI-07); hidden when the world has no heat.
## v0.5.5 A5 (owner pick B "Ember stone"): the same straight bar, ticks and colours (HeatLooks, unchanged), set in
## a chipped stone slab with the ember line under it (HudStyle.draw_plate); the bar is inset by PAD.

const SIZE := Vector2(420, 46)
## The bar's inset from the slab's sides (px).
const PAD := 16.0
## The bar's thickness and the ticks' / cap's height (px).
const BAR_H := 7.0
const TICK_H := 11.0
const FLASH_S := 0.45
const WARN_SHARE := 0.88
const FONT_SIZE := 14

var _s := {}
var _blink := false
var _flash := 0.0
var _last_tier_tick := -2
var _last_tier := 0
var _last_overheat := -1
var _t := 0.0


func _init() -> void:
	name = "HeatMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -SIZE.x * 0.5
	offset_right = SIZE.x * 0.5
	offset_top = -SIZE.y - 22.0
	offset_bottom = -22.0
	custom_minimum_size = SIZE
	visible = false


func sync(reader: WorldReader) -> void:
	_s = reader.heat_state()
	_blink = reader.has_blink()
	visible = not _s.is_empty()
	if _s.is_empty():
		return
	var tier: int = _s["tier"]
	if _last_tier_tick != -2 and tier > _last_tier:
		if tier == HeatLooks.TIER_HOT or tier == HeatLooks.TIER_OVERCLOCK:
			_flash = FLASH_S
	_last_tier_tick = _s["tier_tick"]
	_last_tier = tier
	if int(_s["overheat_tick"]) != _last_overheat:
		if _last_overheat != -1 or int(_s["overheat_tick"]) >= 0:
			_flash = FLASH_S
		_last_overheat = _s["overheat_tick"]
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


# --- Reads (tests) ------------------------------------------------------------------------------------------
func stalled() -> bool:
	return not _s.is_empty() and int(_s["tier"]) == HeatLooks.TIER_OVERHEAT


func heat() -> float:
	return 0.0 if _s.is_empty() else float(_s["heat"])


## The word over the bar: HEAT, HOT, OVERCLOCK or OVERHEAT.
func tier_text() -> String:
	if _s.is_empty():
		return ""
	match int(_s["tier"]):
		HeatLooks.TIER_HOT:
			return tr("HUD_HEAT_HOT")
		HeatLooks.TIER_OVERCLOCK:
			return tr("HUD_HEAT_OVERCLOCK")
		HeatLooks.TIER_OVERHEAT:
			return tr("HUD_HEAT_OVERHEAT")
	return tr("HUD_HEAT")


## The VENT prompt's text, or "" while venting would not blast.
func vent_text() -> String:
	if _s.is_empty() or not _s["vent_ready"]:
		return ""
	return tr("HUD_HEAT_VENT_BLINK") if _blink else tr("HUD_HEAT_VENT")


## The marks on the bar: [heat, name] for Hot, Overclock and the overheat end.
func marks() -> Array:
	if _s.is_empty():
		return []
	return [
		[_s["hot"], tr("HUD_HEAT_HOT")],
		[_s["overclock"], tr("HUD_HEAT_OVERCLOCK")],
		[_s["max"], tr("HUD_HEAT_OVERHEAT")],
	]


func flashing() -> bool:
	return _flash > 0.0


## The filled share of the bar (0..1).
func fill() -> float:
	return 0.0 if _s.is_empty() else clampf(heat() / float(_s["max"]), 0.0, 1.0)


## The bar's rect in the meter's own pixels.
func bar_rect() -> Rect2:
	return Rect2(PAD, SIZE.y - BAR_H - 10.0, SIZE.x - PAD * 2.0, BAR_H)


## Where `h` heat points land along the bar (x, px), scaled by the sim's max heat.
func x_of(h: float) -> float:
	if _s.is_empty():
		return 0.0
	var r := bar_rect()
	return r.position.x + r.size.x * clampf(h / float(_s["max"]), 0.0, 1.0)


## The colour the fill is drawn in now: the heat colour, red while overheated.
func fill_color() -> Color:
	if _s.is_empty():
		return HeatLooks.COOL
	if stalled():
		return HeatLooks.OVERHEAT_MARK
	return HeatLooks.color(heat(), float(_s["max"]), float(_s["hot"]), float(_s["overclock"]))


# --- Drawing ------------------------------------------------------------------------------------------------
func _draw() -> void:
	if _s.is_empty():
		return
	var r := bar_rect()
	var mx := float(_s["max"])
	var h := heat()
	var pulse := HudStyle.pulse(_t * 1.5)
	if HudStyle.current == HudStyle.Style.EMBER:
		HudStyle.draw_plate(self, Rect2(Vector2.ZERO, SIZE), true)
	var track := Color(0, 0, 0, 0.6)
	if stalled():
		track = Color(HeatLooks.OVERHEAT_MARK, 0.25 + 0.25 * pulse)
	draw_rect(r, track)
	var fc := fill_color()
	if stalled():
		fc = Color(fc, 0.6 + 0.4 * pulse)
	draw_rect(Rect2(r.position, Vector2(x_of(h) - r.position.x, r.size.y)), fc)
	if _flash > 0.0:
		var k := _flash / FLASH_S
		var lit := Rect2(r.position, Vector2(x_of(h) - r.position.x, r.size.y))
		draw_rect(lit, Color(HeatLooks.WHITE_HOT, 0.6 * k))
	_tick(float(_s["hot"]), HeatLooks.HOT, h)
	_tick(float(_s["overclock"]), HeatLooks.OVERCLOCK, h)
	var near := h >= mx * WARN_SHARE or stalled()
	var cap := Color(HeatLooks.OVERHEAT_MARK, (0.45 + 0.55 * pulse) if near else 0.9)
	var mid := r.get_center().y
	draw_rect(Rect2(r.end.x - 1.0, mid - TICK_H * 0.5 - 1.0, 3.0, TICK_H + 2.0), cap)
	var top := r.position.y - TICK_H * 0.5 - 4.0
	_text(Vector2(PAD, top), tier_text(), _tier_color(), HORIZONTAL_ALIGNMENT_LEFT)
	var vent := vent_text()
	if not vent.is_empty():
		_text(
			Vector2(PAD, top), vent, Color(HeatLooks.WHITE_HOT, 0.95), HORIZONTAL_ALIGNMENT_CENTER
		)


## A threshold tick across the bar: dim until heat reaches it, then its zone's colour.
func _tick(at: float, col: Color, h: float) -> void:
	var r := bar_rect()
	var x := x_of(at)
	var c := col if h >= at else Color(col, 0.45)
	draw_rect(Rect2(x - 1.0, r.get_center().y - TICK_H * 0.5, 2.0, TICK_H), c)


func _tier_color() -> Color:
	match int(_s["tier"]):
		HeatLooks.TIER_HOT:
			return HeatLooks.HOT
		HeatLooks.TIER_OVERCLOCK:
			return HeatLooks.OVERCLOCK.lerp(HeatLooks.WHITE_HOT, 0.25)
		HeatLooks.TIER_OVERHEAT:
			return HeatLooks.OVERHEAT_MARK
	return Color(0.8, 0.84, 0.88, 0.75)


func _text(baseline: Vector2, text: String, col: Color, align: HorizontalAlignment) -> void:
	if text.is_empty():
		return
	var font := HudStyle.font(true)
	var w := SIZE.x - PAD * 2.0
	draw_string_outline(font, baseline, text, align, w, FONT_SIZE, 3, Color(0, 0, 0, 0.6))
	draw_string(font, baseline, text, align, w, FONT_SIZE, col)
