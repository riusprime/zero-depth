class_name WarlordClips
extends RefCounted
## v0.8.0 BA: the Warlord's clips (the owner's rigged knight, 41 Tripo joints posed through BonePoser in the model
## frame). A drilled soldier, so its moves are sharp and committed: a guarded breath with the tower shield carried
## across its front, a marching walk, the spear raised and thrust forward to loose each wave of the Javelin Fan (and
## for the Shield Wall, braced behind its shield on bent knees: the shielded hold), the shield drawn back and rammed
## forward with a step for the bash, the spear hoisted overhead and driven into the floor on one knee for the Spear
## Lines, the spear couched low for the lunge and thrust at full stretch, the spear drawn back over its shoulder and
## hurled for the Javelin Rain; a flinch, a reel, a roar with spear and shield raised high, rising from one knee,
## and a fall onto its back. The shield's lift while the weak point is open stays a procedural layer
## (WarlordAvatar._pose_rig). The carry pose of the shield arm is in both idle and walk, so it is always there.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
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
			_pattern(),
			_sweep(),
			_flood(),
			_charge(),
			_barrage(),
			_recall(),  # v0.8.0 BS1 (S2)
			_shielded(),
			_flinch(),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


## The shield carried turned across its front (in idle and walk alike).
static func _carry(c: BossClip) -> void:
	c.turn(&"L_Upperarm", Y, [[0, -0.9], [1, -0.9]])
	c.turn(&"L_Upperarm", X, [[0, -0.2], [1, -0.2]])
	c.turn(&"L_Upperarm", Z, [[0, 0.3], [1, 0.3]])
	c.turn(&"L_Forearm", Z, [[0, 0.55], [1, 0.55]])
	c.turn(&"R_Forearm", Z, [[0, 0.1], [1, 0.1]])


static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	_carry(c)
	c.turn(&"Spine01", Z, [[0, 0], [0.5, 0.03], [1, 0]])
	c.turn(&"Spine02", Z, [[0, 0], [0.5, 0.02], [1, 0]])
	c.turn(&"Head", Z, [[0, 0.01], [0.5, -0.03], [1, 0.01]])
	c.shift(&"L_Clavicle", UP, [[0, 0], [0.5, 0.012], [1, 0]])
	c.shift(&"R_Clavicle", UP, [[0, 0], [0.5, 0.012], [1, 0]])
	c.turn(&"Hip", X, [[0, 0.025], [0.5, -0.025], [1, 0.025]])
	c.turn(&"R_Upperarm", Z, [[0, 0.02], [0.5, 0.06], [1, 0.02]])
	c.turn(&"Head", Y, [[0, 0.06], [0.3, 0.06], [0.4, -0.08], [0.8, -0.08], [0.9, 0.06], [1, 0.06]])
	return c


## The march: thighs swing, the knee folds on the leg coming through, the feet stay flat, the hips roll and the
## spear arm counter-swings; the body dips on each plant.
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	_carry(c)
	var thigh := [[0, 0], [0.25, 0.45, OUT], [0.5, 0, IN], [0.75, -0.45, OUT], [1, 0, IN]]
	c.turn(&"R_Thigh", Z, thigh)
	c.turn(&"L_Thigh", Z, BossClip.negated(thigh))
	c.turn(&"R_Calf", Z, [[0, -0.75], [0.25, -0.1], [0.5, 0], [0.75, 0], [0.9, -0.5], [1, -0.75]])
	c.turn(&"L_Calf", Z, [[0, 0], [0.25, 0], [0.4, -0.5], [0.5, -0.75], [0.75, -0.1], [1, 0]])
	c.turn(&"R_Foot", Z, [[0, 0.5], [0.25, -0.3], [0.5, 0], [0.75, 0.35], [1, 0.5]])
	c.turn(&"L_Foot", Z, [[0, 0], [0.25, 0.35], [0.5, 0.5], [0.75, -0.3], [1, 0]])
	c.turn(&"Hip", X, [[0, 0], [0.25, 0.06], [0.5, 0], [0.75, -0.06], [1, 0]])
	c.turn(&"Spine01", Y, [[0, 0], [0.25, -0.07], [0.5, 0], [0.75, 0.07], [1, 0]])
	c.turn(&"Spine01", Z, [[0, -0.05], [1, -0.05]])
	c.turn(&"R_Upperarm", Z, BossClip.negated(BossClip.scaled(thigh, 0.7)))
	c.shift(
		B, UP, [[0, 0.03], [0.25, -0.03, IN], [0.5, 0.03, OUT], [0.75, -0.03, IN], [1, 0.03, OUT]]
	)
	return c


