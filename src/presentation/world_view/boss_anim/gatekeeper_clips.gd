class_name GatekeeperClips
extends RefCounted
## v0.8.0 BA: the Gatekeeper's clips (the owner's Stone Sentinel, rigged in code by BossRig: torso, head, arm_l/r,
## fist_l/r, leg_l/r). A colossal stone golem, so every move is slow to load and lands hard: a deep breath and a
## sway when idle, a stomping walk that dips and squashes on each plant, both fists hauled overhead and hammered down
## for the Fist Slam (once per marker), one fist wound far back and driven into the floor for the Shock Lanes, arms
## flung wide then punched into the ground for the Cross Quake, curling into a boulder behind its crossed arms for the
## Rock Rings (its shielded signature), a full-body backhand for the sweep; a flinch, a reel and a dazed slump, a
## roar with its arms thrown wide at each phase gate, a burst out of the ground and a forward collapse.
## Turns in the model frame (BossClip): Z + swings an arm forward/up and pitches the torso back; X + swings a left
## limb out (the right one's mirror is -); Y + turns the front to its left.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const UP := Vector3(0, 1, 0)
const FWD := Vector3(1, 0, 0)
const B := BossClip.BODY
const IO := BossClip.IN_OUT
const IN := BossClip.IN
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
			_marks(),
			_row_lanes(),
			_pattern(),
			_pattern_shielded(),
			_sweep(),
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
	c.shift(B, UP, [[0, 0], [0.5, 0.03], [1, 0]])
	c.stretch(B, [[0, 0], [0.5, 0.012], [1, 0]])
	c.turn(&"torso", Z, [[0, 0], [0.5, 0.035], [1, 0]])
	c.turn(&"torso", Y, [[0, 0.03], [0.5, -0.03], [1, 0.03]])
	c.turn(&"head", Z, [[0, 0.02], [0.5, -0.05], [1, 0.02]])
	c.turn(&"arm_l", Z, [[0, 0.04], [0.5, 0.11], [1, 0.04]])
	c.turn(&"arm_r", Z, [[0, 0.11], [0.5, 0.04], [1, 0.11]])
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0.08], [0.5, 0.12], [1, 0.08]], true)
	c.turn_pair(&"fist_l", &"fist_r", Z, [[0, 0.12], [0.5, 0.18], [1, 0.12]])
	return c


## A heavy stomp: the swing leg lifts and reaches, the body rides high over it and drops with a squash as it plants
## (t 0.25 and 0.75), the shoulders and fists counter-swing.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.turn(&"leg_r", Z, [[0, 0], [0.25, 0.42, OUT], [0.5, 0, IN], [0.75, -0.42, OUT], [1, 0, IN]])
	c.turn(&"leg_l", Z, [[0, 0], [0.25, -0.42, OUT], [0.5, 0, IN], [0.75, 0.42, OUT], [1, 0, IN]])
	c.shift(&"leg_r", UP, [[0, 0.12], [0.2, 0.0], [0.8, 0.0], [1, 0.12]])
	c.shift(&"leg_l", UP, [[0, 0], [0.3, 0], [0.5, 0.12], [0.7, 0], [1, 0]])
	c.shift(
		B, UP, [[0, 0.07], [0.25, -0.04, IN], [0.5, 0.07, OUT], [0.75, -0.04, IN], [1, 0.07, OUT]]
	)
	(
		c
		. stretch(
			B,
			[
				[0, 0],
				[0.21, 0],
				[0.25, -0.05, IN3],
				[0.33, 0, OUT],
				[0.71, 0],
				[0.75, -0.05, IN3],
				[0.83, 0, OUT],
				[1, 0],
			]
		)
	)
	c.turn(B, X, [[0, 0], [0.25, -0.05], [0.5, 0], [0.75, 0.05], [1, 0]])
	c.turn(&"torso", Z, [[0, -0.07], [1, -0.07]])
	c.turn(&"torso", Y, [[0, 0], [0.25, 0.1, OUT], [0.5, 0, IN], [0.75, -0.1, OUT], [1, 0, IN]])
	c.turn(
		&"arm_l", Z, [[0, 0.1], [0.25, 0.42, OUT], [0.5, 0.1, IN], [0.75, -0.25, OUT], [1, 0.1, IN]]
	)
	c.turn(
		&"arm_r", Z, [[0, 0.1], [0.25, -0.25, OUT], [0.5, 0.1, IN], [0.75, 0.42, OUT], [1, 0.1, IN]]
	)
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0.12], [1, 0.12]], true)
	c.turn(&"head", Z, [[0, 0.03], [0.25, -0.03], [0.5, 0.03], [0.75, -0.03], [1, 0.03]])
	return c


