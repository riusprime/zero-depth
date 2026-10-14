class_name SiegeEngineClips
extends RefCounted
## v0.8.0 BA: the Siege Engine's clips (the owner's Fortress Turret, rigged in code by BossRig: hull, cannon,
## mortar_l/r and four legs of a thigh and a shin). The legs move through parameters the avatar maps onto them
## (SiegeEngineAvatar._pose_legs): gait_a_* (front left and back right) and gait_b_* (front right and back left) for
## the walk, squat (every thigh splayed out under the lowered hull), front_kneel and back_kneel (a pair bent),
## front_lift (the front pair raised off the ground). A walking fortress, so it is mechanical and heavy: an idling
## engine and a scanning cannon, a plodding walk in diagonal pairs, braced low and kicking with each volley as its
## turret turns for the Turret Cross (shielded, hunkered), the mortar tubes cranked up and thumping for the Mortar
## Grid and the Barrage (once per marker), kneeling with the cannon levelled and a huge recoil for the Rail, squatting
## flat to drop its turrets, rearing up and stamping down for the shockwave; a jolt, a buckling stagger, a roar with
## its cannon raised to the sky and its mortars firing, unfolding out of the ground, and a collapse onto its belly.

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
			_grid(),
			_marks(),
			_lanes(),
			_deploy(),
			_slam_ring(),
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
	c.shift(
		&"hull",
		UP,
		[
			[0, 0],
			[0.125, 0.012],
			[0.25, 0],
			[0.375, 0.012],
			[0.5, 0],
			[0.625, 0.012],
			[0.75, 0],
			[0.875, 0.012],
			[1, 0]
		]
	)
	c.turn(&"cannon", Z, [[0, 0], [0.5, 0.06], [1, 0]])
	c.turn(&"cannon", Y, [[0, 0.08], [0.5, -0.08], [1, 0.08]])
	c.turn_pair(&"mortar_l", &"mortar_r", Z, [[0, 0], [0.5, -0.05], [1, 0]])
	c.turn(&"hull", Z, [[0, 0], [0.5, 0.015], [1, 0]])
	return c


## The plod: the diagonal pairs lift and reach in turn, the hull bobs and rolls toward the planted pair, the cannon
## nods with each step.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.param(&"gait_a_lift", [[0, 0], [0.25, 0.32, OUT], [0.5, 0, IN], [1, 0]])
	c.param(&"gait_b_lift", [[0, 0], [0.5, 0], [0.75, 0.32, OUT], [1, 0, IN]])
	c.param(&"gait_a_swing", [[0, -0.18], [0.5, 0.18], [1, -0.18]])
	c.param(&"gait_b_swing", [[0, 0.18], [0.5, -0.18], [1, 0.18]])
	c.shift(
		&"hull",
		UP,
		[[0, 0.04], [0.25, -0.02, IN], [0.5, 0.04, OUT], [0.75, -0.02, IN], [1, 0.04, OUT]]
	)
	c.turn(&"hull", X, [[0, 0], [0.25, 0.04], [0.5, 0], [0.75, -0.04], [1, 0]])
	c.turn(&"cannon", Z, [[0, 0], [0.3, -0.04], [0.5, 0], [0.8, -0.04], [1, 0]])
	return c


## The Turret Cross: it squats wide and braces, cannon up; on the strike it kicks back and keeps kicking with each
## volley while the hull turns the cross round, then swings back and stands.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.param(&"squat", [[0, 0], [0.4, 0.9, BACK], [0.62, 0.9], [0.85, 0.3], [1, 0]])
	c.shift(
		&"hull",
		UP,
		[[0, 0], [0.4, -0.22, BACK], [0.5, -0.28, IN3], [0.62, -0.24], [0.85, -0.05], [1, 0]]
	)
	c.turn(&"cannon", Z, [[0, 0], [0.4, 0.22], [0.62, 0.22], [1, 0]])
	var kick := [[0, 0], [0.49, 0], [0.5, -0.42, IN3], [0.515, -0.1]]
	for k in 4:
		var t0 := 0.53 + 0.022 * k
		kick.append([t0, -0.4, IN3])
		kick.append([t0 + 0.012, -0.1])
	kick.append_array([[0.62, 0.0], [1, 0]])
	c.shift(&"cannon", FWD, kick)
	c.turn(
		&"hull",
		Z,
		[
			[0, 0],
			[0.49, 0],
			[0.5, 0.08, IN3],
			[0.515, 0.02],
			[0.53, 0.07],
			[0.545, 0.02],
			[0.575, 0.07],
			[0.59, 0.02],
			[0.62, 0],
			[1, 0]
		]
	)
	c.turn(&"hull", Y, [[0, 0], [0.5, 0, IN3], [0.62, 0.7, LIN], [0.8, 0.7], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.7, LIN], [0.62, 0.4], [0.66, 0], [1, 0]])
	return c


