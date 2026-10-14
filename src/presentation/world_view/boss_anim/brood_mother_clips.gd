class_name BroodMotherClips
extends RefCounted
## v0.8.0 BA: the Brood Mother's clips (the owner's Crawler Queen, rigged in code by BossRig: body, sac and eight
## legs). The legs move through parameters the avatar maps onto each leg by where it sits round the body
## (BroodMotherAvatar._pose_legs): gait_a_* / gait_b_* (the two alternating leg sets of its scuttle), legs_lift (every
## leg; + lifts the tips, - plants them hard), front_lift and back_lift (the front and back pairs), tuck (curled in
## under it, in the air), dig_l / dig_r (the front legs stabbing the ground). A spider, so it is quick and twitchy:
## a breathing sac and twitching legs when idle, a fast scuttle, the sac hoisted and swollen then whipped forward to
## fling each egg of the Egg Storm, a rearing spin spewing the Web Spiral, a coiled crouch, launch, tucked flight and
## splayed landing for the leap, a frantic dig and a nose-first dive for the burrow and a rearing eruption out of it,
## the sac swelling and heaving out the brood; drawn in tight under its hood when shielded; a flinch, a buckling
## stagger, a roar reared up on its back legs, a climb out of the ground and a curled-up death.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const UP := Vector3(0, 1, 0)
const FWD := Vector3(1, 0, 0)
const B := BossClip.BODY
const IO := BossClip.IN_OUT
const IN3 := BossClip.IN3
const OUT := BossClip.OUT
const OUT3 := BossClip.OUT3
const IN := BossClip.IN
const BACK := BossClip.BACK
const LIN := BossClip.LINEAR
const S := BossClip.SETTLE

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		for c: BossClip in [
			_idle(),
			_walk(),
			_marks(),
			_pattern(),
			_leap(),
			_burrow(),
			_brood(),
			_shielded(),
			_flinch(),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(&"sac", [[0, 0], [0.5, 0.05], [1, 0]])
	c.turn(&"sac", Z, [[0, 0.02], [0.5, -0.03], [1, 0.02]])
	c.shift(&"body", UP, [[0, 0], [0.5, 0.035], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.5, 0.03], [1, 0]])
	c.param(&"legs_lift", [[0, 0], [0.5, -0.05], [1, 0]])
	c.param(&"gait_a_lift", [[0, 0], [0.3, 0], [0.36, 0.14, OUT, S], [0.44, 0, IN], [1, 0]])
	c.param(&"gait_b_lift", [[0, 0], [0.78, 0], [0.84, 0.12, OUT, S], [0.92, 0, IN], [1, 0]])
	return c


## The scuttle: two leg sets lifting and reaching in turn, the body bobbing on each set's plant and the sac
## swinging behind.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.param(&"gait_a_lift", [[0, 0], [0.25, 0.34, OUT], [0.5, 0, IN], [1, 0]])
	c.param(&"gait_b_lift", [[0, 0], [0.5, 0], [0.75, 0.34, OUT], [1, 0, IN]])
	c.param(&"gait_a_swing", [[0, -0.24], [0.5, 0.24], [1, -0.24]])
	c.param(&"gait_b_swing", [[0, 0.24], [0.5, -0.24], [1, 0.24]])
	c.shift(&"body", UP, [[0, 0], [0.25, 0.05, OUT], [0.5, 0, IN], [0.75, 0.05, OUT], [1, 0, IN]])
	c.turn(&"body", X, [[0, 0.04], [0.5, -0.04], [1, 0.04]])
	c.turn(&"body", Z, [[0, -0.05], [1, -0.05]])
	c.turn(&"sac", Y, [[0, 0.06], [0.5, -0.06], [1, 0.06]])
	c.turn(&"sac", Z, [[0, 0.03], [0.25, -0.03], [0.5, 0.03], [0.75, -0.03], [1, 0.03]])
	return c


