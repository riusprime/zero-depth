class_name FoundryClips
extends RefCounted
## v0.8.0 BA: the Foundry's clips (the owner's walking furnace, its legs cut in code by BossRig: body and four legs).
## Parameters the avatar maps: gait_a_* (front left and back right) and gait_b_* (front right and back left) for its
## steps, splay (every foot slid out to the side), front_lift (the front legs raised), front_kneel and back_kneel (a
## pair folded under), heat (the grate's glow, + hotter, - dying). A squat iron furnace, so it moves like a heavy
## pot on legs: bellows breathing when idle, a waddling walk, crouching then heaving up as it erupts for its
## patterns (the Slag Fountain shut tight: the shielded hold), tipping forward on folded front legs to pour the
## Molten Flood, crouched low and hopping with the Vent Blast, rocking back and kicking forward to launch its drones,
## rearing on its back legs and slamming down for the Firestorm; a jolt, a lurching stagger, a roar reared back with
## its fire roaring, heaving itself up out of the ground, and a collapse with its fire dying.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const UP := Vector3(0, 1, 0)
const FWD := Vector3(1, 0, 0)
const B := BossClip.BODY
const IO := BossClip.IN_OUT
const IN3 := BossClip.IN3
const IN := BossClip.IN
const OUT := BossClip.OUT
const OUT3 := BossClip.OUT3
const BACK := BossClip.BACK
const LIN := BossClip.LINEAR
const S := BossClip.SETTLE

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		for c: BossClip in [
			_idle(),
			_walk(),
			_pattern(),
			_row_flood(),
			_slam_ring(),
			_brood(),
			_flood(),
			_melt(),  # v0.8.0 BS2 (S6)
			_shielded(),
			_flinch(),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


## Bellows: the body swells and settles, the fire breathing with it.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(&"body", [[0, 0], [0.5, 0.035], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.5, 0.025], [1, 0]])
	c.turn(&"body", X, [[0, 0.015], [0.5, -0.015], [1, 0.015]])
	c.param(&"heat", [[0, 0], [0.5, 0.3], [1, 0]])
	return c


## The waddle: diagonal pairs lift and swing in turn, the body bobs on each step and rolls toward the planted pair.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.param(&"gait_a_lift", [[0, 0], [0.25, 0.2, OUT], [0.5, 0, IN], [1, 0]])
	c.param(&"gait_b_lift", [[0, 0], [0.5, 0], [0.75, 0.2, OUT], [1, 0, IN]])
	c.param(&"gait_a_swing", [[0, -0.3], [0.5, 0.3], [1, -0.3]])
	c.param(&"gait_b_swing", [[0, 0.3], [0.5, -0.3], [1, 0.3]])
	c.shift(&"body", UP, [[0, 0], [0.25, 0.07, OUT], [0.5, 0, IN], [0.75, 0.07, OUT], [1, 0, IN]])
	c.turn(&"body", X, [[0, 0.06], [0.25, 0], [0.5, -0.06], [0.75, 0], [1, 0.06]])
	c.turn(&"body", Z, [[0, -0.04], [1, -0.04]])
	return c


## Its patterns (the Furnace Waves; the Slag Fountain adds the shielded hold): it crouches with its fire building,
## then heaves up as it erupts (strike) and pumps with each burst.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.param(&"splay", [[0, 0], [0.42, 0.25], [0.5, 0.05, IN3], [0.62, 0.1], [1, 0]])
	var heave := [[0, 0], [0.12, 0.04], [0.42, -0.24], [0.47, -0.27, OUT], [0.5, 0.14, IN3]]
	for k in 3:
		var t0 := 0.53 + 0.03 * k
		heave.append([t0, -0.06, OUT])
		heave.append([t0 + 0.015, 0.1, IN3])
	heave.append_array([[0.62, 0.05], [0.8, -0.05], [1, 0]])
	c.shift(&"body", UP, heave)
	c.stretch(
		&"body",
		[[0, 0], [0.42, -0.08], [0.5, 0.12, IN3], [0.535, 0.16, OUT3, S], [0.62, 0.06], [1, 0]]
	)
	c.turn(&"body", Z, [[0, 0], [0.42, 0.12], [0.5, -0.06, IN3], [0.62, 0], [1, 0]])
	c.param(&"heat", [[0, 0], [0.42, 1.2], [0.5, 2.0], [0.62, 1.5], [0.85, 0.3], [1, 0]])
	c.param(
		&"tremble", [[0, 0], [0.3, 0], [0.47, 0.5], [0.5, 1, LIN], [0.62, 0.5], [0.7, 0], [1, 0]]
	)
	return c


## The Molten Flood: it folds its front legs and tips forward over the rows, lurches into the pour on the strike and
## holds it, rocking, while the rows burn.
static func _row_flood() -> BossClip:
	var c := BossClip.new(&"row_flood")
	c.param(&"front_kneel", [[0, 0], [0.42, 0.8, BACK], [0.62, 0.8], [0.85, 0.2], [1, 0]])
	c.turn(
		&"body",
		Z,
		[
			[0, 0],
			[0.12, -0.05],
			[0.42, 0.25],
			[0.5, -0.6, IN3],
			[0.53, -0.68, OUT3, S],
			[0.56, -0.55],
			[0.59, -0.62],
			[0.62, -0.58],
			[0.85, -0.1],
			[1, 0]
		]
	)
	c.shift(&"body", FWD, [[0, 0], [0.42, -0.1], [0.5, 0.3, IN3], [0.62, 0.25], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, 0.06], [0.5, -0.22, IN3], [0.62, -0.18], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.1], [0.5, -0.2, IN3], [0.62, -0.16], [1, 0]])
	c.param(&"heat", [[0, 0], [0.42, 1.2], [0.5, 2.2, IN3], [0.62, 2.0], [0.85, 0.4], [1, 0]])
	return c