## The Mortar Grid: back legs kneel and the hull tips back as the tubes crank up, then two thumping volleys.
static func _grid() -> BossClip:
	var c := BossClip.new(&"grid")
	c.param(&"back_kneel", [[0, 0], [0.4, 0.7, BACK], [0.62, 0.7], [1, 0]])
	c.turn(
		&"hull", Z, [[0, 0], [0.4, 0.14], [0.5, 0.06, IN3], [0.56, 0.14], [0.62, 0.06, IN3], [1, 0]]
	)
	c.turn_pair(
		&"mortar_l",
		&"mortar_r",
		Z,
		[
			[0, 0],
			[0.4, -0.7, BACK],
			[0.47, -0.75],
			[0.5, -0.45, IN3],
			[0.56, -0.72],
			[0.62, -0.45, IN3],
			[0.85, -0.2],
			[1, 0]
		]
	)
	c.shift(
		&"mortar_l",
		UP,
		[
			[0, 0],
			[0.49, 0],
			[0.5, -0.2, IN3],
			[0.56, 0],
			[0.61, 0],
			[0.62, -0.2, IN3],
			[0.7, 0],
			[1, 0]
		]
	)
	c.shift(
		&"mortar_r",
		UP,
		[
			[0, 0],
			[0.49, 0],
			[0.5, -0.2, IN3],
			[0.56, 0],
			[0.61, 0],
			[0.62, -0.2, IN3],
			[0.7, 0],
			[1, 0]
		]
	)
	c.shift(
		&"hull",
		UP,
		[[0, 0], [0.4, -0.1], [0.5, -0.2, IN3], [0.56, -0.1], [0.62, -0.2, IN3], [1, 0]]
	)
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


## The Barrage: the tubes crank up toward the marker and thump, cranking up again for each marker.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	c.turn_pair(
		&"mortar_l",
		&"mortar_r",
		Z,
		[
			[0, 0],
			[0.4, -0.55, BACK],
			[0.5, -0.25, IN3],
			[0.565, -0.55],
			[0.62, -0.25, IN3],
			[0.85, -0.1],
			[1, 0]
		]
	)
	c.shift(
		&"mortar_l",
		FWD,
		[
			[0, 0],
			[0.49, 0],
			[0.5, -0.18, IN3],
			[0.565, 0],
			[0.61, 0],
			[0.62, -0.18, IN3],
			[0.7, 0],
			[1, 0]
		]
	)
	c.shift(
		&"mortar_r",
		FWD,
		[
			[0, 0],
			[0.49, 0],
			[0.5, -0.18, IN3],
			[0.565, 0],
			[0.61, 0],
			[0.62, -0.18, IN3],
			[0.7, 0],
			[1, 0]
		]
	)
	c.turn(
		&"hull", Z, [[0, 0], [0.4, 0.1], [0.5, 0.0, IN3], [0.565, 0.1], [0.62, 0.0, IN3], [1, 0]]
	)
	c.shift(
		&"hull",
		UP,
		[[0, 0], [0.4, -0.06], [0.5, -0.16, IN3], [0.565, -0.06], [0.62, -0.16, IN3], [1, 0]]
	)
	c.param(&"back_kneel", [[0, 0], [0.4, 0.35], [0.62, 0.35], [1, 0]])
	c.param(
		&"tremble",
		[
			[0, 0],
			[0.49, 0],
			[0.5, 0.5, LIN],
			[0.55, 0],
			[0.61, 0],
			[0.62, 0.5, LIN],
			[0.68, 0],
			[1, 0]
		]
	)
	return c


