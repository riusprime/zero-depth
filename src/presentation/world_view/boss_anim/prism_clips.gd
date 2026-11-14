class_name PrismClips
extends RefCounted
## The Prism's clips (the owner's torn hooded figure with nine crystals floating round her, one skinned mesh on a full
## skeleton). Her file carries its own idle, its float, her five moves, her forming and her breaking; PrismAvatar
## plays those in place of the clips of the same moves here (idle, walk, cross, pattern, bolt_fan, lances, kneel, rise,
## shatter), which keep only their named parameters. The clips played from here, over the file's idle, turn her
## bones: BODY_BONE carries the whole figure (not the floating crystals), CHEST and HEAD bend it, LIFT raises and
## lowers the crystals with her.
## - shielded: braced, "shield" 1; flinch: a hit throws the chest and the hood back; stagger: she sags, the hood
##   hanging, the crystals sinking; roar: she rises with the hood thrown back, the crystals lifting higher; death:
##   she folds and drops, the crystals after her;
## - pulse: a short jolt up as a crystal fires, the avatar's own layer on the whole model.
## The replaced clips, by what their move is:
## - cross: the Cross: the spin-up (0 .. strike), the spin (strike .. SPIN_END), the window (SPIN_END .. hold);
## - pattern: an orb spell; bolt_fan: a lone bolt (only when the dev panel starts her bolt attack by itself; in her
##   fight it fires in a Cross).
## Model frame: +X the front. A turn about Z leans back (+) or forward (-).
## Presentation only.

