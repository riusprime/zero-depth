class_name BlastLook
extends RefCounted
## v0.10.5 W3-S4 (owner F8, 2026-11-04: "Chain Blast explosions are disproportionately large relative to their actual
## damage. With Seekers and Split, 5-6 explosions per second can make combat almost impossible to see. Large
## explosions feel appropriate for slower, heavier attacks."): how big and bright a hook's blast is drawn (a BURST cast
## that AttackFormView draws from the sim's wand casts: Chain Blast, Explosive, Fire's kill burst), and which are drawn.
## - Weight (0..1): the blast's damage (the largest area hit the player dealt on its tick near it; none landed: its
##   trigger hit's at TRIGGER_SHARE) against REF_S seconds of the hero's direct damage over the last WINDOW_TICKS. A
##   fast build's light blasts are small pops, a slow heavy hit's the full blast, and the run's damage growth cancels
##   out. A blast of weight w is drawn at radius MIN_R..1 of the sim's and its light at w (VfxLayer.burst).
## - Budget, per second of sim ticks: at most FULL_PER_S blasts at their weight; past that, one within MERGE_M of a
##   blast drawn in the last MERGE_TICKS merges into it (not drawn) and the rest are small pops (weight 0); past
##   MAX_PER_S none. Both scale with the Effects density (DENSITY), never below one.
## Presentation only (EI-07): it reads the sim's DAMAGE events and cast marks, timed in sim ticks; the sim's blast
## (its radius and damage) is unchanged. Starting values.

const WINDOW_TICKS := 60
const REF_S := 0.25
const FULL_AT := 1.0
const TRIGGER_SHARE := 0.6
const NEAR_M := 0.6
const TRIGGER_M := 1.5
const MIN_REF := 1.0
const MIN_R := 0.35
const FULL_PER_S := 3
const MAX_PER_S := 8
const MERGE_M := 1.6
const MERGE_TICKS := 10
const KEEP_MAX := 512
const DENSITY := {"low": 0.34, "medium": 0.67, "high": 1.0}
## admit()'s answers.
const NONE := 0
const POP := 1
const FULL := 2

## Counts since the view began (tests and the probe).
var drawn := 0
var pops := 0
var merged := 0
var skipped := 0

var _direct: Array = []  # [tick, amount, pos]: the player's direct hits (not area, not DoT)
var _area: Array = []  # [tick, amount, pos]: the player's area hits
var _drawn: Array = []  # [tick, pos, full]
var _last := -1


## One DAMAGE event the player dealt to an enemy at `tick` (a DoT tick is left out by the caller).
func note(tick: int, amount: int, pos: Vector2, area: bool) -> void:
	_restart_if(tick)
	var to: Array = _area if area else _direct
	to.append([tick, amount, pos])
	if to.size() > KEEP_MAX:
		to.pop_front()
	_prune(_last)


## The weight (0..1) of a blast at `pos` (sim radius `radius`) cast at `tick`.
func weight(tick: int, pos: Vector2, radius: float) -> float:
	var dmg := 0.0
	for a: Array in _area:
		if int(a[0]) == tick and pos.distance_to(a[2]) <= radius + NEAR_M:
			dmg = maxf(dmg, float(a[1]))
	var sum := 0.0
	for d: Array in _direct:
		if tick - int(d[0]) < WINDOW_TICKS:
			sum += float(d[1])
		if dmg <= 0.0 and int(d[0]) == tick and pos.distance_to(d[2]) <= TRIGGER_M:
			dmg = maxf(dmg, float(d[1]) * TRIGGER_SHARE)
	var ref := maxf(sum * REF_S * 60.0 / float(WINDOW_TICKS), MIN_REF)
	return clampf(dmg / (ref * FULL_AT), 0.0, 1.0)


## Whether a blast at `pos` cast at `tick` is drawn at the Effects density `density`: FULL (at its weight), POP (a
## small one) or NONE (merged into one drawn near it, or past the second's budget). Counted.
func admit(tick: int, pos: Vector2, density: String) -> int:
	_restart_if(tick)
	_prune(_last)
	var k: float = DENSITY.get(density, 1.0)
	var full_cap := maxi(1, roundi(FULL_PER_S * k))
	var max_cap := maxi(1, roundi(MAX_PER_S * k))
	var out := FULL
	if _drawn.size() >= max_cap:
		out = NONE
		skipped += 1
	else:
		var full_n := 0
		for d: Array in _drawn:
			if bool(d[2]):
				full_n += 1
		if full_n >= full_cap:
			out = POP
			for d: Array in _drawn:
				if tick - int(d[0]) <= MERGE_TICKS and pos.distance_to(d[1]) < MERGE_M:
					out = NONE
					merged += 1
					break
	if out == NONE:
		return NONE
	_drawn.append([tick, pos, out == FULL])
	drawn += 1
	if out == POP:
		pops += 1
	return out


## The radius factor (MIN_R..1) a blast of weight `w` is drawn at.
static func radius_k(w: float) -> float:
	return lerpf(MIN_R, 1.0, clampf(w, 0.0, 1.0))


func clear() -> void:
	_direct.clear()
	_area.clear()
	_drawn.clear()
	_last = -1


func _restart_if(tick: int) -> void:
	if tick < _last - WINDOW_TICKS:  # a new floor's world: its ticks start again (a sync's ticks may come a little late)
		clear()
	_last = maxi(_last, tick)


func _prune(tick: int) -> void:
	while not _direct.is_empty() and tick - int(_direct[0][0]) >= WINDOW_TICKS:
		_direct.pop_front()
	while not _area.is_empty() and tick - int(_area[0][0]) >= WINDOW_TICKS:
		_area.pop_front()
	while not _drawn.is_empty() and tick - int(_drawn[0][0]) >= WINDOW_TICKS:
		_drawn.pop_front()
