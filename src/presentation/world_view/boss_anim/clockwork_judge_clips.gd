class_name ClockworkJudgeClips
extends RefCounted
## The Clockwork Judge's clips (the owner's tall brass automaton, skinned to a skeleton: the pelvis "body", the
## chest, the head, each arm an upper arm, a forearm and a gavel hanging from the wrist, legs whose shins slide,
## the chest clock's two hands, the waist gear). Model frame: +X the front, +Z its right, -Z its left. A turn about
## Z swings a hanging part forward (+) or back (-) like a pendulum and tips a standing one back (+) or forward (-);
## a turn about X carries the right arm out to its side (-) and the left arm out to its side (+), and rolls the
## figure. BODY moves the whole figure about its feet. Parameters the avatar maps: glow (the clock's light) and tick
## (the hands' extra sweep).
## The model's file carries its own animations for standing, walking and its four moves (ClockworkJudgeAvatar
## .OWNER_PLAYS), which move the bones in place of the clips of those names here: of those clips only the
## parameters play, and their bone tracks are the pose the game falls back to should the file lose an animation.
## The reactions have no animation in the file and play from here on top of the file's idle: a jolt (the chest and
## the head knocked back, the arms swinging after), a stall (it lists, sinks on its sliding legs, the head hanging,
## the arms slack), a chiming roar with the arms flung up and out, rising stiffly upright out of its base, and a
## collapse forward as it runs down.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const UP := Vector3(0, 1, 0)
const B := BossClip.BODY
const ARM_L := &"upper_arm_L"
const ARM_R := &"upper_arm_R"
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
		BossClip.loosen(_lib, 0.015)  # The wind-up, the recoil, the idle sway
	return _lib


## Standing: the arms swing a little, opposite each other, the figure breathing a hair.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(B, [[0, 0], [0.5, 0.012], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0.1, IO], [0.5, -0.1, IO], [1, 0.1]])
	c.turn(ARM_R, Z, [[0, -0.1, IO], [0.5, 0.1, IO], [1, -0.1]])
	c.param(&"glow", [[0, 0], [0.5, 0.2], [1, 0]])
	return c


## The stiff walk: a short bob, a slight roll, the arms counter-swinging like pendulums.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.shift(B, UP, [[0, 0], [0.25, 0.04, OUT], [0.5, 0, IO], [0.75, 0.04, OUT], [1, 0, IO]])
	c.turn(B, X, [[0, 0.03], [0.5, -0.03], [1, 0.03]])
	c.turn(ARM_L, Z, [[0, 0.3, IO], [0.5, -0.3, IO], [1, 0.3]])
	c.turn(ARM_R, Z, [[0, -0.3, IO], [0.5, 0.3, IO], [1, -0.3]])
	return c


## The echo: it spreads both arms wide (out to the sides) and leans as the clock races through the windup; it
## holds there while the ghosts replay your path.
static func _echo() -> BossClip:
	var c := BossClip.new(&"echo")
	c.turn(ARM_R, X, [[0, 0], [0.42, -0.9, BACK], [0.5, -1.0, IN3], [0.85, -0.95], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.42, 0.9, BACK], [0.5, 1.0, IN3], [0.85, 0.95], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, -0.12], [0.5, -0.15, IN3], [0.85, -0.12], [1, 0]])
	c.param(&"tick", [[0, 0], [0.42, 2.5, IN3], [0.5, 3.0], [0.85, 2.5], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 1.2], [0.5, 1.6, IN3], [0.85, 1.2], [1, 0]])
	return c


## The Gear Spiral: it braces, arms out to the sides and a little forward, as the sparks pour out.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn(ARM_R, X, [[0, 0], [0.42, -0.7, BACK], [0.5, -0.8, IN3], [0.85, -0.75], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.42, 0.7, BACK], [0.5, 0.8, IN3], [0.85, 0.75], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0], [0.42, 0.25], [0.85, 0.25], [1, 0]])
	c.turn(ARM_R, Z, [[0, 0], [0.42, 0.25], [0.85, 0.25], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, -0.05], [0.5, 0.03, IN3], [0.85, 0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.7], [0.5, 1.2, IN3], [0.85, 0.8], [1, 0]])
	return c


