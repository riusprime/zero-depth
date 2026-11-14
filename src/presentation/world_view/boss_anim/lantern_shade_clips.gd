class_name LanternShadeClips
extends RefCounted
## The Lantern Shade's clips (the owner's tall floating wraith in a torn violet-black cloak with an empty hood, one
## skinned mesh on a full skeleton: hips, spine, chest, neck and the hood, two long arms with hands, the lantern on
## its chain under the right hand, and chains of cloth bones round the robe). Its file carries its own idle, its
## glide and its four attacks; LanternShadeAvatar plays those in place of the clips of the same moves here (idle,
## walk, pattern_shielded, pattern, marks, slam_ring), which keep only their parameters. The other clips (the
## shielded hold, the flinch, the stagger, the roar, the rise, the death) are played from here, over the file's idle.
## They turn three bones: HIPS carries the whole figure, an arm's upper bone the whole arm.
## Model frame: +X the front, +Z its right, -Z its left. A turn about Z swings an arm forward (+) or back (-); a turn
## about X spreads an arm out (the right -, the left +). Parameters the avatar maps: flare (the held lantern's light:
## + flares, - dims), swing (a kick to the lantern on its chain) and drift (the robe's hem billowing out). Under a
## file's animation the lantern and the robe already swing, so only the clips played from here carry swing and drift.
## It never walks: it glides, leaning into its way, the cloak trailing. For Lights Out (its shielded pattern) it
## lifts the lantern high and spreads
## its free arm while the room's light drains into it (the lantern flaring), then folds in as the dark falls (the
## lantern dimming to a coal); for Wisp Bloom it holds the lantern out before it and opens its arms, the wisps
## flowering off it; for the Snuff the free hand reaches for the flame and pinches it out, the lantern
## pulled back and guttering; for the Lantern Sweep it swings the lantern round on its chain in a wide arc. A shudder,
## a slack drifting sag, a silent scream with the arms flung wide, rising out of a pool of smoke, and a collapse into
## its cloak as the lantern goes out.

## The bones the clips turn, spelt as the model file exports them.
const HIPS := &"hips"
const ARM_L := &"upper_arm_L"
const ARM_R := &"upper_arm_R"
const CHAIN := &"chain1"

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
			_lights_out(),
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
		BossClip.loosen(_lib, 0.03)  # The wind-up, the recoil, the idle sway
	return _lib


## Turns the lantern arm, and the top of the lantern's chain the other way by as much: the chain is a bone under the
## hand, so without this the lantern would stick out along a lifted arm as if on a rod, not hang from it.
static func _lantern_arm(c: BossClip, axis: Vector3, keys: Array) -> void:
	c.turn(ARM_R, axis, keys)
	c.turn(CHAIN, axis, BossClip.negated(keys))


## Hovering: the cloak breathing, the arms hanging long and drifting, the lantern turning slowly on its chain.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(HIPS, [[0, 0], [0.5, 0.015, IO], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0.06, IO], [0.5, -0.04, IO], [1, 0.06]])
	c.turn(ARM_R, Z, [[0, -0.04, IO], [0.5, 0.06, IO], [1, -0.04]])
	return c


## The glide: leaning into its way, the cloak trailing, the arms drawn back, the lantern swinging behind.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.turn(HIPS, Z, [[0, -0.1], [0.5, -0.13, IO], [1, -0.1]])
	c.turn(ARM_L, Z, [[0, -0.25, IO], [0.5, -0.32, IO], [1, -0.25]])
	c.turn(ARM_R, Z, [[0, -0.18, IO], [0.5, -0.26, IO], [1, -0.18]])
	return c


## Lights Out (shielded; "pattern_shielded": the only shielded pattern): the lantern raised high over the hood as the
## room's light drains into it (flaring), the free arm spread wide; held through its 3 s; folding in as the dark falls,
## the lantern dimmed to a coal.
static func _lights_out() -> BossClip:
	var c := BossClip.new(&"pattern_shielded")
	c.turn(ARM_R, Z, [[0, 0], [0.4, 2.3, BACK], [0.5, 2.5, IN3], [0.85, 2.4], [1, 0]])
	c.turn(ARM_R, X, [[0, 0], [0.4, 0.35], [0.85, 0.3], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.4, 1.0, BACK], [0.5, 1.15, IN3], [0.85, 1.1], [1, 0]])
	c.turn(HIPS, Z, [[0, 0], [0.4, 0.14], [0.5, 0.18, IN3], [0.85, 0.15], [1, 0]])
	c.shift(HIPS, UP, [[0, 0], [0.4, 0.35, OUT], [0.85, 0.4], [1, 0]])
	c.param(&"flare", [[0, 0], [0.4, 2.2, IN3], [0.6, 2.6], [0.85, 1.4], [0.95, -0.8], [1, -0.6]])
	return c


## Wisp Bloom: the lantern held out before it, the free arm opening, a little rise as the flower blooms off it.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn(ARM_R, Z, [[0, 0], [0.42, 1.3, BACK], [0.5, 1.5, IN3], [0.85, 1.4], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.42, 0.7, BACK], [0.5, 0.85, IN3], [0.85, 0.8], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0], [0.42, 0.5], [0.85, 0.5], [1, 0]])
	c.shift(HIPS, UP, [[0, 0], [0.42, -0.08], [0.5, 0.12, IN3], [0.85, 0.05], [1, 0]])
	c.param(&"flare", [[0, 0], [0.42, 0.8], [0.5, 1.6, IN3], [0.85, 0.9], [1, 0]])
	return c


