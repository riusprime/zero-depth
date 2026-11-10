class_name ChargerVat
extends RefCounted
## v0.10.5 W3-V4a (owner, 2026-11-06: "can we apply it to the rest of the enemies and test it?"): the Charger's and the
## Hatchling's VAT rig (VatBake's rig, see its class notes): the drives a VAT ChargerAvatar is drawn from, the grids
## they are baked on, and the joints. Its own file only to keep ChargerAvatar under the line limit; it reads the
## avatar's own pose code (ChargerAvatar.leg_angles, body_x, body_basis and the leg terms), never a copy of it.
##
## The drives (ChargerAvatar.vat_drives, each 0..1, a loop's a phase 0..1), in this order: the continuous numbers the
## pose is made of. Any mix of them poses exactly (see rig); only each grid's sampling is an approximation (the error
## report: scripts/checks/vat_bake_report.gd). The rise-in's sink is the exact lift (ChargerAvatar.vat_lift).
## Presentation only (EI-07).

const WIND := 0
const LUNGE := 1
const DAZE := 2
const PHASE := 3
const WALK := 4
const CROUCH := 5
const RISE := 6
const BODY_Y := 7
const FIDGET_CLOCK := 8
const FIDGET := 9
const TWITCH_CLOCK := 10
const DRIVES := 12
## The body's height drive spans these (m): the bob, the breath and the tremble over the deepest drop and the reared
## wind-up (-0.284 .. 0.084), with a margin.
const BODY_Y_LO := -0.32
const BODY_Y_HI := 0.12
## The bake grids: [[drive, samples, loops], ...] per grid. Starting values, chosen so the error report's worst vertex
## stays well under a pixel (15.7 mm at the game camera): the stance (wind x lunge x daze, trilinear); the gait (the
## legs' phase, a loop, x the walk); the rise; the body's height (the hips' hold is a clamp: fine) x the crouch; the
## idle fidget (its clock, a loop, x its amount); the dazed twitch (its clock, a loop, x the daze).
const STANCE := 0
const GAIT := 1
const RISE_GRID := 2
const LIFT := 3
const FIDGET_GRID := 4
const TWITCH := 5
const GRIDS := [
	[[WIND, 17, false], [LUNGE, 17, false], [DAZE, 9, false]],
	[[PHASE, 128, true], [WALK, 5, false]],
	[[RISE, 33, false]],
	[[BODY_Y, 177, false], [CROUCH, 2, false]],
	[[FIDGET_CLOCK, 256, true], [FIDGET, 5, false]],
	[[TWITCH_CLOCK, 32, true], [DAZE, 3, false]],
]
## One leg's joints, hip to talon: [what, grid]. A segment's angles are sums of terms from separate drives (yaws about
## Y, pitches about Z), and turns about one axis add, so each term is a joint of its own on the grid of its drives (see
## rig). The femur's frame ends at p0_hold, the tibia's at p1_rise, the talon's at p2_rise.
const LEG := [
	[&"root", STANCE],
	[&"sweep", GAIT],
	[&"s0", STANCE],
	[&"p0_gait", GAIT],
	[&"p0_rise", RISE_GRID],
	[&"p0_fidget", FIDGET_GRID],
	[&"p0_hold", LIFT],
	[&"knee_hold", LIFT],
	[&"knee_fidget", FIDGET_GRID],
	[&"knee_rise", RISE_GRID],
	[&"knee_gait", GAIT],
	[&"s1", STANCE],
	[&"p1_gait", GAIT],
	[&"p1_rise", RISE_GRID],
	[&"ankle_rise", RISE_GRID],
	[&"ankle_gait", GAIT],
	[&"s2", STANCE],
	[&"p2_twitch", TWITCH],
	[&"p2_rise", RISE_GRID],
]