## The Javelin Fan: it lifts the spear high and back, leaning into it, then thrusts it forward to point the volley;
## each wave of the fan jabs it again.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	var jab := [[0, 0], [0.42, 2.6], [0.47, 2.75, OUT], [0.5, 1.45, IN3]]
	for k in 3:
		var t0 := 0.525 + 0.03 * k
		jab.append([t0, 1.7, OUT])
		jab.append([t0 + 0.015, 1.4, IN3])
	jab.append_array([[0.62, 1.45], [0.82, 0.7], [1, 0]])
	c.turn(&"R_Upperarm", Z, jab)
	c.turn(&"R_Upperarm", X, [[0, 0], [0.42, -0.2], [0.5, 0.05, IN3], [0.62, 0.05], [1, 0]])
	c.turn(&"R_Forearm", Z, [[0, 0], [0.42, 0.7], [0.5, 0.15, IN3], [0.62, 0.15], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.42, 0.9], [0.5, -1.55, IN3], [0.62, -1.5], [1, 0]])
	c.turn(&"Spine01", Z, [[0, 0], [0.42, 0.14], [0.5, -0.18, IN3], [0.62, -0.15], [1, 0]])
	c.turn(&"Spine01", Y, [[0, 0], [0.42, -0.3], [0.5, 0.2, IN3], [0.62, 0.15], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.42, -0.08], [0.5, 0.14, IN3], [0.62, 0.12], [1, 0]])
	c.turn(&"R_Thigh", Z, [[0, 0], [0.42, -0.2], [0.5, 0.3, IN3], [0.62, 0.3], [1, 0]])
	c.turn(&"R_Calf", Z, [[0, 0], [0.5, -0.35, IN3], [0.62, -0.35], [1, 0]])
	return c


## The shield bash: it draws the shield back and twists away, then rams it forward with a step, overshooting.
static func _sweep() -> BossClip:
	var c := BossClip.new(&"sweep")
	c.turn(
		&"L_Upperarm",
		Z,
		[
			[0, 0],
			[0.42, -0.7],
			[0.47, -0.75, OUT],
			[0.5, 0.85, IN3],
			[0.535, 1.0, OUT3, S],
			[0.62, 0.85],
			[1, 0]
		]
	)
	c.turn(&"L_Upperarm", Y, [[0, 0], [0.42, 0.45], [0.5, -0.3, IN3], [0.62, -0.3], [1, 0]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.42, 0.1], [0.5, -0.15, IN3], [0.62, -0.15], [1, 0]])
	c.turn(&"L_Forearm", Z, [[0, 0], [0.42, -0.2], [0.5, -0.35, IN3], [0.62, -0.35], [1, 0]])
	c.turn(
		&"Spine01",
		Y,
		[
			[0, 0],
			[0.42, 0.4],
			[0.47, 0.45, OUT],
			[0.5, -0.4, IN3],
			[0.535, -0.48, OUT3, S],
			[0.62, -0.4],
			[1, 0]
		]
	)
	c.turn(&"Spine01", Z, [[0, 0], [0.42, 0.06], [0.5, -0.16, IN3], [0.62, -0.14], [1, 0]])
	c.shift(
		B,
		FWD,
		[
			[0, 0],
			[0.42, -0.14],
			[0.5, 0.32, IN3],
			[0.535, 0.38, OUT3, S],
			[0.62, 0.32],
			[0.85, 0.1],
			[1, 0]
		]
	)
	c.shift(B, UP, [[0, 0], [0.42, -0.08], [0.5, -0.04, IN3], [1, 0]])
	c.turn(&"L_Thigh", Z, [[0, 0], [0.42, -0.15], [0.5, 0.45, IN3], [0.62, 0.45], [1, 0]])
	c.turn(&"L_Calf", Z, [[0, 0], [0.5, -0.4, IN3], [0.62, -0.4], [1, 0]])
	c.turn(&"R_Thigh", Z, [[0, 0], [0.42, 0.1], [0.5, -0.3, IN3], [0.62, -0.3], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.6, LIN], [0.56, 0], [1, 0]])
	return c


