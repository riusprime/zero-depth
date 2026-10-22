class_name HiveLensClips
extends RefCounted
## v0.8.0 BA: the Hive Lens's clips (the owner's rigged floating eye, 23 Tripo joints posed through BonePoser; its
## BODY turns about its sphere's centre, HiveLensAvatar). Parameters the avatar maps: tail_curl, tail_splay and
## tail_sweep (its three cable tails curled up under it, flung out, streamed back; on top of their own lagging sway),
## spin (how fast the crown turns). A hovering eye, so it moves in swells and lurches rather than steps: a bob and a
## slow roll when idle, a forward lean when moving, a pull back and a swell then a snap forward pulsing with each
## wave for its patterns (the Prism Spiral closes it: the shielded hold), the eye narrowing and a recoil for the
## Focus Beam, a contraction and a burst for the Lens Flare, rising high and diving with its tails streaming for the
## dive, a shudder as it splits; a jolt, a sagging stagger, a roar with its crown thrown open, opening as it rises,
## and a fall to the ground rolling onto its side.

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
const SPINE := &"tripo__Spine_1"
const CROWN_BASE := &"tripo__Spine_2"
const CROWN := &"tripo__Head_0"
const SHELL_TOP := &"bone_21"
const PODS := &"bone_22"

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		for c: BossClip in [
			_idle(),
			_walk(),
			_pattern(),
			_lanes(),
			_slam_ring(),
			_leap(),
			_deploy(),
			_gaze(),  # v0.8.0 BS2 (S4)
			_shielded(),
			_flinch(),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


## The hover: a bob, and a slow roll and pitch that reduced motion leaves out (SETTLE keys).
static func _idle() -> BossClip:
	var c := BossClip.new(&"idle", true)
	c.shift(B, UP, [[0, -0.08], [0.5, 0.08], [1, -0.08]])
	c.turn(B, X, [[0, 0], [0.25, 0.08, IO, S], [0.75, -0.08, IO, S], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.4, 0.04, IO, S], [0.9, -0.03, IO, S], [1, 0]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.5, 0.06], [1, 0]])
	c.stretch(SPINE, [[0, 0], [0.5, 0.02], [1, 0]])
	return c


## Moving: it leans into its motion and bobs quicker (the tails trail on their own).
static func _walk() -> BossClip:
	var c := BossClip.new(&"walk", true)
	c.turn(B, Z, [[0, -0.14], [1, -0.14]])
	c.shift(B, UP, [[0, -0.06], [0.25, 0.06], [0.5, -0.06], [0.75, 0.06], [1, -0.06]])
	c.turn(B, X, [[0, 0.04], [0.5, -0.04], [1, 0.04]])
	c.param(&"tail_sweep", [[0, 0.3], [1, 0.3]])
	return c


## Its patterns (the Petal Bloom, the Glare Ring; the Prism Spiral adds the shielded hold): it pulls back and
## swells, eye up, crown spinning up, then snaps forward on the strike and pulses with each wave.
static func _pattern() -> BossClip:
	var c := BossClip.new(&"pattern")
	c.shift(
		B,
		FWD,
		[
			[0, 0],
			[0.42, -0.3],
			[0.47, -0.34, OUT],
			[0.5, 0.18, IN3],
			[0.53, 0.1],
			[0.62, 0.05],
			[1, 0]
		]
	)
	c.turn(B, Z, [[0, 0], [0.42, 0.3], [0.5, -0.18, IN3], [0.53, -0.08], [0.62, -0.05], [1, 0]])
	var swell := [[0, 0], [0.42, 0.14, BACK], [0.47, 0.16], [0.5, -0.08, IN3]]
	for k in 4:
		var t0 := 0.52 + 0.025 * k
		swell.append([t0, 0.1, OUT])
		swell.append([t0 + 0.012, -0.04, IN3])
	swell.append_array([[0.62, 0.0], [1, 0]])
	c.stretch(SPINE, swell)
	c.turn(CROWN_BASE, Z, [[0, 0], [0.42, 0.4], [0.5, 0.15, IN3], [0.62, 0.2], [1, 0]])
	c.stretch(PODS, [[0, 0], [0.42, 0.12], [0.5, 0.2, IN3], [0.62, 0.15], [1, 0]])
	c.param(&"spin", [[0, 0], [0.42, 2.5], [0.5, 4.5], [0.62, 4.0], [0.85, 0.5], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.42, 0.3], [0.5, 0.9, IN3], [0.62, 0.6], [1, 0]])
	return c


