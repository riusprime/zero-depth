class_name PrismClips
extends RefCounted
## v0.8.0 FB2 (owner Q4: code clips first, the owner's animated model replaces them by name; FINAL_BOSS.md F5): the
## Prism's placeholder clips over her rig (BossRig: the body and her floating shards, each its own bone; PrismAvatar
## orbits the shards and flares them). Whole-body motion here (BossClip.BODY) plus named parameters the avatar reads:
## - idle: the float (a slow bob and sway), "spin" 0.25 (the shards' slow orbit);
## - walk: a glide (she leans into it);
## - cross: the Cross: the spin-up (0 .. strike: she rises and opens, "spin" climbing to 1, "charge" glowing), the
##   spin itself (strike .. SPIN_END: aloft, the shards racing round), then the window (SPIN_END .. hold: she sags,
##   "open" 1, the shards slow and drift wide) and the recovery back to the float;
## - cast: a short pulse as a shard fires (a jolt up, "flare" 1), the avatar's own layer;
## - shielded: braced, "shield" 1; flinch: a hit; stagger, roar, rise (from the Colossus's shards), death;
## - shatter: the crack-up between bodies, "tremble" climbing (the avatar's own layer, as FinalBodyAvatar trembles);
## - bolt_fan: a lone bolt (only when the dev panel starts her bolt attack by itself; in her fight it fires in a Cross).
## - pattern (v0.8.0 PR, owner O84): an orb spell: she gathers through its telegraph ("charge"), then rises and holds
##   aloft with the shards racing round ("spin") while her orbs pour out of her, and sinks back to the float.
## Presentation only.

const UP := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
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
	&"cast",
	&"shielded",
	&"flinch",
	&"stagger",
	&"roar",
	&"rise",
	&"death",
	&"shatter",
	&"bolt_fan",
	&"pattern",
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
		var cast := BossClip.new(&"cast")
		cast.shift(B, UP, [[0, 0], [0.2, 0.12, OUT3], [1, 0, IO]])
		cast.turn(B, Z, [[0, 0], [0.2, -0.08, OUT3], [1, 0, IO]])
		cast.param(&"flare", [[0, 0], [0.15, 1.0, OUT3], [1, 0, IN]])
		var shielded := BossClip.new(&"shielded")
		shielded.stretch(B, [[0, 0], [0.7, -0.06, BACK], [1, -0.05]])
		shielded.param(&"shield", [[0, 0], [0.5, 1.0, OUT], [1, 1.0]])
		var flinch := BossClip.new(&"flinch")
		flinch.turn(B, Z, [[0, 0], [0.15, 0.16, OUT3], [0.5, -0.03, IO, S], [1, 0]])
		flinch.shift(B, FWD, [[0, 0], [0.15, -0.18, OUT3], [1, 0]])
		flinch.shift(B, UP, [[0, 0], [0.15, -0.1, OUT3], [1, 0]])
		var stagger := BossClip.new(&"stagger")
		stagger.turn(B, Z, [[0, 0], [0.1, 0.2, OUT3], [0.4, 0.1], [1, 0.1]])
		stagger.shift(B, UP, [[0, 0], [0.4, -0.3], [1, -0.28]])
		stagger.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
		var roar := BossClip.new(&"roar")
		roar.shift(B, UP, [[0, 0], [0.36, 0.4, BACK], [0.85, 0.35], [1, 0]])
		roar.stretch(B, [[0, 0], [0.36, 0.12, BACK], [0.85, 0.1], [1, 0]])
		roar.param(&"spin", [[0, 0.25], [0.36, 1.2], [0.85, 1.0], [1, 0]])
		var rise := BossClip.new(&"rise")
		rise.shift(B, UP, [[0, -0.8], [0.5, -0.5], [0.7, 0.2, OUT], [0.8, -0.02, OUT, S], [1, 0]])
		rise.stretch(B, [[0, -0.25], [0.5, -0.15], [0.7, 0.1, OUT], [1, 0]])
		rise.param(&"spin", [[0, 1.5], [0.7, 0.8], [1, 0]])
		var death := BossClip.new(&"death")
		death.shift(B, UP, [[0, 0], [0.15, 0.2], [0.55, -0.3, IN], [0.84, -0.4], [1, -3.0, IN]])
		death.turn(B, Z, [[0, 0], [0.55, -0.5, IN], [1, -0.55]])
		death.param(&"open", [[0, 0], [0.4, 1.0], [1, 1.0]])
		var shatter := BossClip.new(&"shatter")
		shatter.shift(B, UP, [[0, 0], [0.3, 0.15, OUT], [0.9, -0.1, IN], [1, 0]])
		shatter.param(&"tremble", [[0, 0], [0.2, 0.2], [0.9, 1.0, IN], [1, 0]])
		shatter.param(&"spin", [[0, 0.25], [0.9, 2.0, IN], [1, 0]])
		var bolt := BossClip.new(&"bolt_fan")  # a lone bolt (the dev panel's start): a shard's flick
		bolt.shift(B, UP, [[0, 0], [0.42, 0.1, BACK], [0.5, 0.04, IN3], [1, 0]])
		bolt.turn(B, Z, [[0, 0], [0.42, 0.06], [0.5, -0.06, IN3], [1, 0]])
		bolt.param(&"flare", [[0, 0], [0.42, 0.6], [0.5, 1.0, IN3], [1, 0]])
		var orbs := BossClip.new(&"pattern")  # v0.8.0 PR: an orb spell
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
			cast,
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
	return _lib
