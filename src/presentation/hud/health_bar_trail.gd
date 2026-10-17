class_name HealthBarTrail
extends RefCounted
## v0.8.0 N4 (owner O56, O57): the shared model of a health bar's motion, used by the hero's HUD bar, every boss bar
## and the bars over enemies (and the hero's own over-head bar). It is fed the sim's fraction (set_target, once per
## tick or frame) and run in frame time (advance); it decides nothing (EI-07: the sim's HP is the outcome, this only
## shows it).
## - The damage chunk: when the fraction drops, the fill drops at once and a light layer behind it keeps what was
##   lost. It holds for HOLD_S, counted from the burst's FIRST hit (later hits in the burst add to the chunk and never
##   restart the hold, so a boss hit all the time still drains), then drains to the fill. A hit while it drains raises
##   the drain's speed so the chunk catches up within DRAIN_S of that hit: the chunk always moves. A burst ends once
##   the chunk has reached the fill and no hit came for QUIET_S; until then a new hit drains at once (no new hold), so
##   steady fire never pauses the chunk. A hit of BIG_HIT of the bar or more (a huge crit) lights it brighter for BIG_S.
## - Heals and refills: when the fraction rises the fill grows to it over REFILL_S instead of jumping (a hit while it
##   grows takes the fill down at once if it lands below what is shown).
## - Reduced motion (HudStyle.reduced_motion): no hold, the drain and the refill take CALM_S (near-instant).
## Starting values (owner direction: "waits a moment, and then it drains").

## The chunk's hold from the burst's first hit (s).
const HOLD_S := 0.5
## The chunk's drain to the fill (s).
const DRAIN_S := 0.4
## A heal or refill grows the fill over this (s).
const REFILL_S := 0.8
## Reduced motion: the drain and the refill (s).
const CALM_S := 0.05
## A burst ends after this long without a hit (once the chunk caught up); the next hit then holds again (s).
const QUIET_S := 0.5
## A single drop of this share of the bar or more is a big hit: its chunk lights brighter.
const BIG_HIT := 0.08
const BIG_S := 0.35
const EPS := 0.0005

## The sim's fraction (0..1), what the bar is going to.
var target := 1.0
## The fill shown now.
var fill := 1.0
## The chunk's edge (>= fill): the light layer spans fill..chunk.
var chunk := 1.0
## Seconds of the hold left (0 while draining or idle).
var hold := 0.0
## Seconds of the big hit's light left.
var big := 0.0
var _burst := false
var _quiet := 0.0
var _drain_rate := 0.0
var _refill_rate := 0.0


## Shows `f` at once (a new boss, the rise the sim itself animates, a bar first seen): no chunk, no refill.
func snap(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	target = f
	fill = f
	chunk = f
	hold = 0.0
	big = 0.0
	_burst = false
	_quiet = 0.0
	_drain_rate = 0.0
	_refill_rate = 0.0


## The sim's fraction now.
func set_target(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if f < target - EPS:
		_hit(f)
	elif f > target + EPS and f > fill:
		_refill_rate = maxf(_refill_rate, (f - fill) / _refill_s())
	target = f


func _hit(f: float) -> void:
	if target - f >= BIG_HIT:
		big = BIG_S
	if f < fill:
		chunk = maxf(chunk, fill)
		fill = f
		_refill_rate = 0.0
	if chunk <= fill + EPS:
		return  # the hit landed inside a refill still growing: nothing lost from what is shown
	_quiet = 0.0
	if not _burst:  # the burst's first hit: the hold starts, and only here
		_burst = true
		hold = _hold_s()
		_drain_rate = 0.0 if hold > 0.0 else (chunk - fill) / _drain_s()
	elif hold <= 0.0:  # mid-drain: faster, never restarted
		_drain_rate = maxf(_drain_rate, (chunk - fill) / _drain_s())


## Runs the bar `delta` seconds of frame time; true while something still moves.
func advance(delta: float) -> bool:
	if fill < target:
		fill = minf(target, fill + maxf(_refill_rate, EPS) * delta)
		if fill >= target:
			_refill_rate = 0.0
	elif fill > target:
		fill = target
	chunk = maxf(chunk, fill)
	big = maxf(0.0, big - delta)
	if _burst:
		var left := delta
		if hold > 0.0:
			hold -= delta
			left = maxf(0.0, -hold)
			if hold <= 0.0:
				hold = 0.0
				_drain_rate = (chunk - fill) / _drain_s()
		if hold <= 0.0:
			chunk = maxf(fill, chunk - _drain_rate * left)
			_quiet += delta
			if chunk <= fill + EPS:
				chunk = fill
				if _quiet >= _quiet_s():  # caught up and no hit for a while: the next hit is a new burst
					_burst = false
					_drain_rate = 0.0
	elif chunk > fill:
		chunk = fill
	return moving()


## Something still moves: a chunk shows, or the fill still grows.
func moving() -> bool:
	return _burst or fill < target - EPS or big > 0.0


## The chunk's share of the bar (0 when none shows).
func chunk_size() -> float:
	return maxf(0.0, chunk - fill)


func holding() -> bool:
	return _burst and hold > 0.0


func draining() -> bool:
	return _burst and hold <= 0.0


func refilling() -> bool:
	return fill < target - EPS


func _hold_s() -> float:
	return 0.0 if HudStyle.reduced_motion else HOLD_S


func _quiet_s() -> float:
	return 0.0 if HudStyle.reduced_motion else QUIET_S


func _drain_s() -> float:
	return CALM_S if HudStyle.reduced_motion else DRAIN_S


func _refill_s() -> float:
	return CALM_S if HudStyle.reduced_motion else REFILL_S
