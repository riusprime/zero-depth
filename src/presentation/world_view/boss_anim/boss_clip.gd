class_name BossClip
extends RefCounted
## v0.8.0 BA (owner O6: "the animations they do are a shit … we have to work on animations"; Q4: code clips first,
## the owner's replace them): one keyframed boss animation clip. A clip is a list of tracks; each track moves one
## target along one channel through keys of (time, value, ease, flags):
## - TURN: a bone (or BODY, the model's pivot) turns by `value` radians about `axis` (model frame: +X the front, Y up,
##   +Z the right; +Z pitches the top back and swings a hanging limb forward, +X swings a hanging limb out to the
##   left, +Y turns the front to the left);
## - SHIFT: a bone's pivot (or BODY) moves `value` metres along `axis`;
## - STRETCH: a bone scales by 1 + `value`; on BODY it is a volume-keeping squash (+ taller and thinner, - flatter);
## - PARAM: a named float the avatar reads and maps onto its parts itself (a spider's leg groups, a tail's curl).
## Values are offsets from the rest pose, so clips layer additively (BossAnimator sums every layer's tracks).
## Time runs 0..1. A looping clip (idle, walk) wraps. An attack clip's time is driven by the sim's attack phase
## (BossAvatar.clip_time): the windup fills 0..strike, the active ticks strike..hold, the recovery hold..1, so the key
## at `strike` is the pose on the attack's first active tick, the tick its hit resolves. An impact clip keeps the
## same pose at `strike` and `hold`: a move with several strikes (a `marks` attack's later markers) cycles
## strike..hold once per strike.
## Reduced motion (ViewPrefs.reduced_motion): keys flagged SETTLE (overshoots and settling bounces) are skipped and
## BACK eases become OUT3, so the poses still read but nothing overshoots.
## Built once per boss type (the clip libraries); sampling allocates nothing.

## Easing of the segment that arrives at a key.
const LINEAR := 0
const IN := 1
const IN3 := 2
const OUT := 3
const OUT3 := 4
const IN_OUT := 5
const BACK := 6
const HOLD := 7
## Channels.
const TURN := 0
const SHIFT := 1
const STRETCH := 2
const PARAM := 3
## The target that is the model's whole body (its pivot node) rather than a bone.
const BODY := &"@body"
## Key flags.
const SETTLE := 1
## The default attack timing: the windup fills 0..STRIKE, the active ticks STRIKE..HOLD_END.
const STRIKE := 0.5
const HOLD_END := 0.62
## v0.11.0 O16 (owner Q11: "right now the animation feels too stiff"; Q30: "all bosses, the Twins first"): the same
## loosening O16a gave the Twin Wardens by hand, applied to a whole library once it is built:
## - the idle: every bone's and the body's sway swings `gain` (IDLE_GAIN by default) times as wide about its middle
##   (a held pose, such as a carried weapon, stays where it is), plus, when `sway` > 0, a slow weight shift of the
##   whole body (radians);
## - each attack clip (a move's clip or its shielded variant): every moving track that rises from rest to its first
##   pose at the windup first dips the other way (ANTICIPATE of that pose, at ANTICIPATE_AT of the way to it: the
##   gather before the draw-back), and every track that eases back to rest from the end of its active part
##   overshoots rest the other way (RECOIL of that pose, RECOIL_AT of the way through the recovery: the follow-
##   through). The keys at `strike` and `hold` are untouched, so the strike pose still lands on the sim's first
##   active tick; the clip still ends at rest. Both new keys are SETTLE: reduced motion skips them.
## Parameter tracks (glow, legs, chains) are left alone. Starting values.
const IDLE_GAIN := 1.6
const ANTICIPATE := 0.3
const ANTICIPATE_AT := 0.3
const RECOIL := 0.4
const RECOIL_AT := 0.35

var name: StringName
var loop := false
## Where the strike lands and where the active part ends (attack clips).
var strike := STRIKE
var hold := HOLD_END
## The tracks, flattened.
var targets: Array[StringName] = []
var channels := PackedInt32Array()
var axes := PackedVector3Array()
var first := PackedInt32Array()
var counts := PackedInt32Array()
var times := PackedFloat32Array()
var values := PackedFloat32Array()
var eases := PackedInt32Array()
var flags := PackedInt32Array()