## The Rail: it kneels on its front legs with the cannon levelled, straining as the charge builds, then the shot
## throws it back on its haunches.
static func _lanes() -> BossClip:
	var c := BossClip.new(&"lanes")
	c.param(&"front_kneel", [[0, 0], [0.4, 0.7, BACK], [0.5, 0.2, IN3], [0.62, 0.3], [1, 0]])
	c.turn(
		&"hull",
		Z,
		[[0, 0], [0.4, -0.12], [0.5, 0.2, IN3], [0.54, 0.26, OUT3, S], [0.62, 0.12], [1, 0]]
	)
	c.shift(&"hull", FWD, [[0, 0], [0.4, 0.08], [0.5, -0.3, IN3], [0.62, -0.18], [1, 0]])
	c.shift(&"hull", UP, [[0, 0], [0.4, -0.16], [0.5, -0.05, IN3], [0.62, -0.1], [1, 0]])
	c.shift(
		&"cannon",
		FWD,
		[[0, 0], [0.4, 0.12], [0.49, 0.15], [0.5, -0.55, IN3], [0.56, -0.35], [0.62, -0.2], [1, 0]]
	)
	c.turn(&"cannon", Z, [[0, 0], [0.4, -0.06], [0.5, 0.15, IN3], [0.62, 0.05], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.49, 0], [0.5, -0.25, IN3], [0.62, -0.2], [1, 0]])
	c.param(
		&"tremble", [[0, 0], [0.25, 0], [0.48, 0.7], [0.5, 1, LIN], [0.62, 0.3], [0.7, 0], [1, 0]]
	)
	return c


## The deploy: it squats flat with its mortars spread, then the hull pops as its turrets drop out.
static func _deploy() -> BossClip:
	var c := BossClip.new(&"deploy")
	c.param(&"squat", [[0, 0], [0.42, 1.2, BACK], [0.62, 1.1], [1, 0]])
	c.shift(
		&"hull",
		UP,
		[[0, 0], [0.42, -0.4, BACK], [0.5, -0.2, IN3], [0.55, -0.36], [0.62, -0.34], [1, 0]]
	)
	c.turn(&"mortar_l", X, [[0, 0], [0.42, 0.35], [0.62, 0.35], [1, 0]])
	c.turn(&"mortar_r", X, [[0, 0], [0.42, -0.35], [0.62, -0.35], [1, 0]])
	c.stretch(&"hull", [[0, 0], [0.42, -0.04], [0.5, 0.08, IN3], [0.56, 0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.6, LIN], [0.58, 0], [1, 0]])
	return c


## The shockwave: it rears up on its back legs, front legs raised, then stamps down with its whole weight.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.param(
		&"front_lift",
		[[0, 0], [0.12, -0.1], [0.42, 1.0, BACK], [0.5, -0.15, IN3], [0.62, -0.1], [1, 0]]
	)
	c.param(&"back_kneel", [[0, 0], [0.42, 0.3], [0.5, 0.0, IN3], [1, 0]])
	c.turn(
		B,
		Z,
		[
			[0, 0],
			[0.12, -0.04],
			[0.42, 0.3, BACK],
			[0.5, -0.06, IN3],
			[0.54, -0.1, OUT3, S],
			[0.62, -0.05],
			[1, 0]
		]
	)
	c.shift(B, UP, [[0, 0], [0.42, 0.1], [0.5, -0.18, IN3], [0.62, -0.12], [1, 0]])
	c.stretch(
		B, [[0, 0], [0.42, 0.05], [0.5, -0.12, IN3], [0.56, 0.03, OUT, S], [0.62, -0.04], [1, 0]]
	)
	c.turn(&"cannon", Z, [[0, 0], [0.42, 0.25], [0.5, -0.2, IN3], [0.62, -0.1], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.6, 0], [1, 0]])
	return c


