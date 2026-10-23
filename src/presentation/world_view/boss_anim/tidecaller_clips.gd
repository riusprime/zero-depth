class_name TidecallerClips
extends RefCounted
## v0.9.0 NB1: the Tidecaller's clips (the owner's hunched sea priest, cut into parts in its file: body, staff with the
## bell hanging from it, the reaching left arm, the back shell; BossModels rigs each as a bone). Model frame: +X the
## front, +Z its right (the staff), -Z its left (the reaching arm). Parameters the avatar maps: ring (the bell's swing,
## added to what the tide drives) and glow (the shell's and the mask's light). A heavy, slow figure: it breathes
## under its shell when idle and plods leaning on its staff; for the Pull it lifts the staff high and the bell rings
## through the windup, then it plants the staff and holds, arm out, while the tide runs (the avatar swings the bell and
## pulses the shell from the sim's tide); for the Tide Rings its shell swells and bursts out a ring; for the Undertow
## its arm reaches at the circle and drags back on the strike; for the Shell Slam it hunches and slams its shell down.
## A jolt, a dazed sway, a roar with the arm thrown wide, rising out of the water, and a collapse forward.

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
const BACK := BossClip.BACK
const LIN := BossClip.LINEAR
const S := BossClip.SETTLE

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		for c: BossClip in [
			_idle(),
			_walk(),
			_tide(),
			_pattern(),
			_marks(),
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


## Breathing under the shell: the body swells and settles, the shell lifts a little after it, the bell sways.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(&"body", [[0, 0], [0.5, 0.025], [1, 0]])
	c.stretch(&"shell", [[0, 0], [0.6, 0.03], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0.05], [0.5, 0.12], [1, 0.05]])
	c.turn(&"bell", X, [[0, 0.06], [0.5, -0.06], [1, 0.06]])
	c.param(&"glow", [[0, 0], [0.5, 0.25], [1, 0]])
	return c


## The plod: it leans on the staff (planted as the body rolls over it), bobbing, the arm and the bell swinging.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.shift(&"body", UP, [[0, 0], [0.25, 0.05, OUT], [0.5, 0, IO], [0.75, 0.05, OUT], [1, 0, IO]])
	c.turn(&"body", X, [[0, 0.05], [0.5, -0.05], [1, 0.05]])
	c.turn(&"body", Z, [[0, -0.06], [1, -0.06]])
	c.turn(&"staff", Z, [[0, 0.14], [0.5, -0.14], [1, 0.14]])
	c.turn(&"arm_l", Z, [[0, -0.12], [0.5, 0.18], [1, -0.12]])
	c.turn(&"bell", X, [[0, 0.12], [0.5, -0.12], [1, 0.12]])
	return c


## The Pull: the staff rises high over its head and the bell rings harder and harder through the windup; on the strike
## it plants the staff, the arm thrown out, and holds through the tide (the avatar adds the tide's own swing).
static func _tide() -> BossClip:
	var c := BossClip.new(&"tide")
	c.turn(&"staff", X, [[0, 0], [0.42, 0.35, BACK], [0.5, 0.05, IN3], [0.62, 0.08], [1, 0]])
	c.shift(&"staff", UP, [[0, 0], [0.42, 0.45, BACK], [0.5, -0.05, IN3], [0.62, 0], [1, 0]])
	var ring := [[0, 0]]
	for k in 6:
		var t0 := 0.06 + 0.06 * k
		ring.append([t0, 0.35 + 0.08 * k, OUT])
		ring.append([t0 + 0.03, -0.35 - 0.08 * k, OUT])
	ring.append_array([[0.5, 0.0, IN3], [1, 0]])
	c.param(&"ring", ring)
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.3], [0.5, 0.75, IN3], [0.62, 0.7], [0.85, 0.2], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.42, 0.2], [0.5, 0.5, IN3], [0.62, 0.45], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, 0.12], [0.5, -0.08, IN3], [0.62, -0.05], [1, 0]])
	c.shift(
		&"body",
		UP,
		[[0, 0], [0.42, 0.1], [0.5, -0.12, IN3], [0.54, -0.15, OUT3, S], [0.62, -0.1], [1, 0]]
	)
	c.param(&"glow", [[0, 0], [0.42, 1.0], [0.5, 1.6, IN3], [0.62, 1.3], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.48, 0], [0.5, 0.7, LIN], [0.56, 0], [1, 0]])
	return c


## The Tide Rings: the shell swells as it draws breath, then bursts out with each ring (strike), the body rocking.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.stretch(
		&"shell",
		[[0, 0], [0.42, 0.14, BACK], [0.5, -0.06, IN3], [0.56, 0.08, OUT, S], [0.62, 0], [1, 0]]
	)
	c.turn(&"body", Z, [[0, 0], [0.42, 0.14], [0.5, -0.1, IN3], [0.62, -0.04], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, 0.06], [0.5, -0.04, IN3], [0.62, 0], [1, 0]])
	c.turn(&"bell", X, [[0, 0], [0.42, 0.2], [0.5, -0.3, IN3], [0.62, 0.15], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.8], [0.5, 1.4, IN3], [0.62, 0.6], [1, 0]])
	return c