## The Spear Lines: it hoists the spear overhead, rising onto its toes, then drives it point first into the floor on
## one knee and holds it there while the lines run.
static func _flood() -> BossClip:
	var c := BossClip.new(&"flood")
	c.turn(
		&"R_Upperarm",
		Z,
		[
			[0, 0],
			[0.12, -0.2, OUT],
			[0.38, 2.5],
			[0.47, 2.65, OUT],
			[0.5, 0.9, IN3],
			[0.62, 0.9],
			[0.85, 0.5],
			[1, 0]
		]
	)
	c.turn(&"R_Upperarm", X, [[0, 0], [0.38, -0.15], [0.5, -0.1, IN3], [0.62, -0.1], [1, 0]])
	c.turn(&"R_Forearm", Z, [[0, 0], [0.38, 0.2], [0.5, 0.3, IN3], [0.62, 0.3], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.38, 1.0], [0.5, 2.45, IN3], [0.62, 2.45], [0.85, 1.0], [1, 0]])
	c.turn(
		&"Spine01",
		Z,
		[[0, 0], [0.38, 0.1], [0.5, -0.3, IN3], [0.535, -0.36, OUT3, S], [0.62, -0.3], [1, 0]]
	)
	c.turn(&"Head", Z, [[0, 0], [0.38, -0.12], [0.5, -0.15, IN3], [0.62, -0.15], [1, 0]])
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.12, -0.05],
			[0.38, 0.08],
			[0.5, -0.32, IN3],
			[0.535, -0.36, OUT3, S],
			[0.62, -0.32],
			[0.85, -0.1],
			[1, 0]
		]
	)
	c.turn(&"R_Thigh", Z, [[0, 0], [0.5, 0.75, IN3], [0.62, 0.75], [1, 0]])
	c.turn(&"R_Calf", Z, [[0, 0], [0.5, -1.2, IN3], [0.62, -1.2], [1, 0]])
	c.turn(&"R_Foot", Z, [[0, 0], [0.5, 0.45, IN3], [0.62, 0.45], [1, 0]])
	c.turn(&"L_Thigh", Z, [[0, 0], [0.5, -0.35, IN3], [0.62, -0.35], [1, 0]])
	c.turn(&"L_Calf", Z, [[0, 0], [0.5, -0.9, IN3], [0.62, -0.9], [1, 0]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.38, 0.3], [0.5, 0.75, IN3], [0.62, 0.75], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.58, 0], [1, 0]])
	return c