## The Verdict: the right gavel hauled up and back over the shoulder through the windup, then swung down and through
## onto the square as it strikes, the figure following the swing.
static func _verdict() -> BossClip:
	var c := BossClip.new(&"verdict")
	c.turn(
		ARM_R,
		Z,
		[[0, 0], [0.42, -2.3, BACK], [0.5, 1.3, IN3], [0.55, 1.5, OUT3, S], [0.7, 1.1], [1, 0]]
	)
	c.turn(ARM_L, Z, [[0, 0], [0.42, 0.35], [0.5, -0.3, IN3], [0.7, -0.15], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.12], [0.5, -0.22, IN3], [0.6, -0.18], [1, 0]])
	c.turn(B, Y, [[0, 0], [0.42, -0.15], [0.5, 0.1, IN3], [0.7, 0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.8], [0.5, 1.5, IN3], [0.62, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.8, LIN], [0.58, 0], [1, 0]])
	return c


## The Gavel Slam: both gavels raised high, then brought down together, the figure dropping onto them.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	for arm: StringName in [ARM_L, ARM_R]:
		c.turn(
			arm,
			Z,
			[[0, 0], [0.42, -2.0, BACK], [0.5, 1.2, IN3], [0.55, 1.35, OUT3, S], [0.7, 1.0], [1, 0]]
		)
	c.shift(B, UP, [[0, 0], [0.42, 0.1], [0.5, -0.22, IN3], [0.62, -0.18], [0.8, -0.05], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.1], [0.5, -0.25, IN3], [0.62, -0.2], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.03], [0.5, -0.06, IN3], [0.62, -0.03], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.6, 0], [1, 0]])
	return c


## Shielded (the echo, over its spread arms): the chest held a little back to present the clock, the head bowed
## to it, the clock blazing.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"chest", Z, [[0, 0], [1, 0.06]])
	c.turn(&"head", Z, [[0, 0], [1, -0.1]])
	c.param(&"glow", [[0, 0], [1, 0.8]])
	return c


