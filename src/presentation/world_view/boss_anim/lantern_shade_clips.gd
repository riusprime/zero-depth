class_name LanternShadeClips
extends RefCounted
## v0.9.0 NB4: the Lantern Shade's clips (the owner's tall floating wraith in a torn violet-black cloak with an empty
## hood, cut into parts in its file: body (the cloak and hood), the two long arms from the shoulders, and the held
## lantern on its chain hanging from the right hand; BossModels rigs each as a bone, the lantern under arm_r). Model
## frame: +X the front, +Z its right, -Z its left. A turn about Z swings an arm forward (+) or back (-); a turn about X
## spreads an arm out (arm_r -, arm_l +). Parameters the avatar maps: flare (the held lantern's light: + flares, -
## dims), swing (the lantern's extra swing on its chain) and drift (the cloak's extra sway). It never walks: it glides,
## leaning into its way, the cloak trailing. For Lights Out (its shielded pattern) it lifts the lantern high and spreads
## its free arm while the room's light drains into it (the lantern flaring), then folds in as the dark falls (the
## lantern dimming to a coal); for Wisp Bloom it holds the lantern out before it and opens its arms, the wisps
## flowering off it; for the Snuff both long arms reach out to the circle, the fingers closing on it, the lantern
## pulled back and guttering; for the Lantern Sweep it swings the lantern round on its chain in a wide arc. A shudder,
## a slack drifting sag, a silent scream with the arms flung wide, rising out of a pool of smoke, and a collapse into
## its cloak as the lantern goes out.

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
	return _lib


## Hovering: the cloak breathing, the arms hanging long and drifting, the lantern turning slowly on its chain.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(&"body", [[0, 0], [0.5, 0.015, IO], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0.06, IO], [0.5, -0.04, IO], [1, 0.06]])
	c.turn(&"arm_r", Z, [[0, -0.04, IO], [0.5, 0.06, IO], [1, -0.04]])
	c.param(&"drift", [[0, 0], [0.5, 0.3], [1, 0]])
	return c


## The glide: leaning into its way, the cloak trailing, the arms drawn back, the lantern swinging behind.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.turn(&"body", Z, [[0, -0.1], [0.5, -0.13, IO], [1, -0.1]])
	c.turn(&"arm_l", Z, [[0, -0.25, IO], [0.5, -0.32, IO], [1, -0.25]])
	c.turn(&"arm_r", Z, [[0, -0.18, IO], [0.5, -0.26, IO], [1, -0.18]])
	c.param(&"swing", [[0, 0.4], [0.5, -0.4], [1, 0.4]])
	c.param(&"drift", [[0, 0.6], [1, 0.6]])
	return c


## Lights Out (shielded; "pattern_shielded": the only shielded pattern): the lantern raised high over the hood as the
## room's light drains into it (flaring), the free arm spread wide; held through its 3 s; folding in as the dark falls,
## the lantern dimmed to a coal.
static func _lights_out() -> BossClip:
	var c := BossClip.new(&"pattern_shielded")
	c.turn(&"arm_r", Z, [[0, 0], [0.4, 2.3, BACK], [0.5, 2.5, IN3], [0.85, 2.4], [1, 0]])
	c.turn(&"arm_r", X, [[0, 0], [0.4, 0.35], [0.85, 0.3], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.4, 1.0, BACK], [0.5, 1.15, IN3], [0.85, 1.1], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.4, 0.14], [0.5, 0.18, IN3], [0.85, 0.15], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.4, 0.35, OUT], [0.85, 0.4], [1, 0]])
	c.param(&"flare", [[0, 0], [0.4, 2.2, IN3], [0.6, 2.6], [0.85, 1.4], [0.95, -0.8], [1, -0.6]])
	c.param(&"drift", [[0, 0], [0.4, 1.4], [0.85, 1.2], [1, 0]])
	return c


## Wisp Bloom: the lantern held out before it, the free arm opening, a little rise as the flower blooms off it.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn(&"arm_r", Z, [[0, 0], [0.42, 1.3, BACK], [0.5, 1.5, IN3], [0.85, 1.4], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.7, BACK], [0.5, 0.85, IN3], [0.85, 0.8], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.42, 0.5], [0.85, 0.5], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.42, -0.08], [0.5, 0.12, IN3], [0.85, 0.05], [1, 0]])
	c.param(&"flare", [[0, 0], [0.42, 0.8], [0.5, 1.6, IN3], [0.85, 0.9], [1, 0]])
	c.param(&"swing", [[0, 0], [0.5, 0.6, IN3], [0.7, -0.4], [1, 0]])
	return c


## The Snuff: both long arms reaching out and forward to the circle through the windup, the fingers closing on it as it
## strikes (the arms snapping in), the lantern pulled back behind and guttering.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	for arm: StringName in [&"arm_l", &"arm_r"]:
		c.turn(
			arm,
			Z,
			[[0, 0], [0.42, 1.55, BACK], [0.5, 1.7, IN3], [0.56, 1.2, OUT3, S], [0.75, 0.8], [1, 0]]
		)
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.3], [0.5, -0.1, IN3], [0.75, 0], [1, 0]])
	c.turn(&"arm_r", X, [[0, 0], [0.42, -0.3], [0.5, 0.1, IN3], [0.75, 0], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.42, -0.22], [0.5, -0.3, IN3], [0.7, -0.15], [1, 0]])
	c.param(
		&"flare", [[0, 0], [0.42, -0.5], [0.5, 1.2, IN3], [0.56, -0.9, LIN], [0.8, -0.4], [1, 0]]
	)
	c.param(&"swing", [[0, 0], [0.42, -0.8], [0.5, 0.6, IN3], [0.8, 0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.5, LIN], [0.58, 0], [1, 0]])
	return c