## Shielded: hunkered right down on splayed legs, cannon lowered, mortars pulled in.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.param(&"squat", [[0, 0], [0.7, 1.05, BACK], [1, 1.0]])
	c.shift(&"hull", UP, [[0, 0], [0.7, -0.34, BACK], [1, -0.3]])
	c.turn(&"cannon", Z, [[0, 0], [0.7, -0.16], [1, -0.14]])
	c.shift(&"mortar_l", UP, [[0, 0], [0.7, -0.12], [1, -0.12]])
	c.shift(&"mortar_r", UP, [[0, 0], [0.7, -0.12], [1, -0.12]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"hull", Z, [[0, 0], [0.15, 0.1, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.shift(&"cannon", FWD, [[0, 0], [0.15, -0.12, OUT3], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.1, OUT3], [1, 0]])
	return c


## Staggered: its left legs buckle, the hull lurches over and its cannon droops.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(B, X, [[0, 0], [0.1, -0.08, OUT3], [0.4, 0.18], [1, 0.16]])
	c.param(&"squat", [[0, 0], [0.4, 0.5], [1, 0.45]])
	c.shift(&"hull", UP, [[0, 0], [0.1, 0.06], [0.4, -0.2], [1, -0.18]])
	c.turn(&"hull", Z, [[0, 0], [0.1, 0.12], [0.4, -0.1], [1, -0.1]])
	c.turn(&"cannon", Z, [[0, 0], [0.4, -0.28], [1, -0.26]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The phase gate's roar: it rears up, the cannon raised to the sky, and its mortars fire three times.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.param(&"front_lift", [[0, 0], [0.2, -0.1], [0.36, 0.9, BACK], [0.85, 0.85], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.2, -0.05], [0.36, 0.3, BACK], [0.85, 0.28], [1, 0]])
	c.turn(&"cannon", Z, [[0, 0], [0.36, 0.6, BACK], [0.85, 0.55], [1, 0]])
	var tube := [[0, 0], [0.36, 0]]
	for k in 3:
		var t0 := 0.42 + 0.13 * k
		tube.append([t0, -0.2, IN3])
		tube.append([t0 + 0.06, 0.0])
	tube.append([1, 0])
	c.shift(&"mortar_l", UP, tube)
	c.shift(&"mortar_r", UP, tube)
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise-in: it comes up folded, legs splayed, and unfolds to stand with a stamp.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.param(&"squat", [[0, 1.3], [0.5, 1.2], [0.64, -0.1, IN3], [0.74, 0.05, OUT, S], [1, 0]])
	c.shift(
		&"hull", UP, [[0, -0.35], [0.5, -0.3], [0.64, 0.08, IN3], [0.74, -0.03, OUT, S], [1, 0]]
	)
	c.turn(&"cannon", Z, [[0, -0.2], [0.5, -0.2], [0.66, 0.3, BACK], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 1, LIN], [0.74, 0], [1, 0]])
	return c


## Its death: its legs give way outward, the hull crashes onto its belly tipping forward, the cannon droops, it
## rocks once, and sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.param(&"squat", [[0, 0], [0.15, 0.3], [0.55, 2.0, IN], [1, 2.1]])
	c.shift(
		&"hull",
		UP,
		[[0, 0], [0.15, 0.05], [0.55, -0.8, IN], [0.62, -0.7, OUT, S], [0.7, -0.8], [1, -0.8]]
	)
	c.turn(
		B,
		Z,
		[[0, 0], [0.15, 0.08], [0.55, -0.22, IN], [0.62, -0.16, OUT, S], [0.7, -0.22], [1, -0.22]]
	)
	c.turn(B, X, [[0, 0], [0.55, 0.12], [1, 0.12]])
	c.turn(&"cannon", Z, [[0, 0], [0.15, 0.2], [0.6, -0.5], [1, -0.55]])
	c.shift(B, UP, [[0, 0], [0.84, 0], [1, -2.4, IN]])
	c.param(&"tremble", [[0, 0], [0.54, 0], [0.56, 1, LIN], [0.68, 0], [1, 0]])
	return c