const UP := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const FWD := Vector3(1, 0, 0)
const B := BossClip.BODY
## The bones the clips turn, spelt as the model file exports them.
const BODY_BONE := &"body"
const CHEST := &"chest"
const HEAD := &"head"
const LIFT := &"shards_lift"
const IO := BossClip.IN_OUT
const IN3 := BossClip.IN3
const IN := BossClip.IN
const OUT := BossClip.OUT
const OUT3 := BossClip.OUT3
const BACK := BossClip.BACK
const LIN := BossClip.LINEAR
const S := BossClip.SETTLE
## The cross clip's times: the spin-up ends at STRIKE (the beams open), the spin at SPIN_END (the window opens), the
## window at HOLD (the recovery). Matches the shipped Cross: a 1.0 s windup, then 5.0 s of spin and 2.5 s of window
## over the clip's strike .. hold.
const STRIKE := 0.25
const SPIN_END := 0.74
const HOLD := 0.98
## The clips the library holds (tests check each is there).
const NAMES: Array[StringName] = [
	&"idle",
	&"walk",
	&"cross",
	&"pulse",
	&"shielded",
	&"flinch",
	&"stagger",
	&"roar",
	&"rise",
	&"death",
	&"shatter",
	&"bolt_fan",
	&"pattern",
	&"lances",  # Her last phase
	&"kneel",
]

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		var idle := BossClip.new(&"idle", true)
		idle.shift(B, UP, [[0, 0], [0.5, 0.16, IO], [1, 0, IO]])
		idle.turn(B, UP, [[0, -0.12], [0.5, 0.12, IO], [1, -0.12, IO]])
		idle.turn(B, Z, [[0, 0.02], [0.5, -0.02, IO], [1, 0.02, IO]])
		idle.param(&"spin", [[0, 0.25], [1, 0.25]])
		var walk := BossClip.new(&"walk", true)
		walk.shift(B, UP, [[0, 0.1], [0.5, 0.18, IO], [1, 0.1, IO]])
		walk.turn(B, Z, [[0, -0.1], [1, -0.1]])
		walk.param(&"spin", [[0, 0.35], [1, 0.35]])
		var cross := BossClip.new(&"cross")
		cross.strike = STRIKE
		cross.hold = HOLD
		cross.shift(
			B,
			UP,
			[
				[0, 0],
				[0.12, -0.12, IO],
				[STRIKE, 0.55, BACK],
				[0.5, 0.62, IO],
				[SPIN_END, 0.55],
				[0.8, 0.05, IN3],
				[HOLD, 0.0],
				[1, 0]
			]
		)
		cross.stretch(
			B,
			[
				[0, 0],
				[0.12, -0.08],
				[STRIKE, 0.1, OUT3],
				[0.3, 0.04, OUT, S],
				[SPIN_END, 0.04],
				[0.8, -0.1, IN3],
				[HOLD, -0.06],
				[1, 0]
			]
		)
		cross.turn(
			B,
			Z,
			[[0, 0], [STRIKE, -0.06], [SPIN_END, -0.06], [0.8, 0.18, IN3], [HOLD, 0.15], [1, 0]]
		)
		cross.param(
			&"spin",
			[[0, 0.25], [STRIKE, 1.0, IN], [SPIN_END, 1.0], [0.78, 0.1, OUT], [HOLD, 0.1], [1, 0]]
		)
		cross.param(
			&"charge",
			[[0, 0], [STRIKE, 1.0, IN], [0.3, 0.6, OUT], [SPIN_END, 0.6], [0.76, 0.0], [1, 0]]
		)
		cross.param(&"open", [[0, 0], [SPIN_END, 0], [0.77, 1.0, OUT], [HOLD, 1.0], [1, 0]])
		var pulse := BossClip.new(&"pulse")
		pulse.shift(B, UP, [[0, 0], [0.2, 0.12, OUT3], [1, 0, IO]])
		pulse.turn(B, Z, [[0, 0], [0.2, -0.08, OUT3], [1, 0, IO]])
		pulse.param(&"flare", [[0, 0], [0.15, 1.0, OUT3], [1, 0, IN]])
		var shielded := BossClip.new(&"shielded")
		shielded.stretch(BODY_BONE, [[0, 0], [0.7, -0.06, BACK], [1, -0.05]])
		shielded.turn(HEAD, Z, [[0, 0], [0.7, -0.14, BACK], [1, -0.12]])
		shielded.param(&"shield", [[0, 0], [0.5, 1.0, OUT], [1, 1.0]])
		var flinch := BossClip.new(&"flinch")
		flinch.turn(CHEST, Z, [[0, 0], [0.15, 0.16, OUT3], [0.5, -0.03, IO, S], [1, 0]])
		flinch.turn(HEAD, Z, [[0, 0], [0.2, 0.2, OUT3], [0.6, -0.04, IO, S], [1, 0]])
		flinch.shift(BODY_BONE, FWD, [[0, 0], [0.15, -0.14, OUT3], [1, 0]])
		flinch.shift(BODY_BONE, UP, [[0, 0], [0.15, -0.08, OUT3], [1, 0]])
		var stagger := BossClip.new(&"stagger")
		stagger.turn(BODY_BONE, Z, [[0, 0], [0.1, 0.2, OUT3], [0.4, 0.1], [1, 0.1]])
		stagger.turn(HEAD, Z, [[0, 0], [0.4, -0.3], [1, -0.28]])
		stagger.shift(BODY_BONE, UP, [[0, 0], [0.4, -0.3], [1, -0.28]])
		stagger.shift(LIFT, UP, [[0, 0], [0.5, -0.2], [1, -0.18]])
		stagger.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
		var roar := BossClip.new(&"roar")
		roar.shift(BODY_BONE, UP, [[0, 0], [0.36, 0.4, BACK], [0.85, 0.35], [1, 0]])
		roar.turn(CHEST, Z, [[0, 0], [0.36, 0.14, BACK], [0.85, 0.12], [1, 0]])
		roar.turn(HEAD, Z, [[0, 0], [0.36, 0.25, BACK], [0.85, 0.22], [1, 0]])
		roar.shift(LIFT, UP, [[0, 0], [0.36, 0.55, BACK], [0.85, 0.5], [1, 0]])
		roar.param(&"spin", [[0, 0.25], [0.36, 1.2], [0.85, 1.0], [1, 0]])
		var rise := BossClip.new(&"rise")
		rise.shift(B, UP, [[0, -0.8], [0.5, -0.5], [0.7, 0.2, OUT], [0.8, -0.02, OUT, S], [1, 0]])
		rise.stretch(B, [[0, -0.25], [0.5, -0.15], [0.7, 0.1, OUT], [1, 0]])
		rise.param(&"spin", [[0, 1.5], [0.7, 0.8], [1, 0]])
		var death := BossClip.new(&"death")
		death.shift(
			BODY_BONE, UP, [[0, 0], [0.15, 0.2], [0.55, -0.3, IN], [0.84, -0.4], [1, -3.0, IN]]
		)
		death.turn(BODY_BONE, Z, [[0, 0], [0.55, -0.5, IN], [1, -0.55]])
		death.shift(LIFT, UP, [[0, 0], [0.4, 0.1], [1, -3.2, IN]])
		death.param(&"open", [[0, 0], [0.4, 1.0], [1, 1.0]])
		# The file's "break" is the whole shatter, and FinalBodyAvatar trembles the body: nothing to add here.
		var shatter := BossClip.new(&"shatter")
		var bolt := BossClip.new(&"bolt_fan")  # a lone bolt (the dev panel's start): a shard's flick
		bolt.shift(B, UP, [[0, 0], [0.42, 0.1, BACK], [0.5, 0.04, IN3], [1, 0]])
		bolt.turn(B, Z, [[0, 0], [0.42, 0.06], [0.5, -0.06, IN3], [1, 0]])
		bolt.param(&"flare", [[0, 0], [0.42, 0.6], [0.5, 1.0, IN3], [1, 0]])
		var orbs := BossClip.new(&"pattern")  # An orb spell
		orbs.strike = 0.12
		orbs.hold = 0.9
		orbs.shift(B, UP, [[0, 0], [0.1, -0.1, IO], [0.12, 0.45, BACK], [0.9, 0.4], [1, 0, IO]])
		orbs.stretch(B, [[0, 0], [0.1, -0.06], [0.12, 0.08, OUT3], [0.2, 0.03, OUT, S], [1, 0]])
		orbs.param(&"charge", [[0, 0], [0.12, 1.0, IN], [0.2, 0.4, OUT], [0.9, 0.4], [1, 0]])
		orbs.param(&"spin", [[0, 0.25], [0.12, 1.2, IN], [0.9, 1.0], [1, 0]])
		for c: BossClip in [
			idle,
			walk,
			cross,
			pulse,
			shielded,
			flinch,
			stagger,
			roar,
			rise,
			death,
			shatter,
			bolt,
			orbs
		]:
			_lib[c.name] = c
		for c: BossClip in _last_phase():
			_lib[c.name] = c
		BossClip.loosen(_lib, 0.0, 1.25)  # The wind-up, the recoil, the idle sway
	return _lib