## The Egg Storm: it braces, lays (the sac dips and pumps: v0.8.0 BS1), hoists its swelling sac high over its back
## and whips it forward to fling an egg onto each marker (strike..hold is one fling: it swells again and flings
## again), then lets the sac sink back. The eggs then sit on the floor (BossSignatureViews).
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	var sac_turn := [
		[0, 0],
		[0.12, 0.12, OUT],
		[0.42, -0.45],
		[0.47, -0.5, OUT],
		[0.5, 0.25, IN3],
		[0.525, 0.35, OUT3, S],
		[0.57, -0.4],
		[0.62, 0.25, IN3],
		[0.78, 0.1],
		[1, 0],
	]
	c.turn(&"sac", Z, sac_turn)
	# v0.8.0 BS1 (S3, the eggs that stay): first it lays them: the sac dips to the floor and pumps twice, filling.
	c.shift(
		&"sac",
		UP,
		[
			[0, 0],
			[0.08, -0.12, OUT],
			[0.18, 0.03],
			[0.27, -0.1, OUT],
			[0.38, 0.06],
			[0.5, 0, IN3],
			[1, 0]
		]
	)
	c.stretch(
		&"sac",
		[
			[0, 0],
			[0.42, 0.24],
			[0.47, 0.28, OUT],
			[0.5, -0.12, IN3],
			[0.57, 0.2],
			[0.62, -0.12, IN3],
			[0.8, 0.0],
			[1, 0]
		]
	)
	c.turn(
		&"body",
		Z,
		[[0, 0], [0.42, 0.18], [0.5, -0.1, IN3], [0.57, 0.14], [0.62, -0.1, IN3], [1, 0]]
	)
	c.shift(
		&"body",
		UP,
		[
			[0, 0],
			[0.12, -0.08],
			[0.42, 0.1],
			[0.5, -0.06, IN3],
			[0.57, 0.08],
			[0.62, -0.06, IN3],
			[1, 0]
		]
	)
	c.param(
		&"front_lift",
		[[0, 0], [0.42, 0.45], [0.5, -0.1, IN3], [0.57, 0.3], [0.62, -0.1, IN3], [1, 0]]
	)
	c.param(&"legs_lift", [[0, 0], [0.12, -0.12], [0.62, -0.12], [1, 0]])
	c.param(
		&"tremble",
		[
			[0, 0],
			[0.49, 0],
			[0.5, 0.6, LIN],
			[0.55, 0],
			[0.61, 0],
			[0.62, 0.6, LIN],
			[0.68, 0],
			[1, 0]
		]
	)
	return c


## The Web Spiral: it rears up on its back legs with its front legs spread, then drops its head and jerks from side
## to side spewing the arms of globs, its sac pumping.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn(
		&"body",
		Z,
		[
			[0, 0],
			[0.4, 0.38, BACK],
			[0.5, -0.32, IN3],
			[0.53, -0.22],
			[0.62, -0.2],
			[0.85, 0.05],
			[1, 0]
		]
	)
	c.shift(
		&"body", UP, [[0, 0], [0.12, -0.06], [0.4, 0.2], [0.5, -0.16, IN3], [0.62, -0.1], [1, 0]]
	)
	c.param(&"front_lift", [[0, 0], [0.4, 0.95, BACK], [0.5, -0.3, IN3], [0.62, -0.2], [1, 0]])
	c.param(&"back_lift", [[0, 0], [0.4, -0.15], [0.62, -0.1], [1, 0]])
	c.turn(
		B,
		Y,
		[
			[0, 0],
			[0.4, -0.15],
			[0.5, 0.0, IN3],
			[0.53, 0.32],
			[0.56, -0.32],
			[0.59, 0.32],
			[0.62, 0.0],
			[1, 0]
		]
	)
	c.stretch(
		&"sac",
		[
			[0, 0],
			[0.4, 0.18],
			[0.5, -0.06],
			[0.53, 0.1],
			[0.56, -0.06],
			[0.59, 0.1],
			[0.62, -0.04],
			[1, 0]
		]
	)
	c.turn(&"sac", Z, [[0, 0], [0.4, -0.3], [0.5, 0.1, IN3], [0.62, 0.05], [1, 0]])
	return c


