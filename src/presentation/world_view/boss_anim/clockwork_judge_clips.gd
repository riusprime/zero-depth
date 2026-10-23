class_name ClockworkJudgeClips
extends RefCounted
## v0.9.0 NB3: the Clockwork Judge's clips (the owner's tall brass automaton, cut into parts in its file since its
## skeleton is broken: body, the two pendulum arms with their gavels hanging from the shoulders, the waist gear cage,
## the chest clock's hour and minute hands; BossModels rigs each as a bone). Model frame: +X the front, +Z its right,
## -Z its left. A turn about Z swings an arm forward (+) or back (-) like a pendulum; the gears and the hands turn
## about X (the clock faces front). Parameters the avatar maps: glow (the lens eye's and the clock's light), tick (the
## hands' extra sweep) and spin (the gears' extra turn). A rigid, solemn figure: it stands upright with its arms
## swinging like pendulums at rest and walks stiffly, the arms counter-swinging; for the echo it spreads both arms wide
## and leans back while the clock spins (it stays so through the replay); for the Gear Spiral it braces, arms out to
## the sides, the gears racing; for the Verdict it hauls its right gavel up and back, then swings it down onto the
## square; for the Gavel Slam it raises both and brings them down together. A jolt, a stalled sway, a chiming roar
## with the arms flung up, rising stiffly upright out of its base, and a collapse forward as the gears run down.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const UP := Vector3(0, 1, 0)
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
			_echo(),
			_pattern(),
			_verdict(),
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


## Standing: the pendulum arms swing a little, opposite each other, the body breathing a hair, the gears ticking.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(&"body", [[0, 0], [0.5, 0.012], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0.1, IO], [0.5, -0.1, IO], [1, 0.1]])
	c.turn(&"arm_r", Z, [[0, -0.1, IO], [0.5, 0.1, IO], [1, -0.1]])
	c.param(&"glow", [[0, 0], [0.5, 0.2], [1, 0]])
	return c


## The stiff walk: a short bob, a slight roll, the arms counter-swinging like pendulums.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.shift(&"body", UP, [[0, 0], [0.25, 0.04, OUT], [0.5, 0, IO], [0.75, 0.04, OUT], [1, 0, IO]])
	c.turn(&"body", X, [[0, 0.03], [0.5, -0.03], [1, 0.03]])
	c.turn(&"arm_l", Z, [[0, 0.3, IO], [0.5, -0.3, IO], [1, 0.3]])
	c.turn(&"arm_r", Z, [[0, -0.3, IO], [0.5, 0.3, IO], [1, -0.3]])
	c.param(&"spin", [[0, 0.3], [1, 0.3]])
	return c


## The echo: it spreads both arms wide (out to the sides) and leans back as the clock races through the windup; it
## holds there, gears whirring, while the ghosts replay your path.
static func _echo() -> BossClip:
	var c := BossClip.new(&"echo")
	c.turn(&"arm_r", X, [[0, 0], [0.42, -0.9, BACK], [0.5, -1.0, IN3], [0.85, -0.95], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.9, BACK], [0.5, 1.0, IN3], [0.85, 0.95], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, -0.12], [0.5, -0.15, IN3], [0.85, -0.12], [1, 0]])
	c.param(&"tick", [[0, 0], [0.42, 2.5, IN3], [0.5, 3.0], [0.85, 2.5], [1, 0]])
	c.param(&"spin", [[0, 0], [0.42, 1.5], [0.5, 2.0], [0.85, 1.5], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 1.2], [0.5, 1.6, IN3], [0.85, 1.2], [1, 0]])
	return c


## The Gear Spiral: it braces, arms out to the sides and a little forward, the gears racing as the sparks pour out.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn(&"arm_r", X, [[0, 0], [0.42, -0.7, BACK], [0.5, -0.8, IN3], [0.85, -0.75], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.7, BACK], [0.5, 0.8, IN3], [0.85, 0.75], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.42, 0.25], [0.85, 0.25], [1, 0]])
	c.turn(&"arm_r", Z, [[0, 0], [0.42, 0.25], [0.85, 0.25], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, -0.05], [0.5, 0.03, IN3], [0.85, 0], [1, 0]])
	c.param(&"spin", [[0, 0], [0.42, 1.0], [0.5, 3.0, IN3], [0.85, 2.5], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.7], [0.5, 1.2, IN3], [0.85, 0.8], [1, 0]])
	return c