## The Lantern Sweep: the lantern hauled back and up, then swung round low in a wide arc on its chain.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.turn(
		&"arm_r",
		Z,
		[[0, 0], [0.42, -1.6, BACK], [0.5, 1.4, IN3], [0.58, 1.6, OUT3, S], [0.75, 0.9], [1, 0]]
	)
	c.turn(&"arm_r", X, [[0, 0], [0.42, -0.6], [0.5, 0.2, IN3], [0.7, 0.1], [1, 0]])
	c.turn(&"body", Y, [[0, 0], [0.42, 0.45], [0.5, -0.5, IN3], [0.62, -0.45], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.42, 0.4], [0.62, 0.3], [1, 0]])
	c.param(&"swing", [[0, 0], [0.42, -1.4], [0.5, 1.8, IN3], [0.62, 1.2], [1, 0]])
	c.param(&"flare", [[0, 0], [0.42, 0.6], [0.5, 1.8, IN3], [0.62, 0.6], [1, 0]])
	return c


## Shielded (Lights Out, over another clip): drawn up, the arms close at its sides, the lantern bright.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"arm_l", X, [[0, 0], [1, 0.3]])
	c.turn(&"arm_r", X, [[0, 0], [1, -0.2]])
	c.param(&"flare", [[0, 0], [1, 1.0]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"body", Z, [[0, 0], [0.15, -0.14, OUT3], [0.5, 0.04, IO, S], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.15, -0.4, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	c.turn(&"arm_r", Z, [[0, 0], [0.15, -0.4, OUT3], [0.6, 0.1, IO, S], [1, 0]])
	c.param(&"swing", [[0, 0], [0.15, -1.0, OUT3], [0.6, 0.4], [1, 0]])
	return c


## Stunned: it sags low, listing, the arms slack, the lantern dim and swaying.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"body", X, [[0, 0], [0.2, 0.2, OUT3], [1, 0.16]])
	c.shift(&"body", UP, [[0, 0], [0.2, -0.45, OUT3], [1, -0.4]])
	c.turn(&"arm_l", Z, [[0, 0], [0.2, -0.3, OUT3], [0.6, 0.1], [1, -0.1]])
	c.turn(&"arm_r", Z, [[0, 0], [0.2, -0.4, OUT3], [0.6, 0.05], [1, -0.2]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"flare", [[0, 0], [0.2, -0.8], [1, -0.7]])
	c.param(&"swing", [[0, 0], [0.3, 0.8], [0.7, -0.8], [1, 0.4]])
	return c


## The phase gate: a silent scream, the arms flung wide and up, the lantern blazing, the cloak billowing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"arm_r", X, [[0, 0], [0.3, -1.3, BACK], [0.8, -1.2], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.3, 1.3, BACK], [0.8, 1.2], [1, 0]])
	c.turn(&"body", Z, [[0, 0], [0.3, 0.22, BACK], [0.8, 0.2], [1, 0]])
	c.shift(&"body", UP, [[0, 0], [0.3, 0.3], [0.8, 0.3], [1, 0]])
	c.param(&"flare", [[0, 0], [0.3, 2.4], [0.8, 2.0], [1, 0]])
	c.param(&"drift", [[0, 0], [0.3, 2.0], [0.8, 2.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.5], [0.8, 0.5], [1, 0]])
	return c


## Rising: up out of a low pool of smoke, unfolding, the lantern kindling last.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -2.2], [0.6, -0.3, OUT3], [0.85, 0.08, OUT, S], [1, 0]])
	c.turn(&"body", Z, [[0, -0.35], [0.6, -0.05], [1, 0]])
	c.turn(&"arm_r", Z, [[0, -0.6], [0.75, 0.1, BACK], [1, 0]])
	c.turn(&"arm_l", Z, [[0, -0.6], [0.75, 0.1, BACK], [1, 0]])
	c.param(&"flare", [[0, -1.0], [0.7, -0.6], [0.9, 1.4], [1, 0]])
	return c


## The end: the lantern gutters out, the figure folds down into its cloak and sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(&"body", Z, [[0, 0], [0.3, 0.1], [0.85, -0.6, IN3], [1, -0.7]])
	c.shift(B, UP, [[0, 0], [0.3, 0.1], [0.85, -1.4, IN3], [1, -1.8]])
	c.turn(&"arm_l", X, [[0, 0], [0.3, 0.8], [0.9, 0.2, IN3], [1, 0.1]])
	c.turn(&"arm_r", X, [[0, 0], [0.3, -0.8], [0.9, -0.2, IN3], [1, -0.1]])
	c.param(&"flare", [[0, 0], [0.3, 1.6], [0.6, -0.5], [1, -1.0]])
	return c
