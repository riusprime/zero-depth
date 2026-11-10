class_name HeroFxBudget
extends RefCounted
## The per-frame
## budget of the HERO's own effects, so a stacked build's noise never drowns what the enemies are about to do.
## - A cap per frame on the hero's sprites in the effects layer (VfxCore), by Effects density. The callers draw the
##   newest effects first, so past SOFT of the cap the oldest draw dimmed (OVER_ALPHA) and smaller (OVER_SCALE), and
##   past the cap they are skipped. The forms' own meshes and particles (AttackFormCanvas) dim the same way in the
##   last part of their caps. The live bolts that get a rim and trail: LIVE_BOLTS, by density.
## - A global opacity on the hero's effects: when more than DIM_FROM hostile threats (telegraphs, enemy shots) are on
##   screen it drops gently (DIM_PER_S a second) toward DIM_ALPHA, reached at DIM_FULL, so the threats win the contrast;
##   it comes back the same way when they are gone.
## Enemy telegraphs, hostile projectiles and boss attacks are never in this budget: they draw through their own views
## and drawers (VfxCore.drawers), never culled or dimmed by it.
## Presentation only (EI-07): it reads counts the views already hold and decides nothing; its clock is the sim's tick
## (settle() once a tick), so it pauses with the game. Starting values, all of them.

## The hero's effects-layer sprites a frame, by Effects density (ViewPrefs.effects_density). The heavy probe (60
## enemies, eleven cards: O12_EFFECT_BUDGET.md) drew 115 at its p95 and 166 at most before the budget.
const SPRITES := {"low": 60, "medium": 110, "high": 160}
## The hero's live bolts that keep their element rim and trail a frame, by Effects density (the rest fly as darts).
const LIVE_BOLTS := {"low": 32, "medium": 64, "high": 96}
## Past this share of a cap, a piece draws at OVER_ALPHA and OVER_SCALE (the oldest: callers draw newest first).
const SOFT := 0.75
const OVER_ALPHA := 0.55
const OVER_SCALE := 0.8
## Hostile threats on screen before the hero's effects start to dim, and at which they reach DIM_ALPHA. A telegraph
## (an enemy winding up or acting) is one threat; SHOTS_PER_THREAT enemy shots on screen are one more.
const SHOTS_PER_THREAT := 4
const DIM_FROM := 4
const DIM_FULL := 12
const DIM_ALPHA := 0.6
## How far the opacity moves a second (toward its target), so it never pops.
const DIM_PER_S := 1.5
const TICK_S := 1.0 / 60.0

## This frame's cap and soft limit (begin()), the hero sprites drawn, the drawn ones dimmed, the skipped ones.
var cap: int = SPRITES["high"]
var soft: int = int(SPRITES["high"] * SOFT)
var used := 0
var dimmed := 0
var skipped := 0
## The hero effects' opacity now (settle()) and the threats it last saw.
var alpha := 1.0
var threats := 0


## The cap at `density` (unknown: High's).
static func sprites_for(density: String) -> int:
	return int(SPRITES.get(density, SPRITES["high"]))


static func live_bolts_for(density: String) -> int:
	return int(LIVE_BOLTS.get(density, LIVE_BOLTS["high"]))


## The opacity the hero's effects head for with `n` hostile threats on screen.
static func target_alpha(n: int) -> float:
	if n <= DIM_FROM:
		return 1.0
	var u := clampf(float(n - DIM_FROM) / float(DIM_FULL - DIM_FROM), 0.0, 1.0)
	return lerpf(1.0, DIM_ALPHA, u)


## The threats on screen: `telegraphs` (TelegraphViews.threats) plus one for every SHOTS_PER_THREAT enemy shots
## on screen (it stops counting at DIM_FULL: past it the target no longer changes).
static func threats_of(telegraphs: int, reader: WorldReader, cull: ScreenCull) -> int:
	var shots := 0
	for i in reader.projectile_count():
		if telegraphs + floori(float(shots) / SHOTS_PER_THREAT) >= DIM_FULL:
			break
		if reader.projectile_team(i) != WorldReader.TEAM_ENEMY:
			continue
		if cull != null and not cull.shows(SimPlane.to_3d(reader.projectile_pos(i)), 0.5):
			continue
		shots += 1
	return telegraphs + floori(float(shots) / SHOTS_PER_THREAT)


## Starts a frame at Effects density `density`.
func begin(density: String) -> void:
	cap = sprites_for(density)
	soft = int(cap * SOFT)
	used = 0
	dimmed = 0
	skipped = 0


## One hero piece asks to draw: 0.0 when it is skipped, else the factor on its alpha (the global opacity, times
## OVER_ALPHA past the soft limit). over() then says whether it is one of the dimmed ones.
func admit() -> float:
	if used >= cap:
		skipped += 1
		return 0.0
	used += 1
	if used > soft:
		dimmed += 1
		return alpha * OVER_ALPHA
	return alpha


## Whether the last admitted piece was past the soft limit (it also draws at OVER_SCALE).
func over() -> bool:
	return used > soft


## `c` at the hero effects' opacity, and dimmed past a soft limit when `over` (the forms' meshes and particles).
func tint(c: Color, over: bool) -> Color:
	var k := alpha * (OVER_ALPHA if over else 1.0)
	if k < 1.0:
		c.a *= k
	return c


## Once a tick: `n` hostile threats on screen move the opacity toward its target, `dt` seconds' worth.
func settle(n: int, dt: float = TICK_S) -> void:
	threats = n
	alpha = move_toward(alpha, target_alpha(n), DIM_PER_S * dt)
