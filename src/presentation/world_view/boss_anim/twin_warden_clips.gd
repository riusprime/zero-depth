class_name TwinWardenClips
extends RefCounted
## v0.9.0 NB2: the Twin Wardens' clips, one library for both bodies so they move as a pair. Model frame: +X the front,
## +Z the right. The whole figure moves through BODY (the model's pivot), the same on both models: the owner's amber
## Warden keeps its Mixamo skeleton, but its file weights almost every vertex to the hips (evidence/BOSSES_NB.md), so
## only the whole figure can move; the violet one is cut into parts (Body, Helm, Shield, Sword), which add small
## accents on top (the helm turning, the shield set, the sword raised) that the amber's skeleton ignores (it has no
## such bones). Parameters the avatar maps: glow (the cracks' and visor's light) and chain (how hard the shackle hand
## pulls on the chain, for the chain's view).
## Stone sentinels: they stand planted and breathe slowly; they march in step, heavy and stiff; for Crossfire they set
## their shields and lean in as the embers pour out (shielded); for the Chain Sweep they rear back on the chain and
## heave it across; for the Shield Bash they lift and slam their weight down; a jolt, a dazed sway, a roar arms wide,
## rising out of the floor, and a toppling collapse.

const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
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
			_crossfire(),
			_chain_sweep(),
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


## Planted, breathing slowly; the helm looking about.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.stretch(B, [[0, 0], [0.5, 0.015], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.5, -0.02], [1, 0]])
	c.turn(&"helm", Y, [[0, 0.08], [0.5, -0.08], [1, 0.08]])
	c.param(&"glow", [[0, 0], [0.5, 0.3], [1, 0]])
	return c


## The march: a heavy, stiff stride, the body rolling side to side and dipping on each step.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.shift(B, UP, [[0, 0], [0.25, 0.06, OUT], [0.5, 0, IO], [0.75, 0.06, OUT], [1, 0, IO]])
	c.turn(B, X, [[0, 0.07], [0.5, -0.07], [1, 0.07]])
	c.turn(B, Z, [[0, -0.05], [1, -0.05]])
	c.turn(&"shield", Z, [[0, 0.06], [0.5, -0.06], [1, 0.06]])
	c.turn(&"sword", Z, [[0, -0.1], [0.5, 0.1], [1, -0.1]])
	return c


## Crossfire: they plant their feet and set their shields, leaning in as the embers pour out through the active part.
static func _crossfire() -> BossClip:
	var c := BossClip.new(&"crossfire")
	c.turn(B, Z, [[0, 0], [0.42, 0.1, BACK], [0.5, -0.12, IN3], [0.62, -0.1], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, -0.08], [0.5, -0.12, IN3], [0.62, -0.1], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.03], [0.5, -0.05, IN3], [0.62, -0.03], [1, 0]])
	c.turn(&"shield", Y, [[0, 0], [0.42, 0.3], [0.5, 0.35], [0.62, 0.3], [1, 0]])
	c.turn(&"sword", Z, [[0, 0], [0.42, 0.5, BACK], [0.5, -0.3, IN3], [0.62, -0.2], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 1.0], [0.5, 1.6, IN3], [0.62, 1.3], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.48, 0], [0.5, 0.4, LIN], [0.56, 0], [1, 0]])
	return c


## The Chain Sweep: they rear back, hauling the chain taut (tracking), then heave it across on the strike.
static func _chain_sweep() -> BossClip:
	var c := BossClip.new(&"chain_sweep")
	c.turn(
		B,
		Z,
		[
			[0, 0],
			[0.42, 0.22, BACK],
			[0.5, -0.2, IN3],
			[0.56, -0.26, OUT3, S],
			[0.62, -0.15],
			[1, 0]
		]
	)
	c.turn(B, Y, [[0, 0], [0.42, 0.35], [0.5, -0.4, IN3], [0.62, -0.3], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.42, -0.15], [0.5, 0.25, IN3], [0.62, 0.15], [1, 0]])
	c.turn(&"shield", Z, [[0, 0], [0.42, -0.4], [0.5, 0.5, IN3], [0.62, 0.3], [1, 0]])
	c.param(&"chain", [[0, 0], [0.42, 1.0], [0.5, 1.4, IN3], [0.62, 0.6], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.8], [0.5, 1.4, IN3], [0.62, 0.6], [1, 0]])
	return c


## The Shield Bash: it lifts its weight onto its toes, then slams down behind its shield.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.42, 0.22, BACK],
			[0.5, -0.18, IN3],
			[0.55, -0.22, OUT3, S],
			[0.62, -0.15],
			[1, 0]
		]
	)
	c.turn(B, Z, [[0, 0], [0.42, 0.16], [0.5, -0.3, IN3], [0.62, -0.25], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.06], [0.5, -0.1, IN3], [0.62, -0.05], [1, 0]])
	c.shift(&"shield", FWD, [[0, 0], [0.42, -0.05], [0.5, 0.15, IN3], [0.62, 0.1], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.6, 0], [1, 0]])
	c.param(&"glow", [[0, 0], [0.42, 0.6], [0.5, 1.2, IN3], [0.62, 0.5], [1, 0]])
	return c


## The shielded hold: braced behind the shield, the cracks blazing.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(B, Z, [[0, 0], [1, -0.08]])
	c.shift(B, UP, [[0, 0], [1, -0.06]])
	c.turn(&"shield", Y, [[0, 0], [1, 0.25]])
	c.param(&"glow", [[0, 0], [1, 1.0]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(B, Z, [[0, 0], [0.15, 0.1, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	c.turn(&"helm", Z, [[0, 0], [0.15, 0.2, OUT3], [1, 0]])
	return c


static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(B, Z, [[0, 0], [0.2, 0.22, OUT3], [1, 0.18]])
	c.shift(B, UP, [[0, 0], [0.2, -0.15, OUT3], [1, -0.12]])
	c.turn(&"sword", Z, [[0, 0], [0.2, -0.4, OUT3], [1, -0.35]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"glow", [[0, 0], [0.2, -0.6], [1, -0.6]])
	return c


## The phase gate's roar: it rears up, arms wide, the cracks blazing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(B, Z, [[0, 0], [0.3, 0.25, BACK], [0.8, 0.2], [1, 0]])
	c.stretch(B, [[0, 0], [0.3, 0.05], [0.8, 0.04], [1, 0]])
	c.turn(&"shield", X, [[0, 0], [0.3, 0.5, BACK], [0.8, 0.45], [1, 0]])
	c.turn(&"sword", X, [[0, 0], [0.3, -0.5, BACK], [0.8, -0.45], [1, 0]])
	c.param(&"glow", [[0, 0], [0.3, 1.8], [0.8, 1.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.8], [0.8, 0.8], [1, 0]])
	return c


## Rising out of the floor: from sunk and bowed to upright, settling with a thud.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -1.4], [0.55, -0.2, OUT3], [0.8, 0.04, OUT, S], [1, 0]])
	c.turn(B, Z, [[0, -0.35], [0.6, -0.08], [1, 0]])
	return c


## The collapse: it sags, then topples forward and sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(B, Z, [[0, 0], [0.3, 0.1], [0.8, -0.9, IN3], [1, -1.0]])
	c.shift(B, UP, [[0, 0], [0.3, 0.04], [0.85, -0.5, IN3], [1, -0.7]])
	c.param(&"glow", [[0, 0], [0.3, 1.0], [1, -1.0]])
	return c
