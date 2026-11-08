class_name LaserWeight
extends RefCounted
## v0.10.5 W3-O8 (owner F14, 2026-11-04: the Laser "doesn't feel as powerful or impactful as other attack forms"):
## what gives the Laser's beam its weight, as numbers LaserView reads:
## - core + glow: the ribbon is GLOW_WIDTH times the look's width; the look's strip draws in its middle 1 / GLOW_WIDTH
##   (the core, as before) and a soft halo in the look's edge and deep colours fills the rest (glow(), by density);
## - a slight width pulse (PULSE, over PULSE_TICKS) and a start flash (the first FLASH_TICKS of a firing: the muzzle
##   and the impact star FLASH_GROW bigger, the beam FLASH_WIDEN wider, fading out);
## Starting values, all of them. Its sprites draw through the hero's budget (VfxCore.hero_budget, O12).
## Presentation only (EI-07): the clock is the sim's tick the view last read; nothing here decides an outcome.

const GLOW_WIDTH := 2.4
const GLOW := {"low": 0.25, "medium": 0.45, "high": 0.55}
const PULSE := 0.1
const PULSE_TICKS := 10.0
const FLASH_TICKS := 9.0
const FLASH_GROW := 1.3
const FLASH_WIDEN := 0.6
## The impact star this much bigger than the look's (the hit reads at the end of the beam).
const IMPACT_MUL := 1.3
## v0.11.0 O1 (owner Q7: "instant, drawn fast (~0.15 s), glow fading ~0.5 s"): the lance, hit whole on its firing
## tick, draws out from the hero over DRAW_TICKS and its glow fades out by the end of WorldReader.LANCE_GLOW_TICKS.
## A minimal look: the final one waits for the owner's sketch (PLAN X2).
const DRAW_TICKS := 9.0
const LANCE_ENERGY := 1.7


## The halo's strength by Effects density (unknown: medium).
static func glow(density: String) -> float:
	return float(GLOW.get(density, GLOW["medium"]))


## v0.11.0 O1: the share of the lance drawn `age` ticks after its shot (0 to 1 over DRAW_TICKS, eased out).
static func lance_drawn(age: float) -> float:
	var u := clampf(age / DRAW_TICKS, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## v0.11.0 O1: the lance's glow `age` ticks after its shot, of `glow_ticks` in all: 1 while it draws, then down to 0.
static func lance_fade(age: float, glow_ticks: float) -> float:
	if age <= DRAW_TICKS:
		return 1.0
	var u := clampf((age - DRAW_TICKS) / maxf(1.0, glow_ticks - DRAW_TICKS), 0.0, 1.0)
	return (1.0 - u) * (1.0 - u)


## The start flash at `age` ticks since the beam began firing: 1 at once, 0 from FLASH_TICKS (eased out).
static func flash(age: float) -> float:
	if age < 0.0 or age >= FLASH_TICKS:
		return 0.0
	var u := 1.0 - age / FLASH_TICKS
	return u * u


## The beam's width factor at `tick` with the start flash `f`: the pulse (1 +- PULSE) and the flash's widening.
static func width_mul(tick: float, f: float) -> float:
	return 1.0 + PULSE * sin(TAU * tick / PULSE_TICKS) + FLASH_WIDEN * f
