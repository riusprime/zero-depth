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