## The lunge: it couches the spear low at its hip and sinks back onto the rear leg, then thrusts at full stretch
## through the dash and holds it there.
static func _charge() -> BossClip:
	var c := BossClip.new(&"charge")
	c.turn(
		&"R_Upperarm",
		Z,
		[[0, 0], [0.38, -0.35], [0.47, -0.42, OUT], [0.5, 0.75, IN3], [0.62, 0.75], [1, 0]]
	)
	c.turn(&"R_Upperarm", X, [[0, 0], [0.38, 0.1], [0.62, 0], [1, 0]])
	c.turn(&"R_Forearm", Z, [[0, 0], [0.38, 1.25], [0.5, 0.35, IN3], [0.62, 0.35], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.38, -2.45], [0.5, -2.65, IN3], [0.62, -2.65], [1, 0]])
	c.turn(&"Spine01", Z, [[0, 0], [0.38, -0.34], [0.5, -0.42, IN3], [0.62, -0.42], [1, 0]])
	c.turn(&"Head", Z, [[0, 0], [0.38, 0.2], [0.62, 0.22], [1, 0]])
	c.turn(&"L_Thigh", Z, [[0, 0], [0.38, 0.55], [0.5, 0.75, IN3], [0.62, 0.75], [1, 0]])
	c.turn(&"L_Calf", Z, [[0, 0], [0.38, -0.6], [0.5, -0.3, IN3], [0.62, -0.3], [1, 0]])
	c.turn(&"R_Thigh", Z, [[0, 0], [0.38, -0.4], [0.5, -0.6, IN3], [0.62, -0.6], [1, 0]])
	c.turn(&"R_Foot", Z, [[0, 0], [0.38, 0.3], [0.62, 0.4], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.38, -0.12], [0.5, 0.42, IN3], [0.62, 0.42], [0.85, 0.15], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.38, -0.16], [0.5, -0.12], [0.62, -0.12], [1, 0]])
	c.stretch(B, [[0, 0], [0.38, -0.05], [0.5, 0.06, IN3], [0.56, 0], [1, 0]])
	return c


## The Javelin Rain: it draws the spear back over its shoulder, leaning and twisting away, and hurls it with a whip
## of the whole body, the arm following through low.
static func _barrage() -> BossClip:
	var c := BossClip.new(&"barrage")
	c.turn(
		&"R_Upperarm",
		Z,
		[
			[0, 0],
			[0.4, 2.9],
			[0.47, 3.0, OUT],
			[0.5, 1.35, IN3],
			[0.54, 0.6, OUT3, S],
			[0.62, 1.0],
			[1, 0]
		]
	)
	c.turn(&"R_Upperarm", X, [[0, 0], [0.4, -0.2], [0.5, 0, IN3], [1, 0]])
	c.turn(&"R_Forearm", Z, [[0, 0], [0.4, 0.9], [0.5, 0.15, IN3], [0.62, 0.2], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.4, 0.9], [0.5, -2.8, IN3], [0.62, -2.4], [1, 0]])
	c.turn(
		&"Spine01",
		Y,
		[
			[0, 0],
			[0.4, -0.45],
			[0.47, -0.5, OUT],
			[0.5, 0.35, IN3],
			[0.54, 0.45, OUT3, S],
			[0.62, 0.3],
			[1, 0]
		]
	)
	c.turn(&"Spine01", Z, [[0, 0], [0.4, 0.2], [0.5, -0.24, IN3], [0.62, -0.2], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.4, -0.12], [0.5, 0.16, IN3], [0.62, 0.12], [1, 0]])
	c.turn(&"L_Thigh", Z, [[0, 0], [0.4, 0.35], [0.5, 0.4], [0.62, 0.35], [1, 0]])
	c.turn(&"R_Thigh", Z, [[0, 0], [0.4, -0.3], [0.5, -0.2], [1, 0]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.4, 0.45], [0.5, 0.2, IN3], [1, 0]])
	return c