## The Verdict: the right gavel hauled up and back over the shoulder through the windup, then swung down and through
## onto the square as it strikes, the body following the swing.
static func _verdict() -> BossClip:
	var c := BossClip.new(&"verdict")
	c.turn(
		&"arm_r",
		Z,
		[[0, 0], [0.42, -2.3, BACK], [0.5, 1.3, IN3], [0.55, 1.5, OUT3, S], [0.7, 1.1], [1, 0]]
	)
	c.turn(&"arm_l", Z, [[0, 0], [0.42, 0.35], [0.5, -0.3, IN3], [0.7, -0.15], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, 0.12], [0.5, -0.22, IN3], [0.6, -0.18], [1, 0]])
	c.turn(&"body", Y, [[0, 0], [0.42, -0.15], [0.5, 0.1, IN3], [0.7, 0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.8], [0.5, 1.5, IN3], [0.62, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.8, LIN], [0.58, 0], [1, 0]])
	return c


## The Gavel Slam: both gavels raised high, then brought down together, the body dropping onto them.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	for arm: StringName in [&"arm_l", &"arm_r"]:
		c.turn(
			arm,
			Z,
			[[0, 0], [0.42, -2.0, BACK], [0.5, 1.2, IN3], [0.55, 1.35, OUT3, S], [0.7, 1.0], [1, 0]]
		)
	c.shift(
		&"body", UP, [[0, 0], [0.42, 0.1], [0.5, -0.22, IN3], [0.62, -0.18], [0.8, -0.05], [1, 0]]
	)
	c.turn(&"body", Z, [[0, 0], [0.42, 0.1], [0.5, -0.25, IN3], [0.62, -0.2], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.03], [0.5, -0.06, IN3], [0.62, -0.03], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.6, 0], [1, 0]])
	return c


## Shielded (the echo): the arms held still and crossed low in front, the clock blazing.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"arm_l", Z, [[0, 0], [1, 0.4]])
	c.turn(&"arm_r", Z, [[0, 0], [1, 0.4]])
	c.param(&"glow", [[0, 0], [1, 0.8]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"body", Z, [[0, 0], [0.15, 0.1, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.15, -0.35, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	c.turn(&"arm_r", Z, [[0, 0], [0.15, -0.35, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	return c


## Stalled: its gears catch, it lists to one side, the arms hanging slack and swaying.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"body", X, [[0, 0], [0.2, 0.18, OUT3], [1, 0.14]])
	c.shift(&"body", UP, [[0, 0], [0.2, -0.12, OUT3], [1, -0.1]])
	c.turn(&"arm_l", Z, [[0, 0], [0.2, 0.4, OUT3], [0.6, -0.2], [1, 0.2]])
	c.turn(&"arm_r", Z, [[0, 0], [0.2, -0.3, OUT3], [0.6, 0.25], [1, -0.15]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"glow", [[0, 0], [0.2, -0.7], [1, -0.7]])
	c.param(&"spin", [[0, 0], [0.2, -1.0], [1, -1.0]])
	return c


## The phase gate: a chiming roar, both arms flung up and out, the clock and the gears racing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"arm_r", X, [[0, 0], [0.3, -1.4, BACK], [0.8, -1.3], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.3, 1.4, BACK], [0.8, 1.3], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.3, -0.2, BACK], [0.8, -0.18], [1, 0]])
	c.param(&"tick", [[0, 0], [0.3, 4.0], [0.8, 4.0], [1, 0]])
	c.param(&"spin", [[0, 0], [0.3, 3.0], [0.8, 3.0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.3, 1.8], [0.8, 1.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.6], [0.8, 0.6], [1, 0]])
	return c


## Rising: from sunk into its base and folded to upright, the arms dropping into place last.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -1.8], [0.55, -0.2, OUT3], [0.8, 0.04, OUT, S], [1, 0]])
	c.turn(&"body", Z, [[0, 0.3], [0.6, 0.05], [1, 0]])
	c.turn(&"arm_r", X, [[0, 0.5], [0.7, -0.1, BACK], [1, 0]])
	c.turn(&"arm_l", X, [[0, -0.5], [0.7, 0.1, BACK], [1, 0]])
	c.param(&"tick", [[0, 3.0], [0.8, 0.5], [1, 0]])
	return c


## The collapse: the gears run down, it tips forward stiffly, the arms swinging loose, and falls.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(&"body", Z, [[0, 0], [0.3, 0.1], [0.85, -1.2, IN3], [1, -1.3]])
	c.shift(B, UP, [[0, 0], [0.3, 0.04], [0.85, -0.6, IN3], [1, -0.75]])
	c.turn(&"arm_l", Z, [[0, 0], [0.4, -0.5], [0.9, 0.8, IN3], [1, 0.9]])
	c.turn(&"arm_r", Z, [[0, 0], [0.4, -0.4], [0.9, 0.9, IN3], [1, 1.0]])
	c.param(&"spin", [[0, 0], [0.5, -0.8], [1, -1.0]])
	c.param(&"glow", [[0, 0], [0.3, 1.0], [1, -1.0]])
	return c
