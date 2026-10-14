class_name NemesisClips
extends RefCounted
## v0.8.0 FB3 (owner Q4: code clips first, the owner's animated model replaces them by name; FINAL_BOSS.md F6): the
## Nemesis's placeholder clips, in the hero's motion vocabulary (run, dash, slash, shoot, hit, death), on its whole body
## (the owner's model is one mesh, BossClip.BODY) plus named parameters NemesisAvatar reads for its weapon (a dark copy
## of the run's Blade or Gun in its hand) and its cast:
## - idle: light on its feet, a fighter's sway; walk: the hero's run, leaning in, quick steps;
## Each attack clip is named by its move (BossAnimator.MOVE_CLIPS: the data's `move` plays the clip of that name):
## - `mimic_combo`, the slash: the hero's swing: a coil back, the cut across ("swing" -1 → 1, the blade sweeping), the
##   follow-through; a combo's later swings cycle it once per swing (BossAvatar.clip_time);
## - `mimic_shots`, the shot: the hero's aim and shot: arm raised ("aim" 1), a kick on each volley ("recoil");
## - `card_cast`, the cast: a card raised overhead ("sigil" glowing up through the windup), thrown down on the strike;
## - dash: the hero's dash: a low lean forward, stretched, the cloak trailing (NemesisAvatar plays it while the sim says
##   it dashes);
## - shielded, flinch (the hit), stagger, roar, rise (from the Prism's shards), death.
## Presentation only.

const UP := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
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
## The clips the library holds (tests check each is there).
const NAMES: Array[StringName] = [
	&"idle",
	&"walk",
	&"mimic_combo",
	&"mimic_shots",
	&"card_cast",
	&"dash",
	&"shielded",
	&"flinch",
	&"stagger",
	&"roar",
	&"rise",
	&"death",
]

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		var idle := BossClip.new(&"idle", true)
		idle.turn(B, Z, [[0, 0.05], [0.5, -0.03, IO], [1, 0.05, IO]])
		idle.shift(B, UP, [[0, 0], [0.25, 0.04, IO], [0.5, 0, IO], [0.75, 0.04, IO], [1, 0, IO]])
		idle.param(&"swing", [[0, -0.2], [0.5, -0.15], [1, -0.2]])
		var walk := BossClip.new(&"walk", true)
		walk.shift(B, UP, [[0, 0], [0.25, 0.08, OUT], [0.5, 0, IN], [0.75, 0.08, OUT], [1, 0, IN]])
		walk.turn(B, Z, [[0, -0.22], [1, -0.22]])
		walk.turn(B, UP, [[0, 0.08], [0.5, -0.08, IO], [1, 0.08, IO]])
		walk.param(&"swing", [[0, -0.4], [1, -0.4]])
		_lib[&"mimic_combo"] = _slash()
		_lib[&"mimic_shots"] = _shoot()
		_lib[&"card_cast"] = _cast()
		_lib[&"dash"] = _dash()
		for c: BossClip in [idle, walk] + _reactions():
			_lib[c.name] = c
	return _lib


static func _slash() -> BossClip:
	var c := BossClip.new(&"mimic_combo")  # the slash
	c.turn(B, UP, [[0, 0], [0.42, 0.75, BACK], [0.5, -0.85, IN3], [0.62, -0.7, OUT, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.42, -0.12], [0.5, 0.35, IN3], [0.62, 0.3], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.1], [0.5, -0.2, IN3], [0.62, -0.15], [1, 0]])
	c.param(&"swing", [[0, 0], [0.42, -1.0, BACK], [0.5, 1.0, IN3], [0.62, 0.9], [1, 0]])
	return c


static func _shoot() -> BossClip:
	var c := BossClip.new(&"mimic_shots")  # the shot
	c.turn(B, Z, [[0, 0], [0.42, -0.08, IO], [0.5, 0.12, OUT3], [0.58, -0.04, OUT, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.5, -0.12, OUT3], [0.62, 0.0, IO], [1, 0]])
	c.param(&"aim", [[0, 0], [0.3, 1.0, OUT], [0.62, 1.0], [1, 0, IO]])
	c.param(&"recoil", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.58, 0.0, OUT], [1, 0]])
	return c


static func _cast() -> BossClip:
	var c := BossClip.new(&"card_cast")  # the cast
	c.shift(B, UP, [[0, 0], [0.42, 0.22, BACK], [0.5, -0.05, IN3], [0.62, 0.0], [1, 0]])
	c.stretch(B, [[0, 0], [0.42, 0.12, BACK], [0.5, -0.1, IN3], [0.62, 0.0, OUT, S], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.18], [0.5, -0.25, IN3], [0.62, -0.1], [1, 0]])
	c.param(&"sigil", [[0, 0], [0.42, 1.0, IN], [0.5, 1.0], [0.62, 0.0, OUT], [1, 0]])
	return c


static func _dash() -> BossClip:
	var c := BossClip.new(&"dash")
	c.turn(B, Z, [[0, 0], [0.15, -0.55, OUT3], [0.8, -0.5], [1, 0, IO]])
	c.shift(B, UP, [[0, 0], [0.15, -0.15, OUT3], [0.8, -0.12], [1, 0, IO]])
	c.stretch(B, [[0, 0], [0.15, -0.12, OUT3], [0.8, -0.1], [1, 0, IO]])
	c.param(&"trail", [[0, 0], [0.1, 1.0, OUT], [0.8, 1.0], [1, 0]])
	return c


## The shared reactions: shielded, flinch (the hit), stagger, roar, rise, death.
static func _reactions() -> Array[BossClip]:
	var shielded := BossClip.new(&"shielded")
	shielded.stretch(B, [[0, 0], [0.7, -0.08, BACK], [1, -0.06]])
	var flinch := BossClip.new(&"flinch")
	flinch.turn(B, Z, [[0, 0], [0.15, 0.18, OUT3], [0.5, -0.03, IO, S], [1, 0]])
	flinch.shift(B, FWD, [[0, 0], [0.15, -0.16, OUT3], [1, 0]])
	var stagger := BossClip.new(&"stagger")
	stagger.turn(B, Z, [[0, 0], [0.1, 0.25, OUT3], [0.4, 0.12], [1, 0.12]])
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