## The rig of Charger `c`: its drives, its grids (GRIDS) and its joints. The legs' segments are not nested nodes: each
## is placed at the end of the one before and turned by absolute angles (ChargerAvatar._pose_seg), and every angle is
## a sum of terms from different drives (leg_angles). Turns about one axis add (Ry(a + b) = Ry(a) Ry(b)), and a
## segment relative to the one before is T(length) Rz(-pitch) Ry(yaw difference) Rz(next pitch), so the rig nests them
## and splits each pitch and yaw into one joint per term, on the grid of that term's drives (LEG): the composed joints
## are the pose itself, for any mix of the drives. The body and the hips share a first joint, the height and the
## crouch's shift (both plain translations). Built with its pieces, the body's, the femurs', tibias' and talons' nodes
## are the frames the pieces hang in.
static func rig(c: ChargerAvatar) -> Dictionary:
	var joints: Array = [
		{"grid": LIFT, "parent": -1, "frame": null},
		{"grid": STANCE, "parent": 0, "frame": c.body},
	]
	for k in 4:
		var up := 0
		for j: Array in LEG:
			var frame: Node3D = null
			if c.legs.size() == 4:
				match j[0]:
					&"p0_hold":
						frame = c._femurs[k]
					&"p1_rise":
						frame = c._tibias[k]
					&"p2_rise":
						frame = c._talons[k]
			joints.append({"grid": j[1], "parent": up, "frame": frame})
			up = joints.size() - 1
	return {
		"key": "charger",
		"drives": DRIVES,
		"grids": GRIDS,
		"joints": joints,
		"row": func(g: int, d: PackedFloat64Array) -> Array: return row(c, g, d),
		"scaled": true,
	}


## The local transforms of grid `g`'s joints (in rig's order) at the drives `d`: what `c`'s pose code makes of that
## grid's drives alone (each term is leg_angles' with the others at rest).
static func row(c: ChargerAvatar, g: int, d: PackedFloat64Array) -> Array:
	var w: float = d[WIND]
	var lunge: float = d[LUNGE]
	var daze: float = d[DAZE]
	var out: Array = []
	if g == LIFT:
		var by := lerpf(BODY_Y_LO, BODY_Y_HI, d[BODY_Y])
		out.append(
			Transform3D(Basis.IDENTITY, Vector3(ChargerAvatar.body_x(0.0, d[CROUCH], 0.0), by, 0))
		)
	elif g == STANCE:
		out.append(
			Transform3D(
				ChargerAvatar.body_basis(w, lunge, daze),
				Vector3(ChargerAvatar.body_x(w, 0.0, lunge), 0, 0)
			)
		)
	for k in 4:
		c.leg_angles(k, 0, 0, 0, 0, 0, 0, 0, 0, 1.0)
		var base := c.angles()
		match g:
			STANCE:
				c.leg_angles(k, 0, 0, 0, 0, w, lunge, daze, 0, 1.0)
			GAIT:
				var phase: float = d[PHASE] * TAU
				var walk: float = d[WALK]
				c.leg_angles(
					k,
					ChargerAvatar.leg_sweep(k, phase, walk),
					ChargerAvatar.leg_lift(k, phase, walk),
					0,
					0,
					0,
					0,
					0,
					0,
					1.0
				)
			RISE_GRID:
				c.leg_angles(k, 0, 0, 0, 0, 0, 0, 0, 0, d[RISE])
			LIFT:
				var by := lerpf(BODY_Y_LO, BODY_Y_HI, d[BODY_Y])
				c.leg_angles(k, 0, 0, 0, ChargerAvatar.leg_hold(k, by), 0, 0, 0, 0, 1.0)
			FIDGET_GRID:
				var t: float = d[FIDGET_CLOCK] * TAU / 0.9
				var fidget := ChargerAvatar.leg_fidget(k, t, 1.0 - d[FIDGET], 0.0)
				c.leg_angles(k, 0, 0, fidget, 0, 0, 0, 0, 0, 1.0)
			TWITCH:
				var t: float = d[TWITCH_CLOCK] * TAU / 9.0
				c.leg_angles(k, 0, 0, 0, 0, 0, 0, 0, ChargerAvatar.leg_twitch(k, t, daze), 1.0)
		var a := c.angles()
		if g != STANCE:  # a term: its share of each angle
			for i in 6:
				a[i] -= base[i]
		for j: Array in LEG:
			if j[1] == g:
				out.append(_leg_joint(k, j[0], a, w, lunge))
	return out