## Her last phase's clips.
## - lances: the Facet Lances: she gathers (the windup: she rises, "charge" glowing, the shards racing out, "spin"),
##   holds aloft and flicks at each lance ("flare" pulses) while they strike, and sinks back to the float;
## - kneel: the Shattered Kneel: she falls (the windup: a drop and a lurch), lies low and tilted, "open" 1 and the
##   shards stilled ("spin" 0), trembling a little while her core shows, then rises back up (the recovery).
static func _last_phase() -> Array[BossClip]:
	var lances := BossClip.new(&"lances")
	lances.strike = 0.2
	lances.hold = 0.92
	lances.shift(B, UP, [[0, 0], [0.12, -0.12, IO], [0.2, 0.6, BACK], [0.92, 0.5], [1, 0, IO]])
	lances.stretch(B, [[0, 0], [0.12, -0.08], [0.2, 0.12, OUT3], [0.3, 0.05, OUT, S], [1, 0]])
	lances.param(&"charge", [[0, 0], [0.2, 1.0, IN], [0.92, 0.6], [1, 0]])
	lances.param(&"spin", [[0, 0.25], [0.2, 1.6, IN], [0.92, 1.2], [1, 0]])
	var flare := [[0, 0], [0.2, 0.4]]
	for k in 6:
		var t := 0.2 + (0.92 - 0.2) * (k + 1) / 7.0
		flare.append([t - 0.03, 0.3])
		flare.append([t, 1.0, OUT3])
	flare.append([1, 0])
	lances.param(&"flare", flare)
	var kneel := BossClip.new(&"kneel")
	kneel.strike = 0.15
	kneel.hold = 0.86
	kneel.shift(
		B,
		UP,
		[
			[0, 0],
			[0.05, 0.15, OUT],
			[0.15, -0.95, IN3],
			[0.2, -0.85, OUT, S],
			[0.86, -0.9],
			[1, 0, BACK]
		]
	)
	kneel.turn(B, Z, [[0, 0], [0.15, 0.32, IN3], [0.86, 0.3], [1, 0, IO]])
	kneel.turn(B, X, [[0, 0], [0.15, -0.18, IN3], [0.86, -0.16], [1, 0, IO]])
	kneel.stretch(B, [[0, 0], [0.15, -0.14, IN3], [0.86, -0.12], [0.93, 0.08, OUT], [1, 0]])
	kneel.param(&"open", [[0, 0], [0.15, 1.0, OUT], [0.86, 1.0], [1, 0]])
	kneel.param(&"spin", [[0, 0.25], [0.15, 0.0], [0.86, 0.0], [1, 0]])
	kneel.param(&"tremble", [[0, 0], [0.15, 0.6, OUT3], [0.3, 0.25], [0.86, 0.35], [1, 0]])
	return [lances, kneel]