## The Fist Slam: it sinks, hauls both fists high over its head leaning back, and hammers them down onto the marker
## with a lurch and a squash on the strike; with several markers it heaves them up again and hammers again on each
## (strike..hold is one slam), then straightens slowly.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	var arm := [
		[0, 0],
		[0.1, -0.35, OUT],
		[0.4, 2.7],
		[0.47, 2.9, OUT],
		[0.5, 0.5, IN3],
		[0.525, 0.3, OUT3, S],
		[0.565, 2.3, IO],
		[0.62, 0.5, IN3],
		[0.74, 0.55],
		[1, 0],
	]
	c.turn_pair(&"arm_l", &"arm_r", Z, arm)
	c.turn_pair(
		&"arm_l",
		&"arm_r",
		X,
		[[0, 0], [0.4, -0.28], [0.5, 0.12, IN3], [0.565, -0.22], [0.62, 0.12, IN3], [1, 0]],
		true
	)
	c.turn_pair(
		&"fist_l",
		&"fist_r",
		Z,
		[[0, 0], [0.4, 0.7], [0.5, -0.15, IN3], [0.565, 0.6], [0.62, -0.15, IN3], [1, 0]]
	)
	(
		c
		. turn(
			&"torso",
			Z,
			[
				[0, 0],
				[0.1, -0.1, OUT],
				[0.4, 0.24],
				[0.47, 0.28, OUT],
				[0.5, -0.38, IN3],
				[0.525, -0.45, OUT3, S],
				[0.565, 0.08],
				[0.62, -0.38, IN3],
				[0.76, -0.32],
				[1, 0],
			]
		)
	)
	c.turn(
		&"head",
		Z,
		[[0, 0], [0.4, 0.18], [0.5, -0.22, IN3], [0.565, 0.1], [0.62, -0.22, IN3], [1, 0]]
	)
	(
		c
		. shift(
			B,
			UP,
			[
				[0, 0],
				[0.1, -0.12, OUT],
				[0.4, 0.1],
				[0.5, -0.34, IN3],
				[0.525, -0.4, OUT3, S],
				[0.565, -0.08],
				[0.62, -0.34, IN3],
				[0.78, -0.26],
				[1, 0],
			]
		)
	)
	c.shift(
		B, FWD, [[0, 0], [0.4, -0.12], [0.5, 0.22, IN3], [0.565, 0.06], [0.62, 0.22, IN3], [1, 0]]
	)
	(
		c
		. stretch(
			B,
			[
				[0, 0],
				[0.1, -0.06, OUT],
				[0.4, 0.07],
				[0.5, -0.13, IN3],
				[0.525, -0.17, OUT3, S],
				[0.565, 0.02],
				[0.62, -0.13, IN3],
				[0.7, -0.05],
				[1, 0],
			]
		)
	)
	c.turn_pair(
		&"leg_l", &"leg_r", X, [[0, 0], [0.4, 0.1], [0.5, 0.2, IN3], [0.62, 0.2], [1, 0]], true
	)
	c.param(
		&"tremble",
		[
			[0, 0],
			[0.49, 0],
			[0.5, 1, LIN],
			[0.56, 0, OUT],
			[0.61, 0],
			[0.62, 1, LIN],
			[0.7, 0],
			[1, 0]
		]
	)
	return c


