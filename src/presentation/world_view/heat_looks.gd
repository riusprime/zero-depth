class_name HeatLooks
extends RefCounted
## Overclock heat's colours (v0.3.0 L18), shared by the HUD meter, the hero's visor and blade, and the vent and
## steam effects: cool steel, amber when Hot, red-orange at Overclock, white-hot at the overheat point.

## WorldReader.heat_state()["tier"] values (Heat.TIER_*; a test pins them equal).
const TIER_COOL := 0
const TIER_HOT := 1
const TIER_OVERCLOCK := 2
const TIER_OVERHEAT := 3

const COOL := Color("#4E6A80")
const HOT := Color("#FFA63A")
const OVERCLOCK := Color("#FF4A1A")
const WHITE_HOT := Color("#FFF4DE")
const OVERHEAT_MARK := Color("#FF2A2A")
const STEAM := Color("#E6EEF2")


## The heat colour at `heat` points of `mx`, with the Hot and Overclock thresholds `hot` and `oc`.
static func color(heat: float, mx: float, hot: float, oc: float) -> Color:
	if heat <= hot:
		return COOL.lerp(HOT, clampf(heat / maxf(hot, 1.0), 0.0, 1.0) * 0.85)
	if heat <= oc:
		return HOT.lerp(OVERCLOCK, (heat - hot) / maxf(oc - hot, 1.0))
	return OVERCLOCK.lerp(WHITE_HOT, clampf((heat - oc) / maxf(mx - oc, 1.0), 0.0, 1.0))


## How far the hero's visor and blade lean from their own colour toward the heat colour: none until Hot, then up
## to all of it at the overheat point.
static func tint_amount(heat: float, mx: float, hot: float) -> float:
	if heat < hot:
		return 0.0
	return clampf(0.45 + 0.55 * (heat - hot) / maxf(mx - hot, 1.0), 0.0, 1.0)


## The colour and tint amount for a WorldReader.heat_state() ({} gives [COOL, 0.0]).
static func from_state(s: Dictionary) -> Array:
	if s.is_empty():
		return [COOL, 0.0]
	var h: float = s["heat"]
	var mx := float(s["max"])
	var hot := float(s["hot"])
	if int(s["tier"]) == TIER_OVERHEAT:
		return [WHITE_HOT.lerp(STEAM, 0.4), 0.8]
	return [color(h, mx, hot, float(s["overclock"])), tint_amount(h, mx, hot)]
