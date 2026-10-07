class_name HeatMeter
extends Control
## The Overclock heat meter (v0.3.0 PLAN L18; owner: "overclock heat should show a combo meter that shows you the
## overheat point"). A segmented arc at the bottom centre of the HUD, filling left to right:
## - each segment takes its zone's colour (cool steel, amber Hot, red-orange Overclock, white-hot at the end) and
##   the filled part glows wider and brighter as heat rises;
## - the Hot and Overclock thresholds are notches with their names; the overheat point is a red bar and arrow at
##   the arc's end, named, pulsing once heat passes WARN_SHARE of it;
## - crossing a threshold flashes the arc; "VENT: DASH" pulses above it while a dash (or blink) would vent;
## - overheating flashes red and vents steam from the arc while the stall lasts.
## Reads WorldReader.heat_state() only (EI-07); hidden when the world has no heat.

const SIZE := Vector2(520, 170)
const SEGMENTS := 25
const RADIUS := 215.0
const WIDTH := 18.0
const SPAN := deg_to_rad(124.0)
const GAP := deg_to_rad(1.3)
const FLASH_S := 0.45
const WARN_SHARE := 0.88
## Steam puffs per second while stalled, and in the burst when the overheat starts.
const STEAM_RATE := 36.0
const STEAM_BURST := 24
const FONT_SIZE := 17

var _s := {}
var _blink := false
var _flash := 0.0
var _flash_color := Color.WHITE
var _last_tier_tick := -2
var _last_tier := 0
var _last_overheat := -1
var _t := 0.0
var _steam_acc := 0.0
## Steam puffs: [pos, vel, life left, life, radius].
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "HeatMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -SIZE.x * 0.5
	offset_right = SIZE.x * 0.5
	offset_top = -SIZE.y - 6.0
	offset_bottom = -6.0
	custom_minimum_size = SIZE
	_rng.seed = 18
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
			_flash_color = HeatLooks.WHITE_HOT
	_last_tier_tick = _s["tier_tick"]
	_last_tier = tier
	if int(_s["overheat_tick"]) != _last_overheat:
		if _last_overheat != -1 or int(_s["overheat_tick"]) >= 0:
			_flash = FLASH_S
			_flash_color = HeatLooks.OVERHEAT_MARK
			for k in STEAM_BURST:
				_puff()
		_last_overheat = _s["overheat_tick"]
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if stalled():
		_steam_acc += delta * STEAM_RATE
		while _steam_acc >= 1.0:
			_steam_acc -= 1.0
			_puff()
	for k in range(_puffs.size() - 1, -1, -1):
		var p: Array = _puffs[k]
		p[2] -= delta
		if p[2] <= 0.0:
			_puffs.remove_at(k)
			continue
		p[0] += p[1] * delta
		p[1] *= 0.97
	queue_redraw()


# --- Reads (tests) ------------------------------------------------------------------------------------------
func stalled() -> bool:
	return not _s.is_empty() and int(_s["tier"]) == HeatLooks.TIER_OVERHEAT


func heat() -> float:
	return 0.0 if _s.is_empty() else float(_s["heat"])


## The word under the arc: HEAT, HOT, OVERCLOCK or OVERHEAT.
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


## The marks drawn on the arc: [heat, text] for Hot, Overclock and the overheat point.
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


func steam_count() -> int:
	return _puffs.size()


## The filled share of the arc (0..1).
func fill() -> float:
	return 0.0 if _s.is_empty() else clampf(heat() / float(_s["max"]), 0.0, 1.0)


# --- Drawing ------------------------------------------------------------------------------------------------
func _centre() -> Vector2:
	return Vector2(SIZE.x * 0.5, RADIUS + 34.0)


func _angle(h: float) -> float:
	return -PI * 0.5 - SPAN * 0.5 + SPAN * clampf(h / float(_s["max"]), 0.0, 1.0)


func _on_arc(h: float, r: float) -> Vector2:
	var a := _angle(h)
	return _centre() + Vector2(cos(a), sin(a)) * r