## The Focus Beam: the eye narrows and it draws back, trembling as it charges, then the beam kicks it back.
static func _lanes() -> BossClip:
	var c := BossClip.new(&"lanes")
	c.turn(CROWN_BASE, Z, [[0, 0], [0.4, -0.5], [0.5, -0.2, IN3], [0.62, -0.25], [1, 0]])
	c.stretch(SPINE, [[0, 0], [0.4, -0.08], [0.5, 0.1, IN3], [0.62, 0.04], [1, 0]])
	c.stretch(PODS, [[0, 0], [0.4, -0.1], [0.62, -0.05], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.4, -0.18], [0.48, -0.2], [0.5, -0.45, IN3], [0.62, -0.35], [1, 0]])
	c.turn(
		B, Z, [[0, 0], [0.4, -0.08], [0.5, 0.28, IN3], [0.54, 0.34, OUT3, S], [0.62, 0.22], [1, 0]]
	)
	c.param(&"tail_curl", [[0, 0], [0.4, 0.5], [0.5, 0.0, IN3], [1, 0]])
	c.param(&"tail_sweep", [[0, 0], [0.49, 0], [0.5, -0.6, IN3], [0.62, -0.3], [1, 0]])
	c.param(
		&"tremble", [[0, 0], [0.25, 0], [0.48, 0.7], [0.5, 1, LIN], [0.62, 0.4], [0.7, 0], [1, 0]]
	)
	return c


## The Lens Flare: it contracts, tails curled tight and pods in, then bursts open, crown thrown back and tails flung
## wide.
static func _slam_ring() -> BossClip:
	var c := BossClip.new(&"slam_ring")
	c.stretch(
		SPINE,
		[
			[0, 0],
			[0.42, -0.14],
			[0.47, -0.16, OUT],
			[0.5, 0.26, IN3],
			[0.54, 0.32, OUT3, S],
			[0.62, 0.2],
			[1, 0]
		]
	)
	c.stretch(PODS, [[0, 0], [0.42, -0.15], [0.5, 0.3, IN3], [0.62, 0.22], [1, 0]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.42, -0.4], [0.5, 0.65, IN3], [0.62, 0.5], [1, 0]])
	c.param(&"tail_curl", [[0, 0], [0.42, 1.0], [0.5, 0.0, IN3], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.49, 0], [0.5, 1.2, IN3], [0.62, 0.9], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.42, -0.15], [0.5, 0.15, IN3], [0.62, 0.1], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.6, 0], [1, 0]])
	return c


## The dive: it rises high tilting back, tails curling, then dives head first (strike) with its tails streaming
## back through the flight, squashes as it lands (hold) and rises back up.
static func _leap() -> BossClip:
	var c := BossClip.new(&"leap")
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.42, 0.65],
			[0.47, 0.7, OUT],
			[0.5, 0.3, IN3],
			[0.6, -0.35],
			[0.62, -0.55, IN3],
			[0.7, -0.45],
			[1, 0]
		]
	)
	c.turn(
		B,
		Z,
		[
			[0, 0],
			[0.42, 0.38],
			[0.5, -0.65, IN3],
			[0.6, -0.6],
			[0.62, -0.1, IN3],
			[0.72, 0.06, OUT, S],
			[1, 0]
		]
	)
	c.stretch(
		B,
		[
			[0, 0],
			[0.42, -0.06],
			[0.5, 0.16, IN3],
			[0.6, 0.14],
			[0.62, -0.25, IN3],
			[0.7, 0.06, OUT, S],
			[0.8, 0],
			[1, 0]
		]
	)
	c.param(&"tail_curl", [[0, 0], [0.42, 0.7], [0.5, 0.0, IN3], [1, 0]])
	c.param(
		&"tail_sweep", [[0, 0], [0.49, 0], [0.5, 1.2, IN3], [0.6, 1.2], [0.62, 0.0, IN3], [1, 0]]
	)
	c.param(&"tail_splay", [[0, 0], [0.61, 0], [0.62, 1.0, IN3], [0.75, 0.2], [1, 0]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.42, -0.3], [0.5, 0.2], [1, 0]])
	return c


