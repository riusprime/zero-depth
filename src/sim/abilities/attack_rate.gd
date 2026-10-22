class_name AttackRate
extends RefCounted
## v0.8.0 SG (owner O91: "Make attack-speed bonuses additive before a configurable diminishing-return curve. Include
## ordinary speed modifiers in that calculation so they cannot bypass it. Start with diminished gains above +50%"):
## the one attack-speed rule. An attack's raw bonus, per mille, is the attack speed stat's sum (its cards add) plus
## that attack's wand rate bonus (Rapid Fire, Flurry, Heavy ...: AttackSpec.rate_bonus_permille). curve() turns it
## into the effective bonus:
## - up to the knee (SimTuning.attack_speed_knee_permille, +50 %) it counts in full;
## - from the knee to knee2 (+150 %) at slope (50 %); above knee2 at slope2 (25 %);
## - a negative raw bonus counts in full.
## The rate is 1000 + the effective bonus (never under 1), then Heavy Hands' cut (Curses.attack_speed). The Gun's
## period, the Blade's whole swing and the retired drone's period all read it, and so do the cards' forecast
## (CardForecast), the HUD (WorldReader) and the hidden catch-up (CatchUp.power): one function, EI-07. Integer
## maths only.

## The shipped curve (SimTuning's defaults; data/tuning/sim.tres sets them for the dev panel).
const KNEE := 500
const KNEE2 := 1500
const SLOPE := 500
const SLOPE2 := 250
## A Gun shot's period never falls under this many ticks.
const MIN_SHOT_TICKS := 2


## The effective bonus for raw bonus `raw`, per mille, under tuning `t` (see the class comment).
static func curve(t: SimTuning, raw: int) -> int:
	var knee := t.attack_speed_knee_permille
	if raw <= knee:
		return raw
	var knee2 := maxi(knee, t.attack_speed_knee2_permille)
	if raw <= knee2:
		return knee + _part(raw - knee, t.attack_speed_slope_permille)
	return (
		knee
		+ _part(knee2 - knee, t.attack_speed_slope_permille)
		+ _part(raw - knee2, t.attack_speed_slope2_permille)
	)


static func _part(span: int, slope: int) -> int:
	return (span * slope + 500) / 1000


## The attack-speed stat's raw bonus now, per mille (its value − 1000).
static func stat_bonus(w: World) -> int:
	return Stats.value(w, Stats.Stat.ATTACK_SPEED) - 1000


## The rate, per mille, of an attack with wand bonus `wand` and the stat at its value now.
static func rate(w: World, wand: int) -> int:
	return rate_at(w, Stats.value(w, Stats.Stat.ATTACK_SPEED), wand)


## rate() with the attack-speed stat at raw value `stat_v` (CardForecast's after-card number).
static func rate_at(w: World, stat_v: int, wand: int) -> int:
	var r := maxi(1, 1000 + curve(w.tuning, stat_v - 1000 + wand))
	return Curses.attack_speed(w, r)  # v0.6.0 CU: Heavy Hands multiplies the rate


## v0.9.0 LZ (owner Q8: "attack speed raises the tick rate at half its value"; Q9 the same for the Bomb): rate `r` of
## an attack whose form counts attack speed at a share (AttackSpec.rate_scale_permille; 0 = whole): its bonus over (or
## under) 1000 times that share, rounded down, at least 1.
static func form_rate(spec: AttackSpec, r: int) -> int:
	if spec == null or spec.rate_scale_permille <= 0 or r == 1000:
		return r
	return maxi(1, 1000 + (r - 1000) * spec.rate_scale_permille / 1000)


## `ticks` at rate `r` per mille: ticks × 1000 / r, rounded half up.
static func scaled(ticks: int, r: int) -> int:
	return (ticks * 1000 + r / 2) / maxi(1, r)


## The weapon attack's wand rate bonus now: the Gun bolt's, else the Blade's first step's (0 without a spec).
static func weapon_bonus(w: World) -> int:
	if PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w):
		var b := Modifiers.bolt(w)
		return b.rate_bonus_permille if b != null else 0
	if w.player.combo.is_empty():
		return 0
	var s := Modifiers.step(w, 0)
	return s.rate_bonus_permille if s != null else 0


## The weapon attack's rate now (the stat, its wand bonus, the curve, Heavy Hands).
static func weapon_rate(w: World) -> int:
	return rate(w, weapon_bonus(w))
