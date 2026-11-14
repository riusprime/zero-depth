class_name StoneThrowerPoses
extends RefCounted
## The Stone Thrower's clips as poses (StoneThrowerAvatar's raw drives: {drive: value}), from the clocks
## the avatar keeps; pure functions of their inputs, so the code avatar and its VAT twin pose alike. Each clip is a few
## key poses eased into each other (anticipation before the big moves, an overshoot and a settle after them) with a
## little secondary motion on top (the breath, the sway, the trailing hands, the strain's shudder). Presentation only.

const A := preload("res://src/presentation/world_view/stone_thrower_avatar.gd")


## The pose `b` laid over `a` by u (the drives `b` doesn't name stay `a`'s).
static func mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := a.duplicate()
	for k: int in b:
		out[k] = lerpf(float(a.get(k, b[k])), float(b[k]), u)
	return out


static func smooth(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Keyframes [[time, pose], ...] (times rising) at time t: each span eased; before the first and after the last, held.
static func track(keys: Array, t: float) -> Dictionary:
	if t <= float(keys[0][0]):
		return (keys[0][1] as Dictionary).duplicate()
	for k in range(1, keys.size()):
		var t1 := float(keys[k][0])
		if t <= t1:
			var t0 := float(keys[k - 1][0])
			return mix(keys[k - 1][1], keys[k][1], smooth((t - t0) / maxf(t1 - t0, 1e-4)))
	return (keys[keys.size() - 1][1] as Dictionary).duplicate()


## A pose from {drive: value} plus both arms' values {drive base: value} (right at base, left at base + 1) and the
## legs' [right, left].
static func pose(one: Dictionary, arms: Dictionary, legs := []) -> Dictionary:
	var p := one.duplicate()
	for base: int in arms:
		p[base] = arms[base]
		p[base + 1] = arms[base]
	if legs.size() == 2:
		p[A.LEG0] = legs[0]
		p[A.LEG0 + 1] = legs[1]
	return p


## The idle and the walk: `t` the frame clock (s), `walk` 0..1, `phase` the stride's (radians), `speed` signed along
## the facing (m/s), `puff` the heavy breath after a throw (0..1), `calm` reduced motion.
static func locomotion(
	t: float, walk: float, phase: float, speed: float, puff: float, calm: bool
) -> Dictionary:
	var amp := 0.5 if calm else 1.0
	var w := walk
	var breath := sin(t * TAU * 0.42) * (1.0 + 0.8 * puff)
	var shift := sin(t * 0.55) * amp
	var p := {}
	# Idle: the chest heaves, the weight shifts slowly, the arms hang and sway a little out of step.
	p[A.HY] = (-0.02 + 0.012 * breath) * amp * (1.0 - w)
	p[A.HZ] = 0.025 * shift * (1.0 - w)
	p[A.SWAY] = 0.035 * shift * (1.0 - w)
	p[A.LEAN] = -0.16 + 0.035 * breath * amp
	p[A.BREATH] = breath * amp
	p[A.HNOD] = -0.05 * breath * amp
	p[A.HYAW] = 0.3 * sin(t * 0.37) * sin(t * 0.23 + 1.0) * amp * (1.0 - w)
	p[A.TWIST] = 0.0
	p[A.HX] = 0.0
	p[A.TOPPLE] = 0.0
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var sway := t * TAU * 0.31 + side * 0.9
		p[A.SPREAD0 + k] = 0.03 + 0.025 * breath * amp
		p[A.YAW0 + k] = 0.0
		p[A.SWING0 + k] = 0.05 * sin(sway) * amp + 0.02 * breath * amp
		p[A.ELBOW0 + k] = 0.06 + 0.06 * sin(sway - 1.0) * amp
		p[A.WRIST0 + k] = 0.08 * sin(sway - 1.8) * amp  # the knuckles brush the floor, trailing the sway
		p[A.LIFT0 + k] = 0.0
		p[A.LEG0 + k] = 0.0
	if w <= 0.001:
		return p
	# The walk: the legs on the stride, the body bobbing on each step and rolling over the planted leg, the arms swung
	# against the legs with the forearms and hands trailing.
	var s := sin(phase)
	var c := cos(phase)
	var bob := cos(2.0 * phase) * amp
	var q := {}
	q[A.HY] = (-0.035 + 0.035 * bob) * w
	q[A.HZ] = -0.04 * c * amp * w
	q[A.SWAY] = -0.09 * c * amp * w
	q[A.TWIST] = 0.12 * s * amp * w
	q[A.LEAN] = -0.24 + 0.035 * bob
	q[A.HNOD] = 0.06 - 0.04 * bob
	q[A.HYAW] = -0.08 * s * amp * w
	q[A.BREATH] = breath * amp * 0.6
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		q[A.LEG0 + k] = A.LEG_SWING * w * s * side
		# the foot coming forward lifts (backing off: the one coming back)
		q[A.LIFT0 + k] = A.FOOT_LIFT * w * maxf(0.0, c * side * (1.0 if speed >= 0.0 else -1.0))
		var arm := -0.36 * sin(phase - 0.35) * side * w
		q[A.SWING0 + k] = 0.04 + arm
		q[A.SPREAD0 + k] = 0.06 + 0.04 * maxf(0.0, -arm) * amp
		q[A.ELBOW0 + k] = 0.1 + 0.32 * maxf(0.0, arm) + 0.06 * w
		q[A.WRIST0 + k] = -0.25 * sin(phase - 1.1) * side * w * amp
	return mix(p, q, w)


## The lift, the throw and the recovery at `a` seconds from the lift's start, over the locomotion pose `base`:
## `ticks` the sim's (the lift, the throw's flight, the recovery), `t` the frame clock (the shudders).
static func attack(a: float, base: Dictionary, ticks: Vector3i, t: float, calm: bool) -> Dictionary:
	var lift := ticks.x / 60.0
	var throw := lift + ticks.y / 60.0
	var rec := throw + ticks.z / 60.0
	var still := {A.HYAW: 0.0, A.TWIST: 0.0, A.SWAY: 0.0, A.HZ: 0.0, A.LIFT0: 0.0, A.LIFT0 + 1: 0.0}
	# a small rise before it goes down (the anticipation)
	var antic := pose({A.HY: 0.04, A.LEAN: 0.06, A.HNOD: 0.12}, {A.SWING0: -0.12, A.ELBOW0: 0.25})
	# down: the hands at the floor in front, then digging in
	var reach := pose(
		mix(still, {A.HX: 0.08, A.HY: -0.12, A.LEAN: -0.6, A.HNOD: -0.3}, 1.0),
		{A.SWING0: 0.3, A.SPREAD0: -0.2, A.YAW0: 0.0, A.ELBOW0: -0.05, A.WRIST0: 0.55},
		[0.22, -0.18]
	)
	var dig := mix(
		reach,
		pose({A.HY: -0.17, A.LEAN: -0.66}, {A.SWING0: 0.26, A.ELBOW0: 0.02, A.WRIST0: 0.85}),
		1.0
	)
	# the heave: the rock up past the chest, the hands brought in round it
	var heave := pose(
		{A.HX: 0.02, A.HY: -0.06, A.LEAN: -0.12, A.HNOD: 0.05},
		{A.SWING0: 1.2, A.SPREAD0: 0.0, A.YAW0: 0.27, A.ELBOW0: 1.0, A.WRIST0: 0.45},
		[0.15, -0.15]
	)
	# overhead (overshooting a little), held, then arching further back under the strain to the throw
	var over := pose(
		{A.HX: -0.04, A.HY: 0.06, A.LEAN: 0.32, A.HNOD: 0.32},
		{A.SWING0: 2.16, A.SPREAD0: 0.17, A.YAW0: 0.0, A.ELBOW0: 0.35, A.WRIST0: 0.5},
		[0.2, -0.24]
	)
	var hold := mix(over, pose({A.LEAN: 0.25, A.HY: 0.04}, {A.SWING0: 2.02}), 1.0)
	var strain := mix(hold, pose({A.LEAN: 0.33, A.HY: 0.0}, {A.SWING0: 2.12, A.ELBOW0: 0.42}), 1.0)
	# the throw: the arms whip over and down past the knees, a step forward, the body folding after them
	var whip := pose(
		{A.HX: 0.08, A.HY: -0.06, A.LEAN: -0.05, A.HNOD: 0.05},
		{A.SWING0: 1.3, A.SPREAD0: 0.1, A.YAW0: 0.12, A.ELBOW0: 0.25, A.WRIST0: 0.2},
		[0.38, -0.28]
	)
	var thrown := pose(
		{A.HX: 0.17, A.HY: -0.17, A.LEAN: -0.68, A.HNOD: -0.22, A.TWIST: 0.08},
		{A.SWING0: -0.32, A.SPREAD0: 0.08, A.YAW0: 0.0, A.ELBOW0: 0.12, A.WRIST0: -0.3},
		[0.46, -0.32]
	)
	var past := mix(thrown, pose({A.LEAN: -0.74}, {A.SWING0: -0.48, A.WRIST0: -0.45}), 1.0)
	var settle := mix(thrown, pose({A.LEAN: -0.6, A.HY: -0.14}, {A.SWING0: -0.18}), 1.0)
	# the recovery: it straightens, the arms swinging back to hang
	var rise := pose(
		{A.HX: 0.08, A.HY: -0.06, A.LEAN: -0.3, A.HNOD: 0.0, A.TWIST: 0.0},
		{A.SWING0: 0.12, A.SPREAD0: 0.05, A.ELBOW0: 0.15, A.WRIST0: 0.0},
		[0.2, -0.1]
	)
	var keys := [
		[0.0, base],
		[lift * 0.1, mix(base, antic, 1.0)],
		[lift * 0.3, mix(base, reach, 1.0)],
		[lift * 0.4, mix(base, dig, 1.0)],
		[lift * 0.53, mix(base, heave, 1.0)],
		[lift * 0.66, mix(base, over, 1.0)],
		[lift * 0.76, mix(base, hold, 1.0)],
		[lift, mix(base, strain, 1.0)],
		[lift + 0.05, mix(base, whip, 1.0)],
		[lift + 0.11, mix(base, thrown, 1.0)],
		[lift + 0.2, mix(base, past, 1.0)],
		[lift + 0.45, mix(base, settle, 1.0)],
		[throw, mix(base, settle, 1.0)],
		[throw + (rec - throw) * 0.5, mix(base, rise, 1.0)],
		[rec, base],
	]
	var p := track(keys, a)
	if a < lift:
		var u := a / lift
		# the dig's grind (the hands working into the floor) and the strain's shudder growing to the throw
		var grind := smoothstep(0.3, 0.36, u) * (1.0 - smoothstep(0.4, 0.46, u))
		var st := smoothstep(0.66, 1.0, u)
		st *= st
		if not calm:
			var q := sin(t * TAU * 21.0)
			var q2 := sin(t * TAU * 27.0 + 1.3)
			p[A.HY] = float(p[A.HY]) + 0.012 * grind * q
			p[A.LEAN] = float(p[A.LEAN]) + 0.02 * grind * q2 + 0.022 * st * q
			p[A.HZ] = float(p.get(A.HZ, 0.0)) + 0.008 * st * q2
			for k in 2:
				p[A.SWING0 + k] = float(p[A.SWING0 + k]) + 0.03 * st * q2
				p[A.WRIST0 + k] = float(p[A.WRIST0 + k]) + 0.12 * grind * q
		p[A.BREATH] = 1.2 * smoothstep(0.66, 1.0, u) - 0.6 * grind
	return p


## The death at `d` seconds in, from the pose `base` it died in: it staggers back (the arms flailing), drops to its
## knees, then topples forward, falling faster and faster, with a small bounce off the floor.
static func death(d: float, base: Dictionary, calm: bool) -> Dictionary:
	var flail := 0.0 if calm else 1.0
	var stagger := pose(
		{
			A.HX: -0.12,
			A.HY: -0.04,
			A.LEAN: 0.32,
			A.HNOD: 0.35,
			A.TWIST: -0.1,
			A.BREATH: 0.0,
			A.TOPPLE: 0.0
		},
		{A.ELBOW0: 0.5, A.WRIST0: 0.3, A.YAW0: 0.0},
		[-0.28, 0.12]
	)
	stagger[A.SPREAD0] = 0.25 + 0.3 * flail
	stagger[A.SPREAD0 + 1] = 0.2 + 0.25 * flail
	stagger[A.SWING0] = 0.5 + 0.35 * flail
	stagger[A.SWING0 + 1] = 0.3 + 0.2 * flail
	var knees := pose(
		{
			A.HX: 0.04,
			A.HY: -0.36,
			A.LEAN: -0.3,
			A.HNOD: -0.35,
			A.TWIST: 0.0,
			A.SWAY: 0.05,
			A.TOPPLE: 0.0
		},
		{A.SPREAD0: 0.12, A.SWING0: 0.18, A.ELBOW0: 0.15, A.WRIST0: 0.2, A.LIFT0: 0.0},
		[-1.15, -1.15]
	)
	var down := mix(
		knees,
		pose(
			{A.TOPPLE: -1.38, A.LEAN: -0.25, A.HNOD: -0.1},
			{A.SWING0: 1.25, A.SPREAD0: 0.3, A.ELBOW0: 0.35},
			[-0.12, -0.05]  # the legs stretch out behind as it goes down flat
		),
		1.0
	)
	var bounce := mix(down, {A.TOPPLE: -1.27}, 1.0)
	var lie := mix(down, {A.TOPPLE: -1.36}, 1.0)
	var p := track([[0.0, base], [0.24, mix(base, stagger, 1.0)], [0.62, mix(base, knees, 1.0)]], d)
	if d > 0.72:
		var u := clampf((d - 0.72) / 0.42, 0.0, 1.0)
		p = mix(p, down, u * u)
		if d > 1.14:
			var v := clampf((d - 1.14) / 0.2, 0.0, 1.0)
			p = mix(p, bounce, sin(v * PI) * (0.4 if calm else 1.0))
			p = mix(p, lie, v)
	return p
