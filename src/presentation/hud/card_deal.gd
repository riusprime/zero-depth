class_name CardDeal
extends RefCounted
## v0.8.0 N8 (owner O62, D48): the reward cards' deal as one timeline, so the pick panel only reads it each frame
## (no tween decides anything: EI-03; the sim waits on the pick as before, this only draws it).
## - Deal: every card arrives face down from the bottom of the screen into its place in a fan, one after another
##   (STAGGER_S apart, ARRIVE_S each).
## - Flip: then one by one in flip order (order()): its width shrinks to 0, the face is swapped in halfway, and it
##   grows back (FLIP_S).
## - The rare wait: an Epic or Legendary card (high()) is left for last. Before its flip the background darkens and
##   its back glows (WAIT_S); when it flips it gets a punch (a scale pop), a flash and light rays rising behind it.
##   With several high cards (the boss's altar) the wait comes once and they flip in turn.
## - skip(): a pick press during the deal ends it at once (the final state); no input waits on the animation.
## - Reduced motion: no deal and no flip; every card is face up from the start (StoneCard's quick fade shows it).
## Times are starting values (presentation feel, OWNER ONLY).

const ARRIVE_S := 0.34
const STAGGER_S := 0.09
const GAP_S := 0.08
const FLIP_S := 0.22
const FLIP_STAGGER_S := 0.16
const WAIT_S := 0.75
const PUNCH_S := 0.32
const FLASH_S := 0.4
const RAYS_S := 0.5
## The fan: each card's turn (radians) and drop (px at scale 1) per step from the middle card.
const FAN_TURN := 0.07
const FAN_DROP := 14.0
## How far below its place a card starts (px; the panel passes the screen's height).
const FROM_BELOW := 900.0
## The punch's peak extra scale.
const PUNCH := 0.16

var count := 0
var reduced := false
var time := 0.0
var _arrive_at: PackedFloat32Array = []
var _flip_at: PackedFloat32Array = []
var _high: Array[bool] = []
var _wait_from := -1.0
var _wait_to := -1.0
var _end := 0.0
var _skipped := false


## An Epic or a Legendary tier (PickSlot.TIERS index: 2 epic, CardFrames.LEGENDARY_TIER).
static func high(tier: int) -> bool:
	return tier == 2 or tier == CardFrames.LEGENDARY_TIER


## The order the cards flip in: the others in slot order, then the high ones (Epic, Legendary) in slot order.
static func order(tiers: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pass_high in [false, true]:
		for k in tiers.size():
			if high(int(tiers[k])) == pass_high:
				out.append(k)
	return out


## Starts a deal of cards with these tiers (PickSlot.TIERS indices, in slot order).
func start(tiers: Array, p_reduced: bool = false) -> void:
	count = tiers.size()
	reduced = p_reduced
	time = 0.0
	_skipped = reduced
	_arrive_at.resize(count)
	_flip_at.resize(count)
	_high.clear()
	for k in count:
		_arrive_at[k] = k * STAGGER_S
		_high.append(high(int(tiers[k])))
	var t := (count - 1) * STAGGER_S + ARRIVE_S + GAP_S if count > 0 else 0.0
	var waited := false
	for k in order(tiers):
		if _high[k] and not waited:
			waited = true
			_wait_from = t
			_wait_to = t + WAIT_S
			t = _wait_to
		_flip_at[k] = t
		t += FLIP_STAGGER_S if not _high[k] else FLIP_S + 0.12
	if not waited:
		_wait_from = -1.0
		_wait_to = -1.0
	_end = t + maxf(FLIP_S, PUNCH_S if waited else 0.0)


func advance(delta: float) -> void:
	time += maxf(delta, 0.0)


## Ends the deal now: every card in place and face up (a pick press, or reduced motion).
func skip() -> void:
	_skipped = true


func done() -> bool:
	return _skipped or time >= _end


func skipped() -> bool:
	return _skipped


## The deal's length (s) when nothing skips it.
func length() -> float:
	return _end


## Card k is high (waits for last).
func is_high(k: int) -> bool:
	return k >= 0 and k < _high.size() and _high[k]


## 0..1: how far card k has come up from below (eased).
func arrive(k: int) -> float:
	if _skipped:
		return 1.0
	var t := clampf((time - _arrive_at[k]) / ARRIVE_S, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


## 0..1 of card k's flip (0 face down, 1 face up).
func flip(k: int) -> float:
	if _skipped:
		return 1.0
	return clampf((time - _flip_at[k]) / FLIP_S, 0.0, 1.0)


## Card k shows its face (past the flip's halfway).
func face_up(k: int) -> bool:
	return flip(k) >= 0.5


## Card k's width scale now: 1 → 0 over the flip's first half, 0 → 1 over the second.
func width(k: int) -> float:
	var f := flip(k)
	return absf(1.0 - 2.0 * f) if f > 0.0 and f < 1.0 else 1.0


## 0..1: the darkened background of the rare wait (rises over the wait, fades as the last high card lands).
func dark() -> float:
	if _wait_from < 0.0:
		return 0.0
	if _skipped:
		return 0.6
	if time < _wait_from:
		return 0.0
	var up := clampf((time - _wait_from) / (WAIT_S * 0.5), 0.0, 1.0)
	return lerpf(1.0, 0.6, clampf((time - _end) / 0.3, 0.0, 1.0)) * up


## 0..1: card k's glowing back (a high card waiting face down; it pulses during the wait).
func back_glow(k: int) -> float:
	if not is_high(k) or face_up(k):
		return 0.0
	var base := 0.55
	if _wait_from >= 0.0 and time >= _wait_from:
		base = 0.8 + 0.2 * sin((time - _wait_from) * TAU * 1.6)
	return base


## Card k's punch: extra scale, peaking just after it lands face up, then settling.
func punch(k: int) -> float:
	if _skipped or not is_high(k):
		return 0.0
	var t := (time - _flip_at[k] - FLIP_S * 0.5) / PUNCH_S
	if t <= 0.0 or t >= 1.0:
		return 0.0
	return PUNCH * sin(t * PI) * (1.0 - t * 0.4)


## 0..1: the white flash on card k as it lands face up.
func flash(k: int) -> float:
	if _skipped or not is_high(k):
		return 0.0
	var t := (time - _flip_at[k] - FLIP_S * 0.5) / FLASH_S
	return 0.0 if t <= 0.0 or t >= 1.0 else 1.0 - t


## 0..1: the light rays behind card k: rise as it flips face up, then stay (a softer glow) while it shows.
func rays(k: int) -> float:
	if not is_high(k):
		return 0.0
	if _skipped:
		return 0.55
	var t := (time - _flip_at[k] - FLIP_S * 0.5) / RAYS_S
	if t <= 0.0:
		return 0.0
	return 1.0 if t < 1.0 else lerpf(1.0, 0.55, clampf(t - 1.0, 0.0, 1.0))


## Card k's fan pose in its final place: [turn (radians), drop (px at scale 1)] for `count` cards.
func fan(k: int) -> Vector2:
	var mid := (count - 1) * 0.5
	var step := k - mid
	return Vector2(step * FAN_TURN, absf(step) * FAN_DROP)