func _init(clip_name: StringName, looping: bool = false) -> void:
	name = clip_name
	loop = looping


## Adds a turn track: `keys` is an array of [time, radians] or [time, radians, ease] or [time, radians, ease, flags].
func turn(target: StringName, axis: Vector3, keys: Array) -> BossClip:
	return _track(target, TURN, axis.normalized(), keys)


## Adds the same turn to a left and a right bone; `mirror` negates the right one's (a turn about X or Y: out to
## each side, or each turning outward).
func turn_pair(
	left: StringName, right: StringName, axis: Vector3, keys: Array, mirror: bool = false
) -> BossClip:
	turn(left, axis, keys)
	return turn(right, axis, negated(keys) if mirror else keys)


## Keys with their values negated (build time only).
static func negated(keys: Array) -> Array:
	var out := []
	for key: Array in keys:
		var k := key.duplicate()
		k[1] = -float(k[1])
		out.append(k)
	return out


## Keys with their values scaled (build time only).
static func scaled(keys: Array, by: float) -> Array:
	var out := []
	for key: Array in keys:
		var k := key.duplicate()
		k[1] = float(k[1]) * by
		out.append(k)
	return out


## Adds a shift track: metres along `axis`.
func shift(target: StringName, axis: Vector3, keys: Array) -> BossClip:
	return _track(target, SHIFT, axis.normalized(), keys)


## Adds a stretch track (a bone: scale 1 + value; BODY: a squash, + taller).
func stretch(target: StringName, keys: Array) -> BossClip:
	return _track(target, STRETCH, Vector3.ZERO, keys)


## Adds a named parameter track.
func param(target: StringName, keys: Array) -> BossClip:
	return _track(target, PARAM, Vector3.ZERO, keys)


func track_count() -> int:
	return targets.size()


## The first track moving `target` on `channel`, or -1.
func track_of(target: StringName, channel: int) -> int:
	for k in targets.size():
		if targets[k] == target and channels[k] == channel:
			return k
	return -1


## Every target this clip moves (tests: the bones it needs).
func target_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in targets:
		if not out.has(t):
			out.append(t)
	return out


## Track k's value at time t (0..1; a loop wraps). Allocates nothing.
func value(k: int, t: float, reduced: bool = false) -> float:
	var s := first[k]
	var n := counts[k]
	t = fposmod(t, 1.0) if loop else clampf(t, 0.0, 1.0)
	var k0 := -1
	var k1 := -1
	for j in n:
		var q := s + j
		if reduced and (flags[q] & SETTLE) != 0:
			continue
		if times[q] <= t:
			k0 = q
		elif k1 < 0:
			k1 = q
	if k0 < 0:
		return values[k1] if k1 >= 0 else 0.0
	if k1 < 0:
		return values[k0]
	var span := times[k1] - times[k0]
	var u := (t - times[k0]) / span if span > 0.0 else 1.0
	return lerpf(values[k0], values[k1], ease_of(eases[k1], u, reduced))


## The eases (u 0..1 → 0..1; BACK overshoots past 1 before it settles).
static func ease_of(e: int, u: float, reduced: bool = false) -> float:
	match e:
		IN:
			return u * u
		IN3:
			return u * u * u
		OUT:
			return 1.0 - (1.0 - u) * (1.0 - u)
		OUT3:
			return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)
		IN_OUT:
			return u * u * (3.0 - 2.0 * u)
		BACK:
			if reduced:
				return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)
			var v := u - 1.0
			return 1.0 + 2.70158 * v * v * v + 1.70158 * v * v
		HOLD:
			return 1.0 if u >= 1.0 else 0.0
	return u


func _track(target: StringName, channel: int, axis: Vector3, keys: Array) -> BossClip:
	assert(not keys.is_empty(), "%s: a track needs keys" % name)
	targets.append(target)
	channels.append(channel)
	axes.append(axis)
	first.append(times.size())
	counts.append(keys.size())
	var last := -1.0
	for key: Array in keys:
		var t := float(key[0])
		assert(t >= last and t <= 1.0, "%s %s: keys in time order, 0..1" % [name, target])
		last = t
		times.append(t)
		values.append(float(key[1]))
		eases.append(int(key[2]) if key.size() > 2 else IN_OUT)
		flags.append(int(key[3]) if key.size() > 3 else 0)
	return self


