class_name ColossusClips
extends RefCounted
## The Colossus's clips (the owner's floating stone giant, one mesh skinned to a full skeleton: the torso from "body"
## up through the chest to the hood, the chest gem, the halo in two halves, two free-floating fists with a wrist, a
## forearm and clawed fingers each, five crystals held in the air under it, plates and a cloak of cloth chains).
## Model frame: +X the front, +Z its right (fist_R), -Z its left (fist_L).
## Its file carries the animations of its hover, its glide, every move and every reaction but two, and the avatar
## plays them (ColossusAvatar.OWNER_PLAYS). The clips of those names here hold only the parameters the avatar maps
## while an animation moves the bones: tremble (the shake of a blow landing), daze (the stagger's sway) and halo_flare
## (the halo spins faster while it is up).
## The combo is three clips, one per kind of strike, and the avatar picks one for each strike: "combo" (the right
## hook), "combo_l" (the left hook) and "combo_slam" (both fists hammered down, the last strike). Each is timed so
## that its time runs evenly through its animation: its strike and the end of its active part sit at the animation's
## own shares (HOOK, SLAM).
## Two clips still move it from code, over the hover the file plays: the shielded hold (none of its moves is shielded:
## the common hold, fists crossed before the chest) and the fall (seen only without the final fight's shatter: a
## lone summon in the Playground).

const Z := Vector3(0, 0, 1)
const X := Vector3(1, 0, 0)
const UP := Vector3(0, 1, 0)
const B := BossClip.BODY
const IN := BossClip.IN
const IN3 := BossClip.IN3
const OUT := BossClip.OUT
const BACK := BossClip.BACK
const LIN := BossClip.LINEAR
## The bones the code clips move, spelt as the model file exports them.
const FIST_L := &"fist_L"
const FIST_R := &"fist_R"
## The file's hook and slam animations: the seconds of the strike pose, of the end of the active part, and of the
## whole animation.
const HOOK := {"strike": 0.8, "recover": 0.9, "length": 52.0 / 30.0}
const SLAM := {"strike": 0.8, "recover": 1.23, "length": 56.0 / 30.0}

static var _lib := {}


static func library() -> Dictionary:
	if _lib.is_empty():
		for c: BossClip in [
			BossClip.new(&"idle", true),
			BossClip.new(&"walk", true),
			_strike(&"combo", HOOK, 0.6),
			_strike(&"combo_l", HOOK, 0.6),
			_strike(&"combo_slam", SLAM, 1.0),
			_leap(),
			BossClip.new(&"marks"),
			_spike_chase(),
			_spike_burst(),
			_shielded(),
			BossClip.new(&"flinch"),
			_stagger(),
			_roar(),
			_rise(),
			_death(),
		]:
			_lib[c.name] = c
	return _lib


## One strike of the combo (the file's "hook_r", "hook_l" or "slam"): the blow shakes it as it lands. The clip's
## strike and hold are the animation's own shares, so the clip's time is the animation's time over its length.
static func _strike(clip_name: StringName, timing: Dictionary, shake: float) -> BossClip:
	var c := BossClip.new(clip_name)
	c.strike = float(timing["strike"]) / float(timing["length"])
	c.hold = float(timing["recover"]) / float(timing["length"])
	c.param(
		&"tremble",
		[[0, 0], [c.strike - 0.01, 0], [c.strike, shake, LIN], [c.strike + 0.08, 0], [1, 0]]
	)
	return c


## The leap (the file's "leap": a coil, the jump with both fists swung overhead, the landing smash): the halo flares
## and the floor shakes as it lands, at the end of the active part.
static func _leap() -> BossClip:
	var c := BossClip.new(&"leap")
	c.param(&"halo_flare", [[0, 0], [0.5, 0.2], [0.62, 1.0, IN3], [0.8, 0.6], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.61, 0], [0.62, 1, LIN], [0.7, 0], [1, 0]])
	return c


## The spike chase (the file's "ground_punch": one fist raised high and driven into the floor, held there while the
## spikes run): the punch shakes it.
static func _spike_chase() -> BossClip:
	var c := BossClip.new(&"spike_chase")
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 0.8, LIN], [0.6, 0.2], [0.7, 0], [1, 0]])
	return c


## The spike burst (the file's "burst": both fists thrown wide and high, slammed down either side): the halo flares
## as the rings of spikes run out.
static func _spike_burst() -> BossClip:
	var c := BossClip.new(&"spike_burst")
	c.param(&"halo_flare", [[0, 0], [0.5, 0.2], [0.62, 1.0, OUT], [0.85, 0.5], [1, 0]])
	c.param(&"tremble", [[0, 0], [0.49, 0], [0.5, 1, LIN], [0.64, 0], [1, 0]])
	return c


## Shielded: the fists drawn in and crossed before the chest, turned inward.
static func _shielded() -> BossClip:
	var c := BossClip.new(&"shielded")
	for row: Array in [[FIST_L, 1.0], [FIST_R, -1.0]]:
		var fist: StringName = row[0]
		var inward: float = row[1]
		c.shift(fist, X, [[0, 0], [0.7, 0.8, BACK], [1, 0.75]])
		c.shift(fist, UP, [[0, 0], [0.7, 0.3], [1, 0.25]])
		c.shift(fist, Z, [[0, 0], [0.7, 1.0 * inward, BACK], [1, 0.95 * inward]])
		c.turn(fist, UP, [[0, 0], [0.7, -0.6 * inward], [1, -0.6 * inward]])
	return c


## Staggered (the file's "stagger"): the dazed sway on top of its sag.
static func _stagger() -> BossClip:
	var c := BossClip.new(&"stagger")
	c.param(&"daze", [[0, 0], [0.3, 0.3], [0.6, 1], [1, 1]])
	return c


## The roar (the file's "roar"): shaking while it is reared back.
static func _roar() -> BossClip:
	var c := BossClip.new(&"roar")
	c.param(&"tremble", [[0, 0], [0.34, 0], [0.38, 1, LIN], [0.8, 0.8], [0.9, 0], [1, 0]])
	return c


## The rise (the file's "rise": it gathers itself off the floor, the torso first, the fists and the halo after): a
## shudder as the torso comes upright.
static func _rise() -> BossClip:
	var c := BossClip.new(&"rise")
	c.param(&"tremble", [[0, 0], [0.45, 0], [0.47, 0.8, LIN], [0.6, 0], [1, 0]])
	return c


## Its fall: the fists lose their hold on the air and drop as it crumples forward, then it sinks away.
static func _death() -> BossClip:
	var c := BossClip.new(&"death")
	for fist: StringName in [FIST_L, FIST_R]:
		c.shift(fist, UP, [[0, 0], [0.4, -0.4, IN], [1, -0.4]])
	c.shift(B, UP, [[0, 0], [0.15, 0.08], [0.55, -0.6, IN], [0.84, -0.7], [1, -3.1, IN]])
	c.turn(B, Z, [[0, 0], [0.55, -0.4, IN], [1, -0.45]])
	return c