## The leap: a coiled crouch rocking back, the launch with every leg flung down (strike), tucked tight in the air
## (the active part, while it flies), a splayed squashing landing (hold), and it pushes back up with a bounce.
static func _leap() -> BossClip:
	var c := BossClip.new(&"leap")
	c.shift(
		&"body",
		UP,
		[
			[0, 0],
			[0.12, 0.06, OUT],
			[0.42, -0.34],
			[0.47, -0.38, OUT],
			[0.5, 0.18, IN3],
			[0.56, 0.05],
			[0.6, 0.0],
			[0.62, -0.32, IN3],
			[0.68, -0.36, OUT3, S],
			[0.82, 0.04, IO, S],
			[1, 0]
		]
	)
	c.turn(
		&"body",
		Z,
		[[0, 0], [0.42, 0.25], [0.5, -0.15, IN3], [0.56, 0.08], [0.62, -0.1, IN3], [1, 0]]
	)
	c.param(
		&"legs_lift",
		[
			[0, 0],
			[0.42, 0.3],
			[0.5, -0.35, IN3],
			[0.56, 0.0],
			[0.62, -0.3, IN3],
			[0.85, 0.05, IO, S],
			[1, 0]
		]
	)
	c.param(&"front_lift", [[0, 0], [0.42, 0.3], [0.5, 0.0, IN3], [1, 0]])
	c.param(&"tuck", [[0, 0], [0.5, 0], [0.54, 1.0, OUT3], [0.6, 0.85], [0.62, 0, IN3], [1, 0]])
	c.stretch(
		B,
		[
			[0, 0],
			[0.42, -0.08],
			[0.5, 0.14, IN3],
			[0.56, 0.04],
			[0.62, -0.18, IN3],
			[0.7, 0.04, OUT, S],
			[0.8, 0],
			[1, 0]
		]
	)
	c.stretch(
		&"sac",
		[[0, 0], [0.42, -0.06], [0.5, 0.08], [0.62, -0.1, IN3], [0.72, 0.06, OUT, S], [1, 0]]
	)
	return c


## The burrow: it stabs at the ground with its front legs in turn, nose dropping, then dives head first (strike) and
## is gone; it erupts rearing out of the ground with its legs flung wide (halfway..hold) and settles.
static func _burrow() -> BossClip:
	var c := BossClip.new(&"burrow")
	var dig_l := [[0, 0]]
	var dig_r := [[0, 0]]
	for k in 5:
		var t0 := 0.06 + 0.075 * k
		dig_l.append([t0, 0.65, OUT])
		dig_l.append([t0 + 0.035, -0.15, IN3])
		dig_r.append([t0 + 0.035, 0.65, OUT])
		dig_r.append([t0 + 0.07, -0.15, IN3])
	dig_l.append_array([[0.5, 0], [1, 0]])
	dig_r.append_array([[0.5, 0], [1, 0]])
	c.param(&"dig_l", dig_l)
	c.param(&"dig_r", dig_r)
	c.turn(
		&"body",
		Z,
		[
			[0, 0],
			[0.42, -0.25],
			[0.5, -0.65, IN3],
			[0.56, -0.65],
			[0.6, 0.5, OUT3],
			[0.62, 0.42],
			[0.82, -0.05, IO, S],
			[1, 0]
		]
	)
	c.shift(
		&"body",
		UP,
		[
			[0, 0],
			[0.42, -0.14],
			[0.5, -0.45, IN3],
			[0.56, -0.5],
			[0.6, 0.3, OUT3],
			[0.62, 0.25],
			[1, 0]
		]
	)
	c.stretch(
		B,
		[
			[0, 0],
			[0.5, 0.12, IN3],
			[0.56, 0.12],
			[0.6, 0.16, OUT3],
			[0.66, -0.08, IO, S],
			[0.8, 0],
			[1, 0]
		]
	)
	c.param(
		&"legs_lift",
		[
			[0, 0],
			[0.5, 0.2],
			[0.56, 0.2],
			[0.6, 0.55, OUT3],
			[0.62, 0.5],
			[0.82, -0.1, IO, S],
			[1, 0]
		]
	)
	c.param(
		&"tremble",
		[[0, 0], [0.3, 0], [0.46, 0.5], [0.5, 0], [0.58, 0], [0.6, 1, LIN], [0.7, 0], [1, 0]]
	)
	return c


## The brood: the sac swells huge and settles to the ground behind it, the body lifting its head, then the sac
## heaves (strike) and shudders as the hatchlings spill out.
static func _brood() -> BossClip:
	var c := BossClip.new(&"brood")
	c.stretch(
		&"sac",
		[
			[0, 0],
			[0.42, 0.32, BACK],
			[0.47, 0.36, OUT],
			[0.5, -0.16, IN3],
			[0.53, 0.06, OUT3, S],
			[0.56, -0.08],
			[0.62, -0.06],
			[0.85, 0.02],
			[1, 0]
		]
	)
	c.turn(&"sac", Z, [[0, 0], [0.42, 0.3], [0.5, 0.12, IN3], [0.62, 0.15], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, 0.2], [0.5, 0.05, IN3], [0.62, 0.08], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, 0.08], [0.5, -0.1, IN3], [0.62, -0.06], [1, 0]])
	c.param(&"legs_lift", [[0, 0], [0.42, -0.1], [0.5, -0.2, IN3], [0.62, -0.15], [1, 0]])
	c.param(
		&"tremble", [[0, 0], [0.36, 0], [0.47, 0.4], [0.5, 1, LIN], [0.62, 0.5], [0.7, 0], [1, 0]]
	)
	return c