## The Shock Lanes: it twists away with its right fist wound far up and back, the left arm thrown out for balance,
## then whips round and drives the fist into the floor in front of it on a wide, low stance.
static func _row_lanes() -> BossClip:
	var c := BossClip.new(&"row_lanes")
	c.turn(
		&"arm_r",
		Z,
		[
			[0, 0],
			[0.12, -0.4, OUT],
			[0.42, 2.9],
			[0.47, 3.05, OUT],
			[0.5, 0.35, IN3],
			[0.525, 0.15, OUT3, S],
			[0.565, 2.6],
			[0.62, 0.35, IN3],
			[0.75, 0.4],
			[1, 0]
		]
	)
	c.turn(
		&"arm_r",
		X,
		[[0, 0], [0.42, 0.45], [0.5, -0.1, IN3], [0.565, 0.4], [0.62, -0.1, IN3], [1, 0]]
	)
	c.turn(
		&"fist_r",
		Z,
		[[0, 0], [0.42, 0.9], [0.5, -0.2, IN3], [0.565, 0.8], [0.62, -0.2, IN3], [1, 0]]
	)
	c.turn(&"arm_l", X, [[0, 0], [0.42, 1.1], [0.5, 0.7, IN3], [0.62, 0.7], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.42, -0.3], [0.5, 0.5, IN3], [0.62, 0.5], [1, 0]])
	c.turn(
		&"torso",
		Y,
		[
			[0, 0],
			[0.42, -0.6],
			[0.47, -0.66, OUT],
			[0.5, 0.42, IN3],
			[0.525, 0.52, OUT3, S],
			[0.565, -0.45],
			[0.62, 0.42, IN3],
			[0.78, 0.3],
			[1, 0]
		]
	)
	c.turn(
		&"torso",
		Z,
		[
			[0, 0],
			[0.42, 0.18],
			[0.5, -0.42, IN3],
			[0.565, 0.1],
			[0.62, -0.42, IN3],
			[0.78, -0.3],
			[1, 0]
		]
	)
	c.turn(
		B, Y, [[0, 0], [0.42, -0.25], [0.5, 0.18, IN3], [0.565, -0.15], [0.62, 0.18, IN3], [1, 0]]
	)
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.12, -0.08],
			[0.42, 0.06],
			[0.5, -0.36, IN3],
			[0.525, -0.42, OUT3, S],
			[0.565, -0.12],
			[0.62, -0.36, IN3],
			[0.8, -0.25],
			[1, 0]
		]
	)
	c.shift(
		B, FWD, [[0, 0], [0.42, -0.15], [0.5, 0.25, IN3], [0.565, 0.0], [0.62, 0.25, IN3], [1, 0]]
	)
	c.stretch(
		B,
		[
			[0, 0],
			[0.42, 0.06],
			[0.5, -0.12, IN3],
			[0.565, 0.0],
			[0.62, -0.12, IN3],
			[0.72, -0.04],
			[1, 0]
		]
	)
	c.turn(&"leg_r", Z, [[0, 0], [0.42, -0.3], [0.5, 0.35, IN3], [0.62, 0.35], [1, 0]])
	c.turn(&"leg_l", Z, [[0, 0], [0.42, 0.2], [0.5, -0.25, IN3], [0.62, -0.25], [1, 0]])
	c.turn_pair(&"leg_l", &"leg_r", X, [[0, 0], [0.5, 0.2, IN3], [0.62, 0.2], [1, 0]], true)
	c.turn(&"head", Z, [[0, 0], [0.42, 0.1], [0.5, -0.25, IN3], [0.62, -0.25], [1, 0]])
	c.param(
		&"tremble",
		[
			[0, 0],
			[0.49, 0],
			[0.5, 1, LIN],
			[0.56, 0, OUT],
			[0.61, 0],
			[0.62, 1, LIN],
			[0.7, 0],
			[1, 0]
		]
	)
	return c