## The Snuff: both long arms reaching out and forward to the circle through the windup, the fingers closing on it as it
## strikes (the arms snapping in), the lantern pulled back behind and guttering.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	for arm: StringName in [ARM_L, ARM_R]:
		c.turn(
			arm,
			Z,
			[[0, 0], [0.42, 1.55, BACK], [0.5, 1.7, IN3], [0.56, 1.2, OUT3, S], [0.75, 0.8], [1, 0]]
		)
	c.turn(ARM_L, X, [[0, 0], [0.42, 0.3], [0.5, -0.1, IN3], [0.75, 0], [1, 0]])
	c.turn(ARM_R, X, [[0, 0], [0.42, -0.3], [0.5, 0.1, IN3], [0.75, 0], [1, 0]])
	c.turn(HIPS, Z, [[0, 0], [0.42, -0.22], [0.5, -0.3, IN3], [0.7, -0.15], [1, 0]])
	c.param(
		&"flare", [[0, 0], [0.42, -0.5], [0.5, 1.2, IN3], [0.56, -0.9, LIN], [0.8, -0.4], [1, 0]]
	)
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.5, LIN], [0.58, 0], [1, 0]])
	return c


## The Lantern Sweep: the lantern hauled back and up, then swung round low in a wide arc on its chain.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.turn(
		ARM_R,
		Z,
		[[0, 0], [0.42, -1.6, BACK], [0.5, 1.4, IN3], [0.58, 1.6, OUT3, S], [0.75, 0.9], [1, 0]]
	)
	c.turn(ARM_R, X, [[0, 0], [0.42, -0.6], [0.5, 0.2, IN3], [0.7, 0.1], [1, 0]])
	c.turn(HIPS, Y, [[0, 0], [0.42, 0.45], [0.5, -0.5, IN3], [0.62, -0.45], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.42, 0.4], [0.62, 0.3], [1, 0]])
	c.param(&"flare", [[0, 0], [0.42, 0.6], [0.5, 1.8, IN3], [0.62, 0.6], [1, 0]])
	return c


## Shielded (Lights Out, over another clip): drawn up, the arms close at its sides, the lantern bright.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(ARM_L, X, [[0, 0], [1, 0.3]])
	_lantern_arm(c, X, [[0, 0], [1, -0.2]])
	c.param(&"flare", [[0, 0], [1, 1.0]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(HIPS, Z, [[0, 0], [0.15, -0.14, OUT3], [0.5, 0.04, IO, S], [1, 0]])
	c.turn(ARM_L, Z, [[0, 0], [0.15, -0.4, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	_lantern_arm(c, Z, [[0, 0], [0.15, -0.4, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	c.param(&"swing", [[0, 0], [0.15, -1.0, OUT3], [0.6, 0.4], [1, 0]])
	return c


## Stunned: it sags low, listing, the arms slack, the lantern dim and swaying.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(HIPS, X, [[0, 0], [0.2, 0.2, OUT3], [1, 0.16]])
	c.shift(HIPS, UP, [[0, 0], [0.2, -0.45, OUT3], [1, -0.4]])
	c.turn(ARM_L, Z, [[0, 0], [0.2, -0.3, OUT3], [0.6, 0.1], [1, -0.1]])
	_lantern_arm(c, Z, [[0, 0], [0.2, -0.4, OUT3], [0.6, 0.05], [1, -0.2]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"flare", [[0, 0], [0.2, -0.8], [1, -0.7]])
	c.param(&"swing", [[0, 0], [0.3, 0.8], [0.7, -0.8], [1, 0.4]])
	return c


## The phase gate: a silent scream, the arms flung wide and up, the lantern blazing, the cloak billowing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	_lantern_arm(c, X, [[0, 0], [0.3, -1.3, BACK], [0.8, -1.2], [1, 0]])
	c.turn(ARM_L, X, [[0, 0], [0.3, 1.3, BACK], [0.8, 1.2], [1, 0]])
	c.turn(HIPS, Z, [[0, 0], [0.3, 0.22, BACK], [0.8, 0.2], [1, 0]])
	c.shift(HIPS, UP, [[0, 0], [0.3, 0.3], [0.8, 0.3], [1, 0]])
	c.param(&"flare", [[0, 0], [0.3, 2.4], [0.8, 2.0], [1, 0]])
	c.param(&"drift", [[0, 0], [0.3, 2.0], [0.8, 2.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.5], [0.8, 0.5], [1, 0]])
	return c


## Rising: up out of a low pool of smoke, unfolding, the lantern kindling last.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -2.2], [0.6, -0.3, OUT3], [0.85, 0.08, OUT, S], [1, 0]])
	c.turn(HIPS, Z, [[0, -0.35], [0.6, -0.05], [1, 0]])
	_lantern_arm(c, Z, [[0, -0.6], [0.75, 0.1, BACK], [1, 0]])
	c.turn(ARM_L, Z, [[0, -0.6], [0.75, 0.1, BACK], [1, 0]])
	c.param(&"flare", [[0, -1.0], [0.7, -0.6], [0.9, 1.4], [1, 0]])
	return c


## The end: the lantern gutters out, the figure folds down into its cloak and sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(HIPS, Z, [[0, 0], [0.3, 0.1], [0.85, -0.6, IN3], [1, -0.7]])
	c.shift(B, UP, [[0, 0], [0.3, 0.1], [0.85, -1.4, IN3], [1, -1.8]])
	c.turn(ARM_L, X, [[0, 0], [0.3, 0.8], [0.9, 0.2, IN3], [1, 0.1]])
	_lantern_arm(c, X, [[0, 0], [0.3, -0.8], [0.9, -0.2, IN3], [1, -0.1]])
	c.param(&"flare", [[0, 0], [0.3, 1.6], [0.6, -0.5], [1, -1.0]])
	return c