## One leg joint's local transform from its grid's angles `a` (the stance's: whole; a term's: its share).
static func _leg_joint(
	k: int, what: StringName, a: PackedFloat64Array, wind: float, lunge: float
) -> Transform3D:
	var front := k < 2
	var z := Vector3(0, 0, 1)
	match what:
		&"root":
			var hip: Vector3 = ChargerAvatar.FRONT_HIP if front else ChargerAvatar.BACK_HIP
			var side := 1.0 if k % 2 == 0 else -1.0
			return Transform3D(
				Basis.IDENTITY,
				Vector3(hip.x + ChargerAvatar.body_x(wind, 0.0, lunge), hip.y, hip.z * side)
			)
		&"sweep":
			return Transform3D(Basis(Vector3.UP, a[0]), Vector3.ZERO)
		&"s0":
			return Transform3D(Basis(Vector3.UP, a[0]) * Basis(z, a[1]), Vector3.ZERO)
		&"p0_gait", &"p0_rise", &"p0_fidget", &"p0_hold":
			return Transform3D(Basis(z, a[1]), Vector3.ZERO)
		&"knee_hold":
			var l0: float = (ChargerAvatar.FRONT_LEN if front else ChargerAvatar.BACK_LEN)[0]
			return Transform3D(Basis(z, -a[1]), Vector3(l0, 0, 0))
		&"knee_fidget", &"knee_rise", &"knee_gait":
			return Transform3D(Basis(z, -a[1]), Vector3.ZERO)
		&"s1":
			return Transform3D(
				Basis(z, -a[1]) * Basis(Vector3.UP, a[2] - a[0]) * Basis(z, a[3]), Vector3.ZERO
			)
		&"p1_gait", &"p1_rise":
			return Transform3D(Basis(z, a[3]), Vector3.ZERO)
		&"ankle_rise":
			var l1: float = (ChargerAvatar.FRONT_LEN if front else ChargerAvatar.BACK_LEN)[1]
			return Transform3D(Basis(z, -a[3]), Vector3(l1, 0, 0))
		&"ankle_gait":
			return Transform3D(Basis(z, -a[3]), Vector3.ZERO)
		&"s2":
			return Transform3D(
				Basis(z, -a[3]) * Basis(Vector3.UP, a[4] - a[2]) * Basis(z, a[5]), Vector3.ZERO
			)
		&"p2_twitch", &"p2_rise":
			return Transform3D(Basis(z, a[5]), Vector3.ZERO)
	return Transform3D.IDENTITY


## VatVerify.pose_error: poses Charger `c` in a random state, every drive anywhere in its range and mixed freely
## (reachable or not), and returns it (apply poses another Charger the same).
static func sample(c: ChargerAvatar, rng: RandomNumberGenerator) -> Dictionary:
	var s := {
		"phase": rng.randf() * 20.0,
		"t": rng.randf() * 40.0,
		"walk": rng.randf(),
		"wind": rng.randf(),
		"lunge": rng.randf(),
		"daze": rng.randf(),
		"rise": rng.randf(),
		"windup": rng.randf() < 0.5,
		"tell": rng.randf(),
	}
	if rng.randf() < 0.25:  # a quarter fully risen (the commonest)
		s["rise"] = 1.0
	apply(c, s)
	return s


## Poses Charger `c` in state `s` (sample's).
static func apply(c: ChargerAvatar, s: Dictionary) -> void:
	c._phase = s["phase"]
	c._t = s["t"]
	c._walk = s["walk"]
	c._wind = s["wind"]
	c._lunge = s["lunge"]
	c._daze = s["daze"]
	c._rise = s["rise"]
	c._state = WorldReader.STATE_WINDUP if s["windup"] else WorldReader.STATE_MOVE
	c._tell_p = s["tell"]
	c._pose()