## The Cross Quake: it rises with its arms flung wide and its chest thrown back (a big T), then punches both fists
## into the ground at its sides and holds them there, pumping, while the quake streams out.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.turn_pair(
		&"arm_l",
		&"arm_r",
		X,
		[[0, 0], [0.38, 1.35], [0.46, 1.45, OUT], [0.5, 0.55, IN3], [0.62, 0.55], [1, 0]],
		true
	)
	c.turn_pair(
		&"arm_l",
		&"arm_r",
		Z,
		[[0, 0], [0.38, 1.1], [0.46, 1.25, OUT], [0.5, 0.25, IN3], [0.62, 0.25], [1, 0]]
	)
	c.turn_pair(
		&"fist_l", &"fist_r", Z, [[0, 0], [0.38, 0.4], [0.5, -0.1, IN3], [0.62, -0.1], [1, 0]]
	)
	c.turn(
		&"torso",
		Z,
		[
			[0, 0],
			[0.38, 0.28],
			[0.46, 0.32, OUT],
			[0.5, -0.32, IN3],
			[0.53, -0.38, OUT3, S],
			[0.62, -0.32],
			[0.8, -0.2],
			[1, 0]
		]
	)
	c.turn(&"head", Z, [[0, 0], [0.38, 0.35], [0.5, -0.15, IN3], [0.62, -0.1], [1, 0]])
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.12, -0.08],
			[0.38, 0.14],
			[0.46, 0.16, OUT],
			[0.5, -0.36, IN3],
			[0.53, -0.42, OUT3, S],
			[0.545, -0.3],
			[0.56, -0.38],
			[0.575, -0.3],
			[0.59, -0.38],
			[0.62, -0.34],
			[0.8, -0.2],
			[1, 0]
		]
	)
	c.stretch(
		B,
		[
			[0, 0],
			[0.38, 0.08, BACK],
			[0.5, -0.14, IN3],
			[0.53, -0.18, OUT3, S],
			[0.62, -0.1],
			[1, 0]
		]
	)
	c.turn_pair(
		&"leg_l", &"leg_r", X, [[0, 0], [0.38, 0.12], [0.5, 0.24, IN3], [0.62, 0.24], [1, 0]], true
	)
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.62, 0.6], [0.7, 0], [1, 0]])
	return c


## The Rock Rings (shielded): it folds down into a boulder, arms crossed over its bowed head and its red shell
## turned up, quaking while the rings roll out, then heaves itself open again.
static func _pattern_shielded() -> BossClip:
	var c := BossClip.new(&"pattern_shielded")
	c.turn_pair(
		&"arm_l",
		&"arm_r",
		Z,
		[
			[0, 0],
			[0.12, -0.3, OUT],
			[0.42, 1.75, BACK],
			[0.5, 1.6, IN],
			[0.62, 1.65],
			[0.8, 1.2],
			[1, 0]
		]
	)
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0], [0.42, -0.55], [0.62, -0.55], [1, 0]], true)
	c.turn_pair(&"fist_l", &"fist_r", Z, [[0, 0], [0.42, 1.3], [0.62, 1.3], [0.85, 0.4], [1, 0]])
	c.turn(
		&"torso",
		Z,
		[
			[0, 0],
			[0.12, 0.1],
			[0.42, -0.6, BACK],
			[0.5, -0.66, IN],
			[0.62, -0.62],
			[0.8, -0.3],
			[0.9, 0.08, IO, S],
			[1, 0]
		]
	)
	c.turn(&"head", Z, [[0, 0], [0.42, -0.35], [0.62, -0.35], [1, 0]])
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.12, 0.06],
			[0.42, -0.5, BACK],
			[0.5, -0.56, IN],
			[0.62, -0.52],
			[0.82, -0.2],
			[0.9, 0.06, IO, S],
			[1, 0]
		]
	)
	c.stretch(
		B,
		[
			[0, 0],
			[0.42, -0.12],
			[0.5, -0.17, IN3],
			[0.53, -0.12],
			[0.62, -0.13],
			[0.86, 0.06, OUT, S],
			[1, 0]
		]
	)
	c.turn_pair(&"leg_l", &"leg_r", X, [[0, 0], [0.42, 0.18], [0.62, 0.18], [1, 0]], true)
	c.param(&"tremble", [[0, 0], [0.48, 0], [0.5, 0.8, LIN], [0.62, 0.45], [0.66, 0], [1, 0]])
	return c