## A hit: the chest knocked back, the head after it, the arms and their gavels swinging back and through.
static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(B, Z, [[0, 0], [0.15, 0.04, OUT3], [0.5, -0.01, IO, S], [1, 0]])
	c.turn(&"chest", Z, [[0, 0], [0.15, 0.1, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.turn(&"head", Z, [[0, 0], [0.2, 0.16, OUT3], [0.55, -0.05, IO, S], [1, 0]])
	for arm: StringName in [ARM_L, ARM_R]:
		c.turn(arm, Z, [[0, 0], [0.15, -0.2, OUT3], [0.6, 0.06, IO, S], [1, 0]])
	for gavel: StringName in [&"gavel_L", &"gavel_R"]:
		c.turn(gavel, Z, [[0, 0], [0.25, -0.25, OUT3], [0.7, 0.1, IO, S], [1, 0]])
	return c


## Stalled: its gears catch; it lists to one side and sinks on its sliding legs (the shins take up the drop, so the
## feet stay on the ground), the head hanging, the arms slack and swaying.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(B, X, [[0, 0], [0.2, 0.08, OUT3], [1, 0.06]])
	c.turn(&"chest", X, [[0, 0], [0.2, 0.12, OUT3], [1, 0.1]])
	c.turn(&"chest", Z, [[0, 0], [0.2, -0.12, OUT3], [1, -0.1]])
	c.turn(&"head", Z, [[0, 0], [0.25, -0.3, OUT3], [1, -0.26]])
	c.turn(&"head", X, [[0, 0], [0.25, 0.12, OUT3], [1, 0.1]])
	c.shift(&"body", UP, [[0, 0], [0.2, -0.12, OUT3], [1, -0.1]])
	for shin: StringName in [&"shin_L", &"shin_R"]:
		c.shift(shin, UP, [[0, 0], [0.2, 0.12, OUT3], [1, 0.1]])
	c.turn(ARM_L, Z, [[0, 0], [0.2, 0.3, OUT3], [0.6, -0.12], [1, 0.14]])
	c.turn(ARM_R, Z, [[0, 0], [0.2, -0.2, OUT3], [0.6, 0.16], [1, -0.08]])
	c.turn(&"forearm_L", Z, [[0, 0], [0.3, 0.2, OUT3], [1, 0.15]])
	c.turn(&"forearm_R", Z, [[0, 0], [0.3, 0.2, OUT3], [1, 0.15]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"glow", [[0, 0], [0.2, -0.7], [1, -0.7]])
	return c


## The phase gate: a chiming roar, both arms flung up and out with the gavels swinging under the wrists, the chest
## and the head thrown back, the clock racing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(ARM_R, X, [[0, 0], [0.3, -1.1, BACK], [0.8, -1.0], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.3, 1.1, BACK], [0.8, 1.0], [1, 0]])
	c.turn(&"forearm_R", X, [[0, 0], [0.35, -0.4, BACK], [0.8, -0.35], [1, 0]])
	c.turn(&"forearm_L", X, [[0, 0], [0.35, 0.4, BACK], [0.8, 0.35], [1, 0]])
	c.turn(&"gavel_R", X, [[0, 0], [0.45, 1.2, BACK], [0.8, 1.1], [1, 0]])
	c.turn(&"gavel_L", X, [[0, 0], [0.45, -1.2, BACK], [0.8, -1.1], [1, 0]])
	c.turn(&"chest", Z, [[0, 0], [0.3, 0.14, BACK], [0.8, 0.12], [1, 0]])
	c.turn(&"head", Z, [[0, 0], [0.35, 0.24, BACK], [0.8, 0.2], [1, 0]])
	c.param(&"tick", [[0, 0], [0.3, 4.0], [0.8, 4.0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.3, 1.8], [0.8, 1.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.6], [0.8, 0.6], [1, 0]])
	return c


## Rising: from sunk into its base and folded forward to upright, the head last, the arms dropping into place.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -1.8], [0.55, -0.2, OUT3], [0.8, 0.04, OUT, S], [1, 0]])
	c.turn(&"chest", Z, [[0, -0.3], [0.6, -0.05], [1, 0]])
	c.turn(&"head", Z, [[0, -0.35], [0.7, -0.1], [1, 0]])
	c.turn(ARM_R, Z, [[0, 0.5], [0.7, -0.1, BACK], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0.5], [0.7, -0.1, BACK], [1, 0]])
	c.param(&"tick", [[0, 3.0], [0.8, 0.5], [1, 0]])
	return c


## The collapse: it runs down, tips forward stiffly, the chest and the head folding, the arms swinging loose, and
## falls.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(B, Z, [[0, 0], [0.3, 0.1], [0.85, -1.2, IN3], [1, -1.3]])
	c.shift(B, UP, [[0, 0], [0.3, 0.04], [0.85, -0.6, IN3], [1, -0.75]])
	c.turn(&"chest", Z, [[0, 0], [0.3, 0.06], [0.85, -0.15, IN3], [1, -0.18]])
	c.turn(&"head", Z, [[0, 0], [0.3, 0.1], [0.85, -0.3, IN3], [1, -0.35]])
	c.turn(ARM_L, Z, [[0, 0], [0.4, -0.5], [0.9, 0.8, IN3], [1, 0.9]])
	c.turn(ARM_R, Z, [[0, 0], [0.4, -0.4], [0.9, 0.9, IN3], [1, 1.0]])
	c.param(&"glow", [[0, 0], [0.3, 1.0], [1, -1.0]])
	return c