## The split: it shudders and swells as the pods tear loose (their spreading is HiveLensAvatar's split), then a pulse.
static func _deploy() -> BossClip:
	var c := BossClip.new(&"deploy")
	c.stretch(SPINE, [[0, 0], [0.42, 0.14], [0.5, -0.06, IN3], [0.56, 0.06], [0.62, 0.02], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.42, 0.18], [0.5, -0.1, IN3], [0.62, -0.05], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.42, 0.6], [0.5, 1.0, IN3], [0.62, 0.5], [1, 0]])
	c.param(
		&"tremble", [[0, 0], [0.15, 0], [0.42, 0.8], [0.5, 1, LIN], [0.62, 0.2], [0.68, 0], [1, 0]]
	)
	return c


## v0.8.0 BS2 (owner O5, S4): the Gaze. Its windup (0..0.2, the 0.8 s the eye brightens): it draws back and up,
## the crown thrown open wide round the eye, trembling harder as the charge builds; on the strike the beam kicks it
## back a little and it then stares, steady, its body leaning against the beam's push, the crown spinning slowly and
## the tails streaming back while the beam turns (0.2..0.9: the long active part); then it blinks and settles.
static func _gaze() -> BossClip:
	var c := BossClip.new(&"gaze")
	c.strike = 0.2
	c.hold = 0.9
	c.turn(
		CROWN_BASE,
		Z,
		[
			[0, 0],
			[0.18, 0.55, BACK],
			[0.2, 0.62],
			[0.25, 0.5],
			[0.88, 0.5],
			[0.93, -0.4, IN3],
			[1, 0]
		]
	)
	c.turn(CROWN, Z, [[0, 0], [0.18, 0.3], [0.88, 0.25], [1, 0]])
	c.stretch(PODS, [[0, 0], [0.18, 0.18], [0.2, 0.24, IN3], [0.88, 0.16], [1, 0]])
	c.stretch(SPINE, [[0, 0], [0.18, 0.06], [0.2, -0.05, IN3], [0.25, 0.02], [0.88, 0.02], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.18, -0.2], [0.2, -0.32, IN3], [0.26, -0.22], [0.88, -0.2], [1, 0]])
	c.shift(B, UP, [[0, 0], [0.18, 0.18, OUT], [0.26, 0.12], [0.88, 0.12], [1, 0]])
	c.turn(B, Z, [[0, 0], [0.18, 0.12], [0.2, -0.1, IN3], [0.26, -0.04], [0.88, -0.05], [1, 0]])
	c.turn(
		B,
		X,
		[[0, 0], [0.3, 0.04, IO, S], [0.5, -0.04, IO, S], [0.7, 0.04, IO, S], [0.88, 0], [1, 0]]
	)
	c.param(&"spin", [[0, 0], [0.18, 3.0], [0.25, 1.2], [0.88, 1.2], [1, 0]])
	c.param(&"tail_sweep", [[0, 0], [0.2, -0.2], [0.26, -0.7, IN3], [0.88, -0.6], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.18, 0.4], [0.88, 0.3], [1, 0]])
	c.param(
		&"tremble",
		[[0, 0], [0.05, 0.1], [0.19, 0.9, LIN], [0.2, 0.4], [0.88, 0.25], [0.92, 0], [1, 0]]
	)
	return c


## Shielded (the Prism Spiral): it closes up. The crown folds down over the eye, the shell and pods draw in, the
## tails curl up under it.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	c.turn(CROWN_BASE, Z, [[0, 0], [0.7, -0.92, BACK], [1, -0.85]])
	c.turn(CROWN, Z, [[0, 0], [0.7, -0.38], [1, -0.35]])
	c.shift(SHELL_TOP, FWD, [[0, 0], [0.7, 0.06], [1, 0.06]])
	c.shift(SHELL_TOP, UP, [[0, 0], [0.7, -0.04], [1, -0.04]])
	c.stretch(PODS, [[0, 0], [0.7, -0.14], [1, -0.12]])
	c.param(&"tail_curl", [[0, 0], [0.7, 1.1, BACK], [1, 1.0]])
	return c