## The sweep: it winds its whole body round to the right with the right arm out wide, then whips round to the left in
## one backhand, overshooting before it settles.
static func _sweep() -> BossClip:
	var c := BossClip.new(&"sweep")
	c.turn(
		B,
		Y,
		[
			[0, 0],
			[0.42, -0.45],
			[0.47, -0.5, OUT],
			[0.5, 0.5, IN3],
			[0.54, 0.65, OUT3, S],
			[0.62, 0.55],
			[0.8, 0.3],
			[1, 0]
		]
	)
	c.turn(
		&"torso",
		Y,
		[[0, 0], [0.42, -0.45], [0.5, 0.45, IN3], [0.54, 0.55, OUT3, S], [0.62, 0.45], [1, 0]]
	)
	c.turn(
		&"arm_r", X, [[0, 0], [0.42, -1.35], [0.5, -1.25, IN3], [0.62, -1.2], [0.85, -0.4], [1, 0]]
	)
	c.turn(
		&"arm_r",
		Z,
		[[0, 0], [0.42, -0.5], [0.5, 0.9, IN3], [0.54, 1.1, OUT3, S], [0.62, 0.9], [1, 0]]
	)
	c.turn(&"fist_r", Z, [[0, 0], [0.42, 0.3], [0.5, 0.1], [1, 0]])
	c.turn(&"arm_l", Z, [[0, 0], [0.42, 0.6], [0.5, -0.4, IN3], [0.62, -0.4], [1, 0]])
	c.turn(&"arm_l", X, [[0, 0], [0.42, -0.2], [0.5, 0.5, IN3], [0.62, 0.5], [1, 0]])
	c.turn(&"torso", Z, [[0, 0], [0.42, 0.08], [0.5, -0.18, IN3], [0.62, -0.15], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, -0.12], [0.5, -0.06, IN3], [0.62, -0.08], [1, 0]])
	c.turn(&"leg_l", Z, [[0, 0], [0.42, 0.2], [0.5, -0.2, IN3], [0.62, -0.2], [1, 0]])
	c.turn(&"leg_r", Z, [[0, 0], [0.42, -0.2], [0.5, 0.25, IN3], [0.62, 0.25], [1, 0]])
	return c


## The shielded hold (over a move without its own shielded clip): arms crossed in front of the visor, crouched.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn_pair(&"arm_l", &"arm_r", Z, [[0, 0], [0.7, 1.7, BACK], [1, 1.6]])
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0], [0.7, -0.5], [1, -0.5]], true)
	c.turn_pair(&"fist_l", &"fist_r", Z, [[0, 0], [0.7, 1.2], [1, 1.2]])
	c.turn(&"torso", Z, [[0, 0], [0.7, -0.35, BACK], [1, -0.3]])
	c.shift(B, UP, [[0, 0], [0.7, -0.3, BACK], [1, -0.26]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"torso", Z, [[0, 0], [0.15, 0.2, OUT3], [0.5, -0.05, IO, S], [1, 0]])
	c.turn(&"head", Z, [[0, 0], [0.15, 0.25, OUT3], [0.5, -0.06, IO, S], [1, 0]])
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0], [0.15, 0.25, OUT3], [1, 0]], true)
	c.shift(B, FWD, [[0, 0], [0.15, -0.14, OUT3], [0.5, 0.03, IO, S], [1, 0]])
	return c


## Staggered: it reels back with its arms flung up, then slumps forward, arms hanging, head down, dazed.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(
		&"torso",
		Z,
		[[0, 0], [0.12, 0.38, OUT3], [0.22, 0.45, OUT, S], [0.5, -0.32, IO], [1, -0.36]]
	)
	c.turn(&"head", Z, [[0, 0], [0.12, 0.3, OUT3], [0.5, -0.38], [1, -0.4]])
	c.turn_pair(&"arm_l", &"arm_r", Z, [[0, 0], [0.12, 1.0, OUT3], [0.5, -0.15], [1, -0.12]])
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0], [0.12, 0.7, OUT3], [0.5, 0.12], [1, 0.1]], true)
	c.shift(B, FWD, [[0, 0], [0.12, -0.3, OUT3], [0.5, -0.12], [1, -0.12]])
	c.shift(B, UP, [[0, 0], [0.12, 0.05], [0.5, -0.28], [1, -0.3]])
	c.turn_pair(&"leg_l", &"leg_r", X, [[0, 0], [0.5, 0.14], [1, 0.14]], true)
	c.param(&"daze", [[0, 0], [0.3, 0.2], [0.6, 1], [1, 1]])
	return c