## v0.11.0 O16: loosens a built library in place, once (the wind-up, the recoil, the idle sway: see IDLE_GAIN).
static func loosen(library: Dictionary, sway: float = 0.0, gain: float = IDLE_GAIN) -> void:
	var moves := {}
	for n: StringName in BossAnimator.MOVE_CLIPS.values():
		moves[n] = true
	for c: BossClip in library.values():
		if c.name == &"idle":
			c._loosen_idle(sway, gain)
		elif (
			moves.has(c.name)
			or (String(c.name).ends_with(BossAnimator.SHIELDED_SUFFIX) and c.name != &"shielded")
		):
			c._loosen_attack()


func _keys_of(k: int) -> Array:
	var out := []
	for j in counts[k]:
		var q := first[k] + j
		out.append([times[q], values[q], eases[q], flags[q]])
	return out


## Rebuilds the flattened tracks from per-track key lists (build time only).
func _rebuild(tracks: Array) -> void:
	var t0 := targets.duplicate()
	var c0 := channels.duplicate()
	var a0 := axes.duplicate()
	targets.clear()
	channels = PackedInt32Array()
	axes = PackedVector3Array()
	first = PackedInt32Array()
	counts = PackedInt32Array()
	times = PackedFloat32Array()
	values = PackedFloat32Array()
	eases = PackedInt32Array()
	flags = PackedInt32Array()
	for k in tracks.size():
		_track(t0[k], c0[k], a0[k], tracks[k])


func _loosen_idle(sway: float, gain: float) -> void:
	var tracks := []
	for k in targets.size():
		var keys := _keys_of(k)
		if channels[k] != PARAM:
			var lo := INF
			var hi := -INF
			for key: Array in keys:
				lo = minf(lo, key[1])
				hi = maxf(hi, key[1])
			var mid := (lo + hi) * 0.5
			for key: Array in keys:
				key[1] = mid + (float(key[1]) - mid) * gain
		tracks.append(keys)
	_rebuild(tracks)
	if sway > 0.0:
		turn(BODY, Vector3(1, 0, 0), [[0, sway], [0.5, -sway], [1, sway]])


func _loosen_attack() -> void:
	var tracks := []
	for k in targets.size():
		var keys := _keys_of(k)
		if channels[k] != PARAM and keys.size() >= 3:
			_anticipate(keys)
			_recoil(keys)
		tracks.append(keys)
	_rebuild(tracks)


## A dip the other way before the first pose (the first key rest at 0, the next a pose reached by the strike).
func _anticipate(keys: Array) -> void:
	var k0: Array = keys[0]
	var k1: Array = keys[1]
	var t1 := float(k1[0])
	if float(k0[0]) != 0.0 or absf(k0[1]) > 0.0001 or absf(k1[1]) < 0.0001:
		return
	if t1 < 0.2 or t1 > strike + 0.0001:
		return
	keys.insert(1, [t1 * ANTICIPATE_AT, -float(k1[1]) * ANTICIPATE, OUT, SETTLE])


## An overshoot past rest after the active part (the last key rest at 1, the one before it at or after `hold`), unless
## the track already settles after its strike.
func _recoil(keys: Array) -> void:
	var n := keys.size()
	var last: Array = keys[n - 1]
	var prev: Array = keys[n - 2]
	var tp := float(prev[0])
	if float(last[0]) != 1.0 or absf(last[1]) > 0.0001 or absf(prev[1]) < 0.0001:
		return
	if tp < hold - 0.0001 or 1.0 - tp < 0.15:
		return
	for key: Array in keys:
		if float(key[0]) > strike and (int(key[3]) & SETTLE) != 0:
			return
	keys.insert(n - 1, [tp + (1.0 - tp) * RECOIL_AT, -float(prev[1]) * RECOIL, OUT, SETTLE])
