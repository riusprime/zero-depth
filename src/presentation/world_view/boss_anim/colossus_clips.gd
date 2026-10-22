class_name ColossusClips
extends RefCounted
## v0.8.0 FB1 (owner O17: "big stone hands … a fast moving pace fight"; FINAL_BOSS.md F4; Q4: code clips first, the
## owner's animated model replaces them by the same names): the Colossus's placeholder clips over the bones BossRig cuts
## from its mesh (body, chest, halo, and the two fists, separate pieces hung from shoulder pivots). Parameters the
## avatar maps: `hook` (-1 wound up .. +1 struck: the combo's swing, on the right fist, then the left, and as the
## two-fisted slam on its last strike; ColossusAvatar picks which from the strike), `halo_flare` (the halo spins faster
## while it is up). A heavy brawler that never stands still: the fists hover and drift beside it when idle and pump as
## it stalks, hooks that wind far back and whip across, a two-fisted hammer into the floor, a crouched leap with both
## fists raised that lands in a smash, a boulder hauled up in the right fist and hurled, one fist punched into the floor
## to send the spikes chasing and both slammed down for the burst; a jolt, a stagger with the fists sagging, a roar with
## the fists thrown wide, a rise that pulls the fists in from the ground, and a fall that drops them.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
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
			_combo(),
			_leap(),
			_marks(),
			_spike_chase(),
			_spike_burst(),
			_shielded(),
			_flinch(),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


## Breathing; the fists hover and drift a little, out of step; the halo turns slowly.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.shift(&"chest", UP, [[0, 0], [0.5, 0.04], [1, 0]])
	c.shift(&"fist_l", UP, [[0, 0], [0.5, 0.12], [1, 0]])
	c.shift(&"fist_r", UP, [[0, 0.12], [0.5, 0], [1, 0.12]])
	c.turn(&"fist_l", Z, [[0, 0.05], [0.5, 0.12], [1, 0.05]])
	c.turn(&"fist_r", Z, [[0, 0.12], [0.5, 0.05], [1, 0.12]])
	return c


## A fast stalking stride: the body bobs and leans in, the fists pump in turn.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.shift(B, UP, [[0, 0], [0.25, 0.08, OUT], [0.5, 0, IN], [0.75, 0.08, OUT], [1, 0, IN]])
	c.turn(B, Z, [[0, -0.12], [1, -0.12]])
	c.turn(B, X, [[0, 0.05], [0.5, -0.05], [1, 0.05]])
	c.turn(&"fist_l", Z, [[0, -0.35], [0.5, 0.45], [1, -0.35]])
	c.turn(&"fist_r", Z, [[0, 0.45], [0.5, -0.35], [1, 0.45]])
	return c


## The combo: each strike cycles strike..hold (one swing a cycle, the slam last). The windup winds the fist (or both)
## far back, the strike whips it across (or hammers both down), held a beat, then it recovers.
static func _combo() -> BossClip:
	var c := BossClip.new(&"combo")
	c.param(
		&"hook",
		[[0, 0], [0.4, -1.0, OUT], [0.5, 1.0, IN3], [0.56, 1.05, OUT3, S], [0.62, 0.9], [1, 0]]
	)
	c.turn(B, UP, [[0, 0], [0.4, 0.35], [0.5, -0.3, IN3], [0.62, -0.25], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.4, 0.1], [0.5, -0.22, IN3], [0.62, -0.18], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.4, -0.15], [0.5, 0.45, IN3], [0.62, 0.4], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.6, LIN], [0.58, 0], [1, 0]])
	return c


## The leap: a deep crouch with both fists raised overhead, the jump (the avatar arcs the body), and the landing
## smash with both fists, the halo flaring.
static func _leap() -> BossClip:
	var c := BossClip.new(&"leap")
	for f: StringName in [&"fist_l", &"fist_r"]:
		c.turn(f, Z, [[0, 0], [0.4, 2.3, BACK], [0.5, 2.5], [0.58, 0.9, IN3], [0.66, 0.8], [1, 0]])
		c.shift(f, UP, [[0, 0], [0.5, 0.2], [0.58, -0.9, IN3], [0.66, -0.8], [1, 0]])
	c.shift(
		B,
		UP,
		[[0, 0], [0.4, -0.45, BACK], [0.5, 0.2, OUT], [0.58, -0.35, IN3], [0.7, -0.1], [1, 0]]
	)
	c.stretch(
		B, [[0, 0], [0.4, -0.12], [0.5, 0.12, OUT], [0.58, -0.16, IN3], [0.7, 0.04, IO, S], [1, 0]]
	)
	c.param(&"halo_flare", [[0, 0], [0.5, 0.2], [0.58, 1.0, IN3], [0.8, 0.6], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.57, 0], [0.58, 1, LIN], [0.66, 0], [1, 0]])
	return c