## The Undertow: the long arm reaches toward the circle, fingers spread, then yanks back as it strikes (and drags).
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	c.turn(
		&"arm_l",
		Z,
		[
			[0, 0],
			[0.42, 0.95, BACK],
			[0.5, -0.25, IN3],
			[0.56, -0.35, OUT3, S],
			[0.62, -0.2],
			[1, 0]
		]
	)
	c.shift(&"arm_l", FWD, [[0, 0], [0.42, 0.2], [0.5, -0.1, IN3], [0.62, 0], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, -0.14], [0.5, 0.1, IN3], [0.62, 0.04], [1, 0]])
	c.turn(&"body", Y, [[0, 0], [0.42, -0.12], [0.5, 0.06, IN3], [0.62, 0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.6], [0.5, 1.0, IN3], [0.62, 0.4], [1, 0]])
	return c


## The Shell Slam: it hunches forward over its shell, then throws its weight down, the shell slamming the floor.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.turn(
		&"body",
		Z,
		[[0, 0], [0.42, 0.18], [0.5, -0.42, IN3], [0.54, -0.48, OUT3, S], [0.62, -0.4], [1, 0]]
	)
	c.shift(
		&"body", UP, [[0, 0], [0.42, 0.14], [0.5, -0.3, IN3], [0.62, -0.25], [0.8, -0.05], [1, 0]]
	)
	c.stretch(
		&"shell", [[0, 0], [0.42, 0.06], [0.5, -0.1, IN3], [0.56, 0.05, OUT, S], [0.62, 0], [1, 0]]
	)
	c.turn(&"staff", Z, [[0, 0], [0.42, 0.3], [0.5, -0.35, IN3], [0.62, -0.3], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.04], [0.5, -0.08, IN3], [0.62, -0.04], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.6, 0], [1, 0]])
	return c


## The shielded hold (the Pull): hunched under its shell, the shell swollen and glowing.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"body", Z, [[0, 0], [1, -0.1]])
	c.stretch(&"shell", [[0, 0], [1, 0.06]])
	c.param(&"glow", [[0, 0], [1, 0.8]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"body", Z, [[0, 0], [0.15, 0.16, OUT3], [0.5, -0.04, IO, S], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.15, -0.3, OUT3], [1, 0]])
	c.turn(&"bell", X, [[0, 0], [0.15, 0.4, OUT3], [0.5, -0.2, IO, S], [1, 0]])
	return c


static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"body", Z, [[0, 0], [0.2, -0.25, OUT3], [1, -0.2]])
	c.shift(&"body", UP, [[0, 0], [0.2, -0.18, OUT3], [1, -0.15]])
	c.turn(&"staff", Z, [[0, 0], [0.2, 0.4, OUT3], [1, 0.3]])
	c.turn(&"arm_l", Z, [[0, 0], [0.2, -0.4, OUT3], [1, -0.35]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"glow", [[0, 0], [0.2, -0.6], [1, -0.6]])
	return c


## The phase gate's roar: it rears back, the arm and the staff thrown wide, the shell blazing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"body", Z, [[0, 0], [0.3, 0.3, BACK], [0.8, 0.25], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.3, 0.9, BACK], [0.8, 0.8], [1, 0]])
	c.turn(&"staff", X, [[0, 0], [0.3, -0.4, BACK], [0.8, -0.35], [1, 0]])
	c.stretch(&"shell", [[0, 0], [0.3, 0.12], [0.8, 0.1], [1, 0]])
	c.param(&"glow", [[0, 0], [0.3, 1.8], [0.8, 1.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.8], [0.8, 0.8], [1, 0]])
	return c


## Rising out of the water: from sunk and hunched to upright, the shell last.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -1.6], [0.55, -0.2, OUT3], [0.8, 0.05, OUT, S], [1, 0]])
	c.turn(&"body", Z, [[0, -0.4], [0.6, -0.1], [1, 0]])
	c.stretch(&"shell", [[0, -0.2], [0.7, 0.08, BACK], [1, 0]])
	return c


## The collapse: it sags forward over its staff, the staff tipping away, and sinks under its shell.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(&"body", Z, [[0, 0], [0.3, 0.12], [0.8, -0.7, IN3], [1, -0.75]])
	c.shift(B, UP, [[0, 0], [0.3, 0.05], [0.85, -0.7, IN3], [1, -0.9]])
	c.turn(&"staff", X, [[0, 0], [0.4, -0.2], [0.9, -0.9, IN3], [1, -1.0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.4, 0.3], [1, -0.6]])
	c.param(&"glow", [[0, 0], [0.3, 1.0], [1, -1.0]])
	return c