## The phase gate's roar: it gathers itself low, then throws its arms wide and high, chest out and head back,
## quaking, and settles.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.shift(B, UP, [[0, 0], [0.22, -0.22, OUT], [0.36, 0.14, BACK], [0.85, 0.1], [1, 0]])
	c.stretch(B, [[0, 0], [0.22, -0.08], [0.36, 0.1, BACK], [0.85, 0.06], [1, 0]])
	c.turn_pair(
		&"arm_l", &"arm_r", Z, [[0, 0], [0.22, -0.4], [0.36, 2.2, BACK], [0.85, 2.0], [1, 0]]
	)
	c.turn_pair(
		&"arm_l", &"arm_r", X, [[0, 0], [0.22, -0.3], [0.36, 1.0, BACK], [0.85, 0.9], [1, 0]], true
	)
	c.turn_pair(&"fist_l", &"fist_r", Z, [[0, 0], [0.36, 0.5], [0.85, 0.5], [1, 0]])
	c.turn(&"torso", Z, [[0, 0], [0.22, -0.25], [0.36, 0.38, BACK], [0.85, 0.32], [1, 0]])
	c.turn(&"head", Z, [[0, 0], [0.22, -0.2], [0.36, 0.45, BACK], [0.85, 0.4], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise-in (0..0.55 while the boss bar fills and it climbs out of the ground, then the flourish): it comes up
## arms first, fists over its head, then hammers them down to its sides with a stomp and stands.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.turn_pair(
		&"arm_l", &"arm_r", Z, [[0, 2.6], [0.5, 2.7], [0.64, 0.4, IN3], [0.7, 0.2, OUT3, S], [1, 0]]
	)
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0.35], [0.5, 0.4], [0.64, 0.6, IN3], [1, 0]], true)
	c.turn(&"torso", Z, [[0, 0.25], [0.5, 0.3], [0.64, -0.3, IN3], [0.8, -0.1], [1, 0]])
	c.turn(&"head", Z, [[0, 0.3], [0.5, 0.35], [0.64, -0.15, IN3], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.5, 0.08], [0.64, -0.26, IN3], [0.7, -0.3, OUT3, S], [1, 0]])
	c.stretch(B, [[0, 0.08], [0.5, 0.08], [0.64, -0.13, IN3], [0.74, 0.02, OUT, S], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 1, LIN], [0.75, 0], [1, 0]])
	return c


## Its death (after the sim removes it): it rears back, its knees buckle and it topples forward onto its face, bounces
## once, and sinks into the ground.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(
		B,
		Z,
		[
			[0, 0],
			[0.18, 0.18, OUT],
			[0.38, 0.1],
			[0.66, -1.38, IN3],
			[0.72, -1.3, OUT, S],
			[0.78, -1.38],
			[1, -1.38]
		]
	)
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.18, 0.04],
			[0.38, -0.3],
			[0.66, 0.42, IN3],
			[0.72, 0.55, OUT, S],
			[0.78, 0.42],
			[0.86, 0.42],
			[1, -2.6, IN]
		]
	)
	c.shift(B, FWD, [[0, 0], [0.18, -0.12], [0.66, 0.2], [1, 0.2]])
	c.turn(&"torso", Z, [[0, 0], [0.18, 0.3, OUT], [0.38, -0.2], [0.7, -0.3], [1, -0.3]])
	c.turn(&"head", Z, [[0, 0], [0.18, 0.35], [0.4, -0.3], [1, -0.2]])
	c.turn_pair(
		&"arm_l", &"arm_r", Z, [[0, 0], [0.18, 0.9, OUT], [0.4, 0.3], [0.66, 2.2, IN], [1, 2.3]]
	)
	c.turn_pair(&"arm_l", &"arm_r", X, [[0, 0], [0.18, 0.6], [0.66, 0.35], [1, 0.35]], true)
	c.turn_pair(&"leg_l", &"leg_r", Z, [[0, 0], [0.38, 0.45], [0.66, 0.1], [1, 0.1]])
	c.param(&"tremble", [[0, 0], [0.64, 0], [0.66, 1, LIN], [0.76, 0], [1, 0]])
	return c