## The boulder throw (`marks`): the right fist hauls a boulder up from the floor and over the shoulder, then hurls it
## forward on each throw (strike), the body twisting into it.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	c.turn(
		&"fist_r", Z, [[0, 0], [0.2, -0.6], [0.45, 2.6, BACK], [0.5, 1.0, IN3], [0.62, 0.7], [1, 0]]
	)
	c.shift(&"fist_r", UP, [[0, 0], [0.2, -0.5], [0.45, 0.4], [0.62, 0], [1, 0]])
	c.turn(B, UP, [[0, 0], [0.45, -0.4], [0.5, 0.3, IN3], [0.62, 0.2], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.45, 0.15], [0.5, -0.2, IN3], [0.62, -0.1], [1, 0]])
	c.turn(&"fist_l", Z, [[0, 0], [0.45, -0.4], [0.5, 0.4, IN3], [1, 0]])
	return c


## The spike chase: one fist raised high, then punched into the floor, held there while the spikes run.
static func _spike_chase() -> BossClip:
	var c := BossClip.new(&"spike_chase")
	c.turn(
		&"fist_r", Z, [[0, 0], [0.42, 2.4, BACK], [0.5, 0.7, IN3], [0.62, 0.7], [0.85, 0.3], [1, 0]]
	)
	c.shift(
		&"fist_r", UP, [[0, 0], [0.42, 0.3], [0.5, -1.1, IN3], [0.62, -1.05], [0.85, -0.3], [1, 0]]
	)
	c.turn(B, Z, [[0, 0], [0.42, 0.18], [0.5, -0.3, IN3], [0.62, -0.28], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, 0.05], [0.5, -0.25, IN3], [0.62, -0.22], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.8, LIN], [0.6, 0.2], [0.7, 0], [1, 0]])
	return c


## The spike burst: both fists thrown wide and up, then slammed into the floor either side, the halo flaring as the
## rings of spikes run out.
static func _spike_burst() -> BossClip:
	var c := BossClip.new(&"spike_burst")
	c.turn_pair(
		&"fist_l",
		&"fist_r",
		X,
		[[0, 0], [0.42, 0.9, BACK], [0.5, -0.2, IN3], [0.62, -0.2], [1, 0]],
		true
	)
	for f: StringName in [&"fist_l", &"fist_r"]:
		c.shift(f, UP, [[0, 0], [0.42, 0.5], [0.5, -1.1, IN3], [0.62, -1.0], [0.85, -0.3], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, 0.12], [0.5, -0.3, IN3], [0.62, -0.28], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.08], [0.5, -0.14, IN3], [0.62, -0.1], [1, 0]])
	c.param(&"halo_flare", [[0, 0], [0.5, 0.2], [0.62, 1.0, OUT], [0.85, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.64, 0], [1, 0]])
	return c


## Shielded (none of its moves are; the common hold): fists crossed in front.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn_pair(&"fist_l", &"fist_r", Z, [[0, 0], [0.7, 1.3, BACK], [1, 1.2]])
	c.turn_pair(&"fist_l", &"fist_r", UP, [[0, 0], [0.7, 0.6], [1, 0.6]], true)
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(B, Z, [[0, 0], [0.15, 0.12, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.12, OUT3], [1, 0]])
	return c


## Staggered: it reels back, the fists sagging to the floor, the halo slowing.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(B, Z, [[0, 0], [0.1, 0.18, OUT3], [0.4, 0.08], [1, 0.08]])
	c.shift(B, UP, [[0, 0], [0.4, -0.25], [1, -0.22]])
	for f: StringName in [&"fist_l", &"fist_r"]:
		c.shift(f, UP, [[0, 0], [0.4, -0.6], [1, -0.55]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The roar: fists thrown wide, the body reared back, shaking.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn_pair(&"fist_l", &"fist_r", X, [[0, 0], [0.36, 1.2, BACK], [0.85, 1.1], [1, 0]], true)
	c.turn(B, Z, [[0, 0], [0.2, -0.06], [0.36, 0.3, BACK], [0.85, 0.26], [1, 0]])
	c.stretch(B, [[0, 0], [0.36, 0.12, BACK], [0.85, 0.1], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise (out of the Colossus's place in the arena, or out of shards): it comes up hunched, its fists pulled in
## from the floor, then straightens.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -0.4], [0.5, -0.35], [0.64, 0.12, IN3], [0.74, -0.03, OUT, S], [1, 0]])
	c.turn(B, Z, [[0, -0.3], [0.5, -0.25], [0.7, 0.05, OUT], [1, 0]])
	for f: StringName in [&"fist_l", &"fist_r"]:
		c.shift(f, UP, [[0, -1.2], [0.5, -1.0], [0.7, 0.1, OUT], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 0.8, LIN], [0.74, 0], [1, 0]])
	return c


## Its fall (only seen without the final fight's shatter: the Playground's lone summon): the fists drop, it crumples.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	for f: StringName in [&"fist_l", &"fist_r"]:
		c.shift(f, UP, [[0, 0], [0.4, -1.4, IN], [1, -1.5]])
	c.shift(B, UP, [[0, 0], [0.15, 0.08], [0.55, -0.6, IN], [0.84, -0.7], [1, -3.1, IN]])
	c.turn(B, Z, [[0, 0], [0.55, -0.4, IN], [1, -0.45]])
	return c