static func _flinch() -> BossClip:
	var c := BossClip.new(&"flinch")
	c.turn(B, Z, [[0, 0], [0.15, 0.2, OUT3], [0.5, -0.05, IO, S], [1, 0]])
	c.shift(B, FWD, [[0, 0], [0.15, -0.12, OUT3], [1, 0]])
	c.param(&"tail_curl", [[0, 0], [0.15, 0.45, OUT3], [1, 0]])
	return c


## Staggered: it sags toward the ground and tips, crown drooping, tails limp.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.shift(B, UP, [[0, 0], [0.1, 0.12, OUT3], [0.4, -0.38], [1, -0.36]])
	c.turn(B, Z, [[0, 0], [0.1, -0.15], [0.4, 0.3], [1, 0.3]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.4, -0.32], [1, -0.3]])
	c.param(&"tail_sweep", [[0, 0], [0.4, -0.3], [1, -0.3]])
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The phase gate's roar: it rises, the crown thrown wide open, swelling, tails flung out, the crown spinning hard.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.shift(B, UP, [[0, 0], [0.22, -0.15], [0.36, 0.3, BACK], [0.85, 0.25], [1, 0]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.22, -0.3], [0.36, 0.75, BACK], [0.85, 0.7], [1, 0]])
	c.stretch(SPINE, [[0, 0], [0.22, -0.08], [0.36, 0.18, BACK], [0.85, 0.15], [1, 0]])
	c.stretch(PODS, [[0, 0], [0.36, 0.25], [0.85, 0.22], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.22, -0.2], [0.36, 1.2, BACK], [0.85, 1.1], [1, 0]])
	c.param(&"spin", [[0, 0], [0.36, 6.0], [0.85, 5.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 0.8, LIN], [0.8, 0.6], [0.9, 0], [1, 0]])
	return c


## The rise-in: it comes up closed, tails curled, then opens with a pulse and a flick of its tails.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.turn(CROWN_BASE, Z, [[0, -0.85], [0.5, -0.8], [0.64, 0.45, BACK], [0.8, 0.1], [1, 0]])
	c.param(&"tail_curl", [[0, 1.0], [0.5, 1.0], [0.64, 0.0, IN3], [1, 0]])
	c.param(&"tail_splay", [[0, 0], [0.6, 0], [0.66, 1.0, OUT3], [1, 0]])
	c.stretch(SPINE, [[0, 0], [0.5, -0.05], [0.64, 0.18, BACK], [0.8, 0.0], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.63, 0], [0.64, 0.8, LIN], [0.74, 0], [1, 0]])
	return c


## Its death: it jerks up, then drops out of the air, rolls onto its side as it hits the ground, bounces, crown
## drooping and tails limp, and sinks.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	c.shift(
		B,
		UP,
		[
			[0, 0],
			[0.15, 0.25, OUT3],
			[0.55, -1.05, IN],
			[0.62, -0.9, OUT, S],
			[0.7, -1.05],
			[0.84, -1.05],
			[1, -3.2, IN]
		]
	)
	c.turn(
		B, X, [[0, 0], [0.15, -0.1], [0.55, 1.1, IN], [0.62, 0.95, OUT, S], [0.7, 1.1], [1, 1.1]]
	)
	c.turn(B, Z, [[0, 0], [0.15, 0.25], [0.6, -0.2], [1, -0.2]])
	c.stretch(B, [[0, 0], [0.54, 0], [0.56, -0.2, IN3], [0.64, 0.05, OUT, S], [0.7, 0], [1, 0]])
	c.turn(CROWN_BASE, Z, [[0, 0], [0.15, 0.5], [0.6, -0.6], [1, -0.65]])
	c.param(&"tail_sweep", [[0, 0], [0.15, 0.6], [0.55, -0.7], [1, -0.7]])
	c.param(&"tremble", [[0, 0], [0.54, 0], [0.56, 1, LIN], [0.66, 0], [1, 0]])
	return c
