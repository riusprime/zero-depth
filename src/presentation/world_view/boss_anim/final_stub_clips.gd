class_name FinalStubClips
extends RefCounted
## v0.8.0 FB1 (FINAL_BOSS.md F5, F6): placeholder clips for the final boss's later bodies, the Prism and the Nemesis,
## whose fights are FB2's and FB3's. No longer used: the Prism plays PrismClips (FB2), the Nemesis NemesisClips (FB3).
## Whole-body motion only (the model's pivot, BossClip.BODY): the Prism floats and turns, pulses as it fires and glides;
## the Nemesis sways light on its feet, lunges with its slashes and dashes, and snaps up to cast. Both share the
## reactions (a jolt, a stagger, a roar, a rise from the shards, a fall).

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

static var _prism := {}
static var _nemesis := {}


static func prism() -> Dictionary:
	if _prism.is_empty():
		var idle := BossClip.new(&"idle", true)
		idle.shift(B, UP, [[0, 0], [0.5, 0.18], [1, 0]])
		idle.turn(B, UP, [[0, 0], [0.5, 0.25], [1, 0]])
		var walk := BossClip.new(&"walk", true)
		walk.shift(B, UP, [[0, 0.1], [0.5, 0.2], [1, 0.1]])
		walk.turn(B, Z, [[0, -0.08], [1, -0.08]])
		var pattern := BossClip.new(&"pattern")
		pattern.shift(B, UP, [[0, 0], [0.42, 0.45, BACK], [0.5, 0.3, IN3], [0.62, 0.35], [1, 0]])
		pattern.stretch(B, [[0, 0], [0.42, -0.08], [0.5, 0.12, IN3], [0.56, 0.0, OUT, S], [1, 0]])
		pattern.turn(B, UP, [[0, 0], [0.5, 0.4], [0.62, 0.9, OUT], [1, 0]])
		for c: BossClip in [idle, walk, pattern] + _reactions():
			_prism[c.name] = c
	return _prism


static func nemesis() -> Dictionary:
	if _nemesis.is_empty():
		var idle := BossClip.new(&"idle", true)
		idle.turn(B, X, [[0, 0.04], [0.5, -0.04], [1, 0.04]])
		idle.shift(B, UP, [[0, 0], [0.5, 0.03], [1, 0]])
		var walk := BossClip.new(&"walk", true)
		walk.shift(B, UP, [[0, 0], [0.25, 0.06, OUT], [0.5, 0, IN], [0.75, 0.06, OUT], [1, 0, IN]])
		walk.turn(B, Z, [[0, -0.15], [1, -0.15]])
		var sweep := BossClip.new(&"sweep")
		sweep.turn(B, UP, [[0, 0], [0.42, 0.7, BACK], [0.5, -0.9, IN3], [0.62, -0.8], [1, 0]])
		sweep.shift(B, FWD, [[0, 0], [0.42, -0.1], [0.5, 0.3, IN3], [0.62, 0.25], [1, 0]])
		var charge := BossClip.new(&"charge")
		charge.turn(B, Z, [[0, 0], [0.42, -0.35], [0.5, -0.5, IN3], [0.62, -0.45], [1, 0]])
		charge.stretch(B, [[0, 0], [0.42, -0.1], [0.5, -0.05], [1, 0]])
		var pattern := BossClip.new(&"pattern")
		pattern.shift(B, UP, [[0, 0], [0.42, 0.2, BACK], [0.5, 0.05, IN3], [1, 0]])
		pattern.turn(B, Z, [[0, 0], [0.42, 0.2], [0.5, -0.15, IN3], [1, 0]])
		for c: BossClip in [idle, walk, sweep, charge, pattern] + _reactions():
			_nemesis[c.name] = c
	return _nemesis


## The shared reactions: shielded, flinch, stagger, roar, rise, death.
static func _reactions() -> Array[BossClip]:
	var shielded := BossClip.new(&"shielded")
	shielded.stretch(B, [[0, 0], [0.7, -0.08, BACK], [1, -0.06]])
	var flinch := BossClip.new(&"flinch")
	flinch.turn(B, Z, [[0, 0], [0.15, 0.14, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	flinch.shift(B, FWD, [[0, 0], [0.15, -0.12, OUT3], [1, 0]])
	var stagger := BossClip.new(&"stagger")
	stagger.turn(B, Z, [[0, 0], [0.1, 0.2, OUT3], [0.4, 0.1], [1, 0.1]])
	stagger.shift(B, UP, [[0, 0], [0.4, -0.2], [1, -0.18]])
	stagger.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	var roar := BossClip.new(&"roar")
	roar.turn(B, Z, [[0, 0], [0.36, 0.3, BACK], [0.85, 0.26], [1, 0]])
	roar.stretch(B, [[0, 0], [0.36, 0.12, BACK], [0.85, 0.1], [1, 0]])
	roar.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	var rise := BossClip.new(&"rise")
	rise.shift(B, UP, [[0, -0.5], [0.5, -0.4], [0.7, 0.1, OUT], [0.8, -0.02, OUT, S], [1, 0]])
	rise.stretch(B, [[0, -0.2], [0.5, -0.15], [0.7, 0.08, OUT], [1, 0]])
	var death := BossClip.new(&"death")
	death.shift(B, UP, [[0, 0], [0.15, 0.08], [0.55, -0.4, IN], [0.84, -0.45], [1, -3.0, IN]])
	death.turn(B, Z, [[0, 0], [0.55, -0.5, IN], [1, -0.55]])
	return [shielded, flinch, stagger, roar, rise, death]