func _draw() -> void:
	if _s.is_empty():
		return
	var c := _centre()
	var mx := float(_s["max"])
	var h := heat()
	var hot := float(_s["hot"])
	var oc := float(_s["overclock"])
	var a0 := _angle(0.0)
	var a1 := _angle(mx)
	draw_arc(c, RADIUS, a0 - GAP, a1 + GAP, 72, Color(0, 0, 0, 0.6), WIDTH + 10.0, true)
	var seg := SPAN / SEGMENTS
	for k in SEGMENTS:
		var lo := mx * k / SEGMENTS
		var hi := mx * (k + 1) / SEGMENTS
		var col := HeatLooks.color((lo + hi) * 0.5, mx, hot, oc)
		var sa := a0 + seg * k + GAP * 0.5
		var ea := sa + seg - GAP
		draw_arc(c, RADIUS, sa, ea, 6, Color(col.darkened(0.72), 0.9), WIDTH, true)
		var f := clampf((h - lo) / (hi - lo), 0.0, 1.0)
		if f <= 0.0:
			continue
		var fe := sa + (ea - sa) * f
		draw_arc(c, RADIUS, sa, fe, 6, Color(col, 0.18 + 0.32 * h / mx), WIDTH * 2.4, true)
		draw_arc(c, RADIUS, sa, fe, 6, col, WIDTH, true)
	_mark(hot, HeatLooks.HOT, tr("HUD_HEAT_HOT"), 1.0)
	_mark(oc, HeatLooks.OVERCLOCK, tr("HUD_HEAT_OVERCLOCK"), 1.0)
	_overheat_mark(mx, h)
	if _flash > 0.0:
		var k := _flash / FLASH_S
		draw_arc(
			c, RADIUS, a0, a1, 72, Color(_flash_color, 0.55 * k), WIDTH * (1.4 + 1.6 * k), true
		)
	_text(c + Vector2(0, -RADIUS + 50.0), tier_text(), _tier_color(), 24)
	var vent := vent_text()
	if not vent.is_empty():
		var pulse := 0.65 + 0.35 * sin(_t * 9.0)
		_text(c + Vector2(0, -RADIUS - 52.0), vent, Color(HeatLooks.WHITE_HOT, pulse), 24)
	for p: Array in _puffs:
		var k: float = p[2] / p[3]
		draw_circle(
			p[0], p[4] * (1.6 - 0.6 * k), Color(HeatLooks.STEAM, 0.55 * k), true, -1.0, true
		)


func _tier_color() -> Color:
	match int(_s["tier"]):
		HeatLooks.TIER_HOT:
			return HeatLooks.HOT
		HeatLooks.TIER_OVERCLOCK:
			return HeatLooks.OVERCLOCK.lerp(HeatLooks.WHITE_HOT, 0.25)
		HeatLooks.TIER_OVERHEAT:
			return Color(HeatLooks.OVERHEAT_MARK, 0.6 + 0.4 * absf(sin(_t * 10.0)))
	return Color(0.75, 0.8, 0.85, 0.8)


## A threshold notch across the arc, its name outside it.
func _mark(at: float, col: Color, text: String, alpha: float) -> void:
	var inner := _on_arc(at, RADIUS - WIDTH * 0.9)
	var outer := _on_arc(at, RADIUS + WIDTH * 1.1)
	draw_line(inner, outer, Color(0, 0, 0, 0.8), 6.0, true)
	draw_line(inner, outer, Color(col, alpha), 3.0, true)
	_text(_on_arc(at, RADIUS + WIDTH + 14.0), text, Color(col, alpha), FONT_SIZE)


## The overheat point: a red bar and an arrow at the arc's end, named, pulsing near it.
func _overheat_mark(mx: float, h: float) -> void:
	var near := h >= mx * WARN_SHARE or stalled()
	var pulse := 0.5 + 0.5 * absf(sin(_t * 11.0)) if near else 1.0
	var col := Color(HeatLooks.OVERHEAT_MARK, pulse)
	var inner := _on_arc(mx, RADIUS - WIDTH * 1.2)
	var outer := _on_arc(mx, RADIUS + WIDTH * 1.4)
	draw_line(inner, outer, Color(0, 0, 0, 0.85), 10.0, true)
	draw_line(inner, outer, col, 6.0, true)
	var tip := _on_arc(mx, RADIUS + WIDTH * 1.5)
	var dir := (tip - _centre()).normalized()
	var side := dir.orthogonal() * 9.0
	var back := tip + dir * 14.0
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), col)
	var at := _on_arc(mx, RADIUS + WIDTH + 34.0)
	_text(at + Vector2(10, 0), tr("HUD_HEAT_OVERHEAT"), col, FONT_SIZE + 1)


func _text(at: Vector2, text: String, col: Color, size_px: int) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var w := 240.0
	var pos := at + Vector2(-w * 0.5, size_px * 0.35)
	draw_string_outline(
		font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size_px, 5, Color(0, 0, 0, 0.85 * col.a)
	)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size_px, col)


func _puff() -> void:
	var h := _rng.randf_range(0.0, float(_s.get("max", 100)))
	var at := _on_arc(h, RADIUS + _rng.randf_range(-WIDTH, WIDTH))
	var vel := Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-90.0, -40.0))
	var life := _rng.randf_range(0.5, 1.0)
	_puffs.append([at, vel, life, life, _rng.randf_range(5.0, 11.0)])