## Shielded: it draws in tight under its hood, legs folded close, sac pulled in.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"body", Z, [[0, 0], [0.7, -0.24, BACK], [1, -0.2]])
	c.shift(&"body", UP, [[0, 0], [0.7, -0.28, BACK], [1, -0.25]])
	c.param(&"tuck", [[0, 0], [0.7, 0.35, BACK], [1, 0.3]])
	c.stretch(&"sac", [[0, 0], [0.7, -0.08], [1, -0.06]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"body", Z, [[0, 0], [0.15, 0.18, OUT3], [0.5, -0.05, IO, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.12, OUT3], [1, 0]])
	c.param(&"legs_lift", [[0, 0], [0.15, 0.18, OUT3], [1, 0]])
	c.stretch(&"sac", [[0, 0], [0.15, -0.06, OUT3], [0.5, 0.03, IO, S], [1, 0]])
	return c


## Staggered: its legs buckle and splay, the body drops and tips, the sac sags.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.param(&"legs_lift", [[0, 0], [0.1, 0.4, OUT3], [0.4, -0.3], [1, -0.28]])
	c.shift(&"body", UP, [[0, 0], [0.1, 0.1, OUT3], [0.4, -0.32], [1, -0.3]])
	c.turn(&"body", X, [[0, 0], [0.4, 0.16], [1, 0.14]])
	c.turn(&"body", Z, [[0, 0], [0.1, 0.2], [0.4, -0.12], [1, -0.1]])
	c.turn(&"sac", Z, [[0, 0], [0.4, 0.28], [1, 0.26]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The phase gate's roar: it rears up on its back legs, front legs raised and spread, sac swollen high, shaking.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"body", Z, [[0, 0], [0.2, -0.12], [0.36, 0.55, BACK], [0.85, 0.5], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.2, -0.15], [0.36, 0.25, BACK], [0.85, 0.22], [1, 0]])
	c.param(&"front_lift", [[0, 0], [0.2, -0.1], [0.36, 1.2, BACK], [0.85, 1.1], [1, 0]])
	c.param(&"back_lift", [[0, 0], [0.36, -0.2], [0.85, -0.2], [1, 0]])
	c.turn(&"sac", Z, [[0, 0], [0.36, -0.28], [0.85, -0.25], [1, 0]])
	c.stretch(&"sac", [[0, 0], [0.36, 0.22, BACK], [0.85, 0.2], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise-in: its front legs reach up out of the ground first, it hauls itself out reared up, then slams its
## front legs down and settles.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.turn(&"body", Z, [[0, 0.45], [0.5, 0.45], [0.64, -0.12, IN3], [0.74, 0.04, OUT, S], [1, 0]])
	c.param(&"front_lift", [[0, 1.0], [0.5, 1.0], [0.64, -0.2, IN3], [0.8, 0], [1, 0]])
	c.shift(&"body", UP, [[0, 0.1], [0.5, 0.12], [0.64, -0.18, IN3], [0.74, 0.02, OUT, S], [1, 0]])
	c.stretch(B, [[0, 0], [0.5, 0], [0.64, -0.14, IN3], [0.72, 0.04, OUT, S], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 1, LIN], [0.74, 0], [1, 0]])
	return c


## Its death: it jerks up, its legs curl in under it as the body drops to the ground and rolls, the sac deflates,
## and it sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.shift(
		&"body",
		UP,
		[
			[0, 0],
			[0.15, 0.15, OUT3],
			[0.5, -0.65, IN],
			[0.56, -0.58, OUT, S],
			[0.62, -0.65],
			[1, -0.65]
		]
	)
	c.param(&"tuck", [[0, 0], [0.15, 0.3], [0.5, 1.1], [1, 1.2]])
	c.turn(B, X, [[0, 0], [0.3, 0.05], [0.6, 0.35, IN], [0.68, 0.3, OUT, S], [1, 0.35]])
	c.turn(&"body", Z, [[0, 0], [0.15, 0.25, OUT3], [0.5, -0.15], [1, -0.15]])
	c.stretch(&"sac", [[0, 0], [0.15, 0.1], [0.7, -0.35], [1, -0.4]])
	c.shift(B, UP, [[0, 0], [0.84, 0], [1, -2.4, IN]])
	return c