## v0.8.0 BS1 (owner O5, S2): the recall, timed 0..1 from its first javelin sticking to their flight back
## (BossAvatar._recall): planted on braced legs behind its shield, it reaches its empty spear hand out toward the
## javelins in the floor, straining harder (the tremble) as the recall nears, then yanks the arm back to its chest
## with a twist of the whole body on the tick they fly (1.0), and holds the pull while they come home.
static func _recall() -> BossClip:
	var c := BossClip.new(&"recall")
	c.turn(
		&"R_Upperarm",
		Z,
		[[0, 0.9], [0.15, 1.5, OUT], [0.82, 1.6], [0.92, 1.8, OUT], [0.97, -0.35, IN3], [1, -0.25]]
	)
	c.turn(&"R_Upperarm", X, [[0, -0.1], [0.82, -0.15], [0.97, 0.25, IN3], [1, 0.2]])
	c.turn(&"R_Forearm", Z, [[0, 0.1], [0.82, 0.12], [0.97, 1.25, IN3], [1, 1.15]])
	c.turn(&"R_Hand", Z, [[0, -1.0], [0.15, -1.3, OUT], [0.92, -1.4], [0.97, 0.5, IN3], [1, 0.4]])
	c.turn(&"Spine01", Y, [[0, 0.05], [0.82, 0.14], [0.97, -0.4, IN3], [1, -0.32]])
	c.turn(&"Spine01", Z, [[0, -0.06], [0.82, -0.14], [0.97, 0.2, IN3], [1, 0.16]])
	c.shift(B, FWD, [[0, 0], [0.82, 0.05], [0.97, -0.14, IN3], [1, -0.1]])
	c.shift(B, UP, [[0, -0.04], [0.82, -0.07], [0.97, -0.02], [1, -0.03]])
	c.turn(&"L_Thigh", Z, [[0, 0.3], [1, 0.3]])
	c.turn(&"L_Calf", Z, [[0, -0.35], [1, -0.35]])
	c.turn(&"R_Thigh", Z, [[0, -0.22], [0.97, -0.3], [1, -0.28]])
	c.turn(&"L_Upperarm", Z, [[0, 0.25], [1, 0.25]])  # the shield kept up in front
	c.param(&"tremble", [[0, 0], [0.55, 0], [0.9, 0.55, LIN], [0.93, 0], [1, 0]])
	return c


## The shielded hold (the Shield Wall): braced low on bent knees behind the shield held up in front.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"L_Upperarm", Z, [[0, 0], [0.7, 0.62, BACK], [1, 0.55]])
	c.turn(&"L_Forearm", Z, [[0, 0], [0.7, 0.5, BACK], [1, 0.45]])
	c.turn(&"Spine01", Z, [[0, 0], [0.7, -0.22, BACK], [1, -0.18]])
	for side in ["L_", "R_"]:
		c.turn(StringName(side + "Thigh"), Z, [[0, 0], [0.7, 0.4, BACK], [1, 0.35]])
		c.turn(StringName(side + "Calf"), Z, [[0, 0], [0.7, -0.68, BACK], [1, -0.6]])
		c.turn(StringName(side + "Foot"), Z, [[0, 0], [0.7, 0.28], [1, 0.25]])
	c.shift(B, UP, [[0, 0], [0.7, -0.12, BACK], [1, -0.1]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"Spine01", Z, [[0, 0], [0.15, 0.24, OUT3], [0.5, -0.05, IO, S], [1, 0]])
	c.turn(&"Head", Z, [[0, 0], [0.15, 0.28, OUT3], [0.5, -0.06, IO, S], [1, 0]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.15, 0.16, OUT3], [1, 0]])
	c.turn(&"R_Upperarm", X, [[0, 0], [0.15, -0.16, OUT3], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.1, OUT3], [1, 0]])
	return c