## The Vent Blast: it crouches low on splayed legs, the fire building, then blows and hops with the ring.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.param(&"splay", [[0, 0], [0.42, 0.9, BACK], [0.5, -0.15, IN3], [0.62, 0.0], [1, 0]])
	c.shift(
		&"body",
		UP,
		[
			[0, 0],
			[0.42, -0.3],
			[0.47, -0.33, OUT],
			[0.5, 0.25, IN3],
			[0.54, 0.3, OUT3, S],
			[0.62, 0.1],
			[0.72, -0.06, IO, S],
			[1, 0]
		]
	)
	c.stretch(
		&"body", [[0, 0], [0.42, -0.1], [0.5, 0.16, IN3], [0.56, 0.0], [0.64, -0.08, IO, S], [1, 0]]
	)
	c.stretch(B, [[0, 0], [0.42, -0.06], [0.5, 0.06, IN3], [0.62, -0.06], [0.72, 0.0], [1, 0]])
	c.param(&"heat", [[0, 0], [0.42, 1.5], [0.5, 2.5, IN3], [0.62, 1.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0], [0.48, 0.6], [0.5, 1, LIN], [0.6, 0], [1, 0]])
	return c


## The bomb launch: it rocks back on folded back legs, then kicks forward as the drones fly.
static func _brood() -> BossClip:
	var c := BossClip.new(&"brood")
	c.param(&"back_kneel", [[0, 0], [0.42, 0.6], [0.5, 0.0, IN3], [1, 0]])
	c.turn(
		&"body",
		Z,
		[
			[0, 0],
			[0.42, 0.26],
			[0.47, 0.28, OUT],
			[0.5, -0.16, IN3],
			[0.54, -0.2, OUT3, S],
			[0.62, -0.1],
			[1, 0]
		]
	)
	c.shift(&"body", FWD, [[0, 0], [0.42, -0.1], [0.5, 0.14, IN3], [0.62, 0.08], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, -0.06], [0.5, 0.06, IN3], [0.62, 0], [1, 0]])
	c.param(&"heat", [[0, 0], [0.42, 0.8], [0.5, 1.5], [0.62, 0.8], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.6, LIN], [0.56, 0], [1, 0]])
	return c


## The Firestorm: it rears up on its back legs, front legs raised, then slams down and holds, roaring, while the
## lanes burn.
static func _flood() -> BossClip:
	var c := BossClip.new(&"flood")
	c.param(&"front_lift", [[0, 0], [0.42, 0.3, BACK], [0.5, -0.04, IN3], [0.62, 0.0], [1, 0]])
	c.param(&"back_kneel", [[0, 0], [0.42, 0.35], [0.5, 0.0, IN3], [1, 0]])
	c.turn(
		B,
		Z,
		[
			[0, 0],
			[0.12, -0.05],
			[0.42, 0.35, BACK],
			[0.5, -0.06, IN3],
			[0.54, -0.1, OUT3, S],
			[0.62, -0.04],
			[1, 0]
		]
	)
	c.shift(B, UP, [[0, 0], [0.42, 0.12], [0.5, -0.12, IN3], [0.62, -0.08], [1, 0]])
	c.stretch(
		B, [[0, 0], [0.42, 0.06], [0.5, -0.14, IN3], [0.56, 0.04, OUT, S], [0.62, -0.03], [1, 0]]
	)
	c.param(&"heat", [[0, 0], [0.42, 1.0], [0.5, 2.5, IN3], [0.62, 2.0], [0.85, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.62, 0.4], [0.7, 0], [1, 0]])
	return c


