class_name TidecallerClips
extends RefCounted
## The Tidecaller's clips (the owner's hunched sea priest, skinned to a full skeleton: spine, both arms, the staff in
## its right hand with the bell and its clapper hanging from it, legs, the shell on its back, and chains for the
## sleeves and the robe). Model frame: +X the front, +Z its right (the staff), -Z its left (the reaching arm).
## Its file carries the animations of its stance, its walk and its moves, and the avatar plays them
## (TidecallerAvatar.OWNER_PLAYS): the clips of those names here hold only the parameters the avatar maps while an
## animation moves the bones: glow (the sea light at its mask) and tremble (the shake of a heavy strike).
## The other clips still move it from code, added on top of the stance or the walk the file plays: the shielded hunch
## under its swollen shell, a jolt, a dazed sway, a roar with the arm and the staff thrown wide, rising out of the
## water, and a collapse forward.

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
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
			BossClip.new(&"walk", true),
			_tide(),
			_pattern(),
			_wave(),
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


## Breathing under the shell (the file's "idle"): the light swells with the breath.
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.param(&"glow", [[0, 0], [0.5, 0.25], [1, 0]])
	return c


## The Pull (the file's "bell_raise": the staff up high and rung through the windup, planted on the strike and held
## through the tide): the light climbs with the ringing and blazes as the staff lands, which shakes it.
static func _tide() -> BossClip:
	var c := BossClip.new(&"tide")
	c.param(&"glow", [[0, 0], [0.42, 1.0], [0.5, 1.6, IN3], [0.62, 1.3], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.48, 0], [0.5, 0.7, LIN], [0.56, 0], [1, 0]])
	return c


## The Tide Rings (the file's "bell_toll"): the light flares on the toll.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.param(&"glow", [[0, 0], [0.42, 0.8], [0.5, 1.4, IN3], [0.62, 0.6], [1, 0]])
	return c


## The crossing wave (the file's "claw_sweep"): the light flares as the claws send it off.
static func _wave() -> BossClip:
	var c := BossClip.new(&"wave")
	c.param(&"glow", [[0, 0], [0.42, 0.5], [0.5, 1.0, IN3], [0.62, 0.4], [1, 0]])
	return c


## The Undertow (the file's "claw_drag"): the light flares as the claws drag back.
static func _marks() -> BossClip:
	var c := BossClip.new(&"marks")
	c.param(&"glow", [[0, 0], [0.42, 0.6], [0.5, 1.0, IN3], [0.62, 0.4], [1, 0]])
	return c


## The Shell Slam (the file's "shell_slam"): the floor shakes as its weight lands.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1.0, LIN], [0.6, 0], [1, 0]])
	return c


## The shielded hold (the Pull): hunched under its shell, the shell swollen and glowing.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(&"spine", Z, [[0, 0], [1, -0.1]])
	c.stretch(&"shell", [[0, 0], [1, 0.06]])
	c.param(&"glow", [[0, 0], [1, 0.8]])
	return c


## A hit jolts it back from the waist, the reaching arm flung down and the bell knocked swinging.
static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(&"spine", Z, [[0, 0], [0.15, 0.16, OUT3], [0.5, -0.04, IO, S], [1, 0]])
	c.turn(&"upper_arm_L", Z, [[0, 0], [0.15, -0.3, OUT3], [1, 0]])
	c.turn(&"bell", X, [[0, 0], [0.15, 0.4, OUT3], [0.5, -0.2, IO, S], [1, 0]])
	return c


## Dazed: it sags forward from the waist, the staff slack in its hand and the arm hanging (the avatar dips the
## whole figure for the kneel).
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.turn(&"spine", Z, [[0, 0], [0.2, -0.25, OUT3], [1, -0.2]])
	c.turn(&"staff", Z, [[0, 0], [0.2, 0.4, OUT3], [1, 0.3]])
	c.turn(&"upper_arm_L", Z, [[0, 0], [0.2, -0.4, OUT3], [1, -0.35]])
	c.param(&"daze", [[0, 0], [0.2, 1], [1, 1]])
	c.param(&"glow", [[0, 0], [0.2, -0.6], [1, -0.6]])
	return c


## The phase gate's roar: it rears back, the reaching arm and the staff arm thrown wide, the shell blazing.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.turn(&"spine", Z, [[0, 0], [0.3, 0.3, BACK], [0.8, 0.25], [1, 0]])
	c.turn(&"upper_arm_L", X, [[0, 0], [0.3, 0.9, BACK], [0.8, 0.8], [1, 0]])
	c.turn(&"upper_arm_R", X, [[0, 0], [0.3, -0.4, BACK], [0.8, -0.35], [1, 0]])
	c.stretch(&"shell", [[0, 0], [0.3, 0.12], [0.8, 0.1], [1, 0]])
	c.param(&"glow", [[0, 0], [0.3, 1.8], [0.8, 1.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.3, 0.8], [0.8, 0.8], [1, 0]])
	return c


## Rising out of the water: from sunk and hunched to upright, the shell last.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.shift(B, UP, [[0, -1.6], [0.55, -0.2, OUT3], [0.8, 0.05, OUT, S], [1, 0]])
	c.turn(&"spine", Z, [[0, -0.4], [0.6, -0.1], [1, 0]])
	c.stretch(&"shell", [[0, -0.2], [0.7, 0.08, BACK], [1, 0]])
	return c


## The collapse: the whole figure tips forward and sinks as it folds at the waist, the staff arm falling away and
## the reaching arm dropping.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.turn(B, Z, [[0, 0], [0.3, 0.06], [0.8, -0.3, IN3], [1, -0.35]])
	c.turn(&"spine", Z, [[0, 0], [0.3, 0.06], [0.8, -0.4, IN3], [1, -0.4]])
	c.shift(B, UP, [[0, 0], [0.3, 0.05], [0.85, -0.7, IN3], [1, -0.9]])
	c.turn(&"upper_arm_R", X, [[0, 0], [0.4, -0.2], [0.9, -0.9, IN3], [1, -1.0]])
	c.turn(&"upper_arm_L", Z, [[0, 0], [0.4, 0.3], [1, -0.6]])
	c.param(&"glow", [[0, 0], [0.3, 1.0], [1, -1.0]])
	return c