## Staggered: it reels back, then slumps forward on bent knees, both arms low, wobbling.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"Spine01", Z, [[0, 0], [0.1, 0.3, OUT3], [0.4, -0.3], [1, -0.32]])
	c.turn(&"Head", Z, [[0, 0], [0.1, 0.25, OUT3], [0.4, -0.28], [1, -0.3]])
	for side in ["L_", "R_"]:
		c.turn(StringName(side + "Thigh"), Z, [[0, 0], [0.4, 0.28], [1, 0.25]])
		c.turn(StringName(side + "Calf"), Z, [[0, 0], [0.4, -0.5], [1, -0.45]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.1, 0.5, OUT3], [0.4, 0.25], [1, 0.25]])
	c.turn(&"R_Upperarm", X, [[0, 0], [0.1, -0.5, OUT3], [0.4, -0.2], [1, -0.2]])
	c.turn(&"L_Upperarm", Y, [[0, 0], [0.4, 0.6], [1, 0.6]])
	c.shift(B, FWD, [[0, 0], [0.1, -0.22, OUT3], [0.4, -0.08], [1, -0.08]])
	c.shift(B, UP, [[0, 0], [0.4, -0.14], [1, -0.14]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The phase gate's roar: spear raised high and shield thrown out wide, chest out, head back.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"R_Upperarm", Z, [[0, 0], [0.22, 0.4], [0.36, 2.85, BACK], [0.85, 2.75], [1, 0]])
	c.turn(&"R_Upperarm", X, [[0, 0], [0.36, -0.45], [0.85, -0.4], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.36, 0.6], [0.85, 0.6], [1, 0]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.36, 1.25, BACK], [0.85, 1.15], [1, 0]])
	c.turn(&"L_Upperarm", Y, [[0, 0], [0.36, 0.8], [0.85, 0.8], [1, 0]])
	c.turn(&"Spine01", Z, [[0, 0], [0.22, -0.18], [0.36, 0.28, BACK], [0.85, 0.24], [1, 0]])
	c.turn(&"Head", Z, [[0, 0], [0.22, -0.2], [0.36, 0.35, BACK], [0.85, 0.3], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.22, -0.12], [0.36, 0.04], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 0.8, LIN], [0.8, 0.6], [0.9, 0], [1, 0]])
	return c


## The rise-in: it comes up on one knee, head bowed, stands as the bar fills, and slams its spear's butt down.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.turn(&"R_Thigh", Z, [[0, 0.8], [0.5, 0.0], [1, 0]])
	c.turn(&"R_Calf", Z, [[0, -1.5], [0.5, 0.0], [1, 0]])
	c.turn(&"L_Thigh", Z, [[0, -0.2], [0.5, 0.0], [1, 0]])
	c.turn(&"L_Calf", Z, [[0, -1.2], [0.5, 0.0], [1, 0]])
	c.turn(&"Spine01", Z, [[0, -0.35], [0.5, 0.05], [0.64, -0.12, IN3], [1, 0]])
	c.turn(&"Head", Z, [[0, -0.35], [0.5, 0.1], [1, 0]])
	c.shift(B, UP, [[0, -0.45], [0.5, 0.0], [0.64, -0.08, IN3], [0.74, 0.02, OUT, S], [1, 0]])
	c.turn(&"R_Upperarm", Z, [[0, 0], [0.5, 1.2], [0.64, 0.55, IN3], [1, 0]])
	c.turn(&"R_Hand", Z, [[0, 0], [0.5, 1.6], [0.64, 2.2, IN3], [0.85, 1.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 0.6, LIN], [0.72, 0], [1, 0]])
	return c


## Its death: the knees buckle, the arms fall open and it topples onto its back, bounces, then sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	for side in ["L_", "R_"]:
		c.turn(StringName(side + "Thigh"), Z, [[0, 0], [0.35, 0.7], [0.85, 0.3], [1, 0.3]])
		c.turn(StringName(side + "Calf"), Z, [[0, 0], [0.35, -1.1], [0.85, -0.5], [1, -0.5]])
	c.turn(&"L_Upperarm", X, [[0, 0], [0.2, 0.1], [0.85, 0.9], [1, 0.9]])
	c.turn(&"R_Upperarm", X, [[0, 0], [0.2, -0.1], [0.85, -0.9], [1, -0.9]])
	c.turn(&"Head", Z, [[0, 0], [0.2, -0.2], [0.85, 0.4], [1, 0.4]])
	c.turn(
		B,
		Z,
		[[0, 0], [0.2, -0.08], [0.78, 1.45, IN], [0.84, 1.36, OUT, S], [0.88, 1.45], [1, 1.45]]
	)
	c.shift(B, FWD, [[0, 0], [0.2, 0.05], [0.85, -0.5], [1, -0.5]])
	c.shift(B, UP, [[0, 0], [0.35, -0.25], [0.85, 0.15], [0.9, 0.15], [1, -0.75, IN]])
	c.param(&"tremble", [[0, 0], [0.76, 0], [0.78, 0.8, LIN], [0.88, 0], [1, 0]])
	return c