## Shielded (the Slag Fountain): it hunkers down low on splayed legs, the door shut.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.shift(&"body", UP, [[0, 0], [0.7, -0.32, BACK], [1, -0.28]])
	c.param(&"splay", [[0, 0], [0.7, 0.3, BACK], [1, 0.25]])
	c.stretch(&"body", [[0, 0], [0.7, -0.05], [1, -0.04]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"body", Z, [[0, 0], [0.15, 0.1, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.1, OUT3], [1, 0]])
	c.param(&"heat", [[0, 0], [0.15, 0.8, OUT3], [1, 0]])
	return c


## Staggered: it lurches back and slumps low, its fire dimming.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"body", Z, [[0, 0], [0.1, 0.14, OUT3], [0.4, 0.06], [1, 0.06]])
	c.turn(&"body", X, [[0, 0], [0.4, 0.1], [1, 0.08]])
	c.shift(&"body", UP, [[0, 0], [0.1, 0.06], [0.4, -0.16], [1, -0.14]])
	c.param(&"splay", [[0, 0], [0.4, 0.22], [1, 0.2]])
	c.param(&"heat", [[0, 0], [0.4, -0.7], [1, -0.7]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## v0.8.0 BS2 (owner O5, S6): the meltdown. Through its long windup (0..0.6, the 2 s the outer ring glows) it rears
## back on its back legs, roaring, its fire roaring hotter and hotter and the body swelling, shaking; on the strike
## (the ring melts) it slams down onto splayed legs and pours, tipped forward with its grate blazing; then it settles.
static func _melt() -> BossClip:
	var c := BossClip.new(&"melt")
	c.strike = 0.6
	c.hold = 0.72
	c.param(
		&"front_lift",
		[[0, 0], [0.4, 0.3, BACK], [0.58, 0.32], [0.6, -0.05, IN3], [0.72, 0.0], [1, 0]]
	)
	c.param(
		&"splay", [[0, 0], [0.58, 0], [0.6, 0.8, IN3], [0.64, 0.6, OUT, S], [0.72, 0.5], [1, 0]]
	)
	c.turn(
		B, Z, [[0, 0], [0.4, 0.36, BACK], [0.58, 0.38], [0.6, -0.22, IN3], [0.72, -0.16], [1, 0]]
	)
	c.stretch(
		&"body", [[0, 0], [0.4, 0.14, BACK], [0.58, 0.18], [0.6, -0.16, IN3], [0.72, -0.08], [1, 0]]
	)
	c.shift(&"body", UP, [[0, 0], [0.58, 0.04], [0.6, -0.2, IN3], [0.72, -0.12], [1, 0]])
	c.param(
		&"heat", [[0, 0], [0.3, 1.4], [0.58, 2.6], [0.6, 3.0, IN3], [0.72, 2.4], [0.9, 0.6], [1, 0]]
	)
	c.param(
		&"tremble", [[0, 0], [0.2, 0.2], [0.56, 1, LIN], [0.6, 0.6], [0.72, 0.2], [0.8, 0], [1, 0]]
	)
	return c


## The phase gate's roar: it rears back on its back legs, swelling, its fire roaring, shaking.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.param(&"front_lift", [[0, 0], [0.36, 0.25, BACK], [0.85, 0.22], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.2, -0.06], [0.36, 0.32, BACK], [0.85, 0.28], [1, 0]])
	c.stretch(&"body", [[0, 0], [0.2, -0.06], [0.36, 0.16, BACK], [0.85, 0.12], [1, 0]])
	c.param(&"heat", [[0, 0], [0.36, 2.5], [0.85, 2.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise-in: it comes up crouched on splayed legs, cold, then heaves itself up as its fire lights.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.param(&"splay", [[0, 0.5], [0.5, 0.45], [0.64, -0.05, IN3], [0.74, 0.03, OUT, S], [1, 0]])
	c.shift(
		&"body", UP, [[0, -0.25], [0.5, -0.22], [0.64, 0.14, IN3], [0.74, -0.03, OUT, S], [1, 0]]
	)
	c.param(&"heat", [[0, -0.8], [0.5, -0.6], [0.64, 2.0, IN3], [0.85, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 0.8, LIN], [0.74, 0], [1, 0]])
	return c


## Its death: it jolts, its legs give way outward, the body crashes down tipping forward, rocks once, its fire
## dies, and it sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.param(&"splay", [[0, 0], [0.15, 0.1], [0.55, 1.1, IN], [1, 1.2]])
	c.shift(
		&"body",
		UP,
		[[0, 0], [0.15, 0.08], [0.55, -0.5, IN], [0.62, -0.42, OUT, S], [0.7, -0.5], [1, -0.5]]
	)
	c.turn(
		B,
		Z,
		[[0, 0], [0.15, 0.1], [0.55, -0.28, IN], [0.62, -0.2, OUT, S], [0.7, -0.28], [1, -0.28]]
	)
	c.turn(B, X, [[0, 0], [0.55, 0.1], [1, 0.1]])
	c.param(&"heat", [[0, 0], [0.15, 1.5], [0.6, -0.5], [1, -1.0]])
	c.shift(B, UP, [[0, 0], [0.84, 0], [1, -2.4, IN]])
	c.param(&"tremble", [[0, 0], [0.54, 0], [0.56, 1, LIN], [0.66, 0], [1, 0]])
	return c
