class_name SwarmerModel
extends RefCounted
## The Swarmer on the owner's model (EnemyModels &"swarmer", cut by scripts/assets/hatchling_swarmer_prep.py into the
## body, the two wing-case halves, the two mandibles and six two-part legs), posed for HordeAvatar. The owner asked
## for the enemies to be "animated as good as you can", and for the horde critters to stay small and animated; the
## Swarmer comes in packs of 8, so it stays on the batched horde path: four drives a body (HordeVat: the windup raise,
## the strike, the legs, the gait's phase), the body's own moves the crowd's instance transform, and the native
## avatar (native/src/zd_avatar.cpp, sw_pose) reckoning the same numbers.
## Its clips, from the sim's states through HordeAvatar (the same state as the code body):
## - the gait: a tripod scuttle (front and hind on one side with the middle on the other), each foot swinging back
##   on the ground and lifted as it comes forward, the cadence and the stride growing with the pace; a small bob;
## - idle: the mandibles working, the wing cases breathing, the feet shuffling (none of it with reduced motion);
## - the tell (WINDUP): it rears on its hind feet, the wing cases opening up and out, the mandibles gaping, the front
##   legs raised;
## - the strike (ACTIVE): it lunges nose down onto its front feet, the mandibles snapping shut, the wing cases slamming
##   closed;
## - the crouch of the tell's last part, the hit flinch (AvatarBase), the rise-in (the code body's: up out of the
##   ground);
## - the death (DEATH_SECONDS, die()): it hops and rolls onto its back, the legs curling up, the eye going out.
## Every part's pose is a function of one grid's drives only (pose_parts), so the VAT bake of the same code is the
## live pose. Presentation only (EI-07). +X is the front, +Z its right.

## The drives (natural units, HordeAvatar._pose_parts): x the windup raise, y the strike, z the legs (0..1 the walk's
## pace; below 0 the death's curl, -1 fully curled), w the gait's phase (loops).
## The grids (VatBake's: [[drive, samples, loops], ...]): the stance over the raise and the strike; the gait over its
## phase (a loop) and the legs. Starting values (the error: scripts/checks/vat_bake_report.gd).
const GRIDS := [[[0, 17, false], [1, 17, false]], [[3, 48, true], [2, 17, false]]]
## The gait's cadence (Hz) at a full walk and idle (the feet shuffling, the mandibles working).
const STEP_HZ := 8.0
const IDLE_HZ := 1.1
## The leg's swing (rad either side) and its lift (rad) at a full stride; the knee's share of the lift.
const SWING := 0.42
const LIFT := 0.38
const KNEE_LIFT := 0.5
## The idle shuffle (rad), the death's curl (the hip's lift and the knee's fold, rad).
const SHUFFLE := 0.05
const CURL_HIP := 0.8
const CURL_KNEE := 1.5
## The wing cases' opening (rad: the rear's lift, the outer edge's roll) and their breath (rad).
const SHELL_PITCH := 0.4
const SHELL_ROLL := 0.45
const SHELL_BREATH := 0.035
## The mandibles: the gape at a full raise, the snap at the strike (rad), how far shut they may cross, their working.
const GAPE := 0.6
const SNAP := 0.75
const SHUT := -0.12
const CHATTER := 0.1
## The front legs' raise at the tell (rad).
const RAISE := 0.6
## The body (m, rad): its lean back on the raise, forward on the strike and the crouch, about its hind feet (REAR_X)
## or its front feet (FRONT_X), so a planted foot stays on the ground; the strike's lunge and the crouch's draw-back;
## the stride's bob; the death's roll onto its back, about BODY_Y, and its hop.
const LEAN_REAR := 0.3
const LEAN_LUNGE := 0.2
const LEAN_CROUCH := 0.08
const REAR_X := -0.18
const FRONT_X := 0.11
const LUNGE_M := 0.09
const DRAW_M := 0.03
const BOB_M := 0.006
const DEATH_ROLL := 2.4
const BODY_Y := 0.1
const HOP_M := 0.05
## The legs, in pairs: fr / fl the front, mr / ml the middle, br / bl the hind; the tripods step half a stride apart.
const LEGS: Array[StringName] = [&"fr", &"fl", &"mr", &"ml", &"br", &"bl"]
const TRIPOD := [0.0, 0.5, 0.5, 0.0, 0.0, 0.5]


## The gait clock's rate (rad a second: HordeAvatar._walk_t) at the walk's pace `walk`; idle only without `calm`.
static func gait_rate(walk: float, calm: bool) -> float:
	return TAU * (IDLE_HZ * (1.0 - walk) * (0.0 if calm else 1.0) + STEP_HZ * walk)


## Rebuilds the parts `a` (HordeAvatar._build_model's flat pivots) into the joints: each wing case and mandible a gait
## node (the breath, the working) holding its stance node (the opening, the gape), each leg's upper half (the gait's
## swing and lift; the front pair a stance node under it, the raise) holding the lower half (the knee). Each leg's
## lift axis (out of its hip, across the ground) is kept in the avatar's meta.
static func rig_nodes(a: HordeAvatar) -> void:
	for pname: String in ["shell_l", "shell_r", "mand_l", "mand_r"]:
		var n := a.parts[pname] as Node3D
		var g := Node3D.new()
		g.name = pname.to_pascal_case() + "Gait"
		g.position = n.position
		a.model.add_child(g)
		n.reparent(g, false)
		n.position = Vector3.ZERO
		a.parts[pname + "_g"] = g
	var legs: Array = []
	for leg: StringName in LEGS:
		var up := a.parts["leg_%s_u" % leg] as Node3D
		var low := a.parts["leg_%s_l" % leg] as Node3D
		var hold := up
		if leg in [&"fr", &"fl"]:
			hold = Node3D.new()
			hold.name = "Raise" + String(leg).to_upper()
			up.add_child(hold)
			for c in up.get_children():
				if c != hold:
					c.reparent(hold, false)
			a.parts["leg_%s_r" % leg] = hold
		var knee := low.position - up.position
		low.reparent(hold, false)
		low.position = knee
		var out := Vector3(knee.x, 0.0, knee.z).normalized()
		legs.append([up.position, knee, out.cross(Vector3.UP).normalized(), signf(out.z)])
	a.set_meta(&"swarmer_legs", legs)


## The joints (HordeVat.joint_spec) past the body, a parent before its children.
static func joints(a: HordeAvatar) -> Array:
	var gs := VatBake.GRID_STANCE
	var gg := VatBake.GRID_GAIT
	var p := a.parts
	var out: Array = []
	for pname: String in ["shell_l", "shell_r", "mand_l", "mand_r"]:
		out.append_array([[p[pname + "_g"], gg], [p[pname], gs]])
	for leg: StringName in LEGS:
		out.append([p["leg_%s_u" % leg], gg])
		if p.has("leg_%s_r" % leg):
			out.append([p["leg_%s_r" % leg], gs])
		out.append([p["leg_%s_l" % leg], gg])
	return out


## Poses the parts of `a` (built with its pieces) at drives `d` (natural units, see the class notes): the live pose
## and the VAT bake both pose through here. Each node's transform is set whole from its own grid's drives.
static func pose_parts(a: HordeAvatar, d: Vector4) -> void:
	var p := a.parts
	var wind := d.x
	var strike := d.y
	var walk := maxf(d.z, 0.0)
	var live := 1.0 - clampf(-d.z, 0.0, 1.0)
	var dead := 1.0 - live
	var open := wind * (1.0 - strike)
	var breath := SHELL_BREATH * (0.5 + 0.5 * sin(d.w * TAU)) * live
	for side: Array in [["shell_r", -1.0], ["shell_l", 1.0]]:
		var s: float = side[1]
		var g := p[side[0] + "_g"] as Node3D
		g.transform = Transform3D(Basis(Vector3.BACK, -breath), g.position)
		(p[side[0]] as Node3D).transform = Transform3D(
			Basis(Vector3.RIGHT, s * SHELL_ROLL * open) * Basis(Vector3.BACK, -SHELL_PITCH * open),
			Vector3.ZERO
		)
	var gape := clampf(GAPE * wind - SNAP * strike, SHUT, GAPE)
	var work := CHATTER * sin(d.w * TAU) * live * (1.0 - 0.7 * walk)
	for side: Array in [["mand_r", -1.0], ["mand_l", 1.0]]:
		var s: float = side[1]
		var g := p[side[0] + "_g"] as Node3D
		g.transform = Transform3D(Basis(Vector3.UP, s * work), g.position)
		(p[side[0]] as Node3D).transform = Transform3D(Basis(Vector3.UP, s * gape), Vector3.ZERO)
	var legs: Array = a.get_meta(&"swarmer_legs")
	for k in LEGS.size():
		var leg: Array = legs[k]
		var axis: Vector3 = leg[2]
		var at: float = (d.w + float(TRIPOD[k])) * TAU
		var sw := sin(at)
		var up := maxf(0.0, cos(at))
		var yaw := float(leg[3]) * sw * (SWING * walk + SHUFFLE * (1.0 - walk) * live)
		var hip := up * LIFT * walk + dead * CURL_HIP
		var knee := up * LIFT * KNEE_LIFT * walk - dead * CURL_KNEE
		var u := p["leg_%s_u" % LEGS[k]] as Node3D
		u.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(axis, hip), leg[0])
		var r := p.get("leg_%s_r" % LEGS[k]) as Node3D
		if r != null:
			r.transform = Transform3D(Basis(axis, RAISE * open), Vector3.ZERO)
		(p["leg_%s_l" % LEGS[k]] as Node3D).transform = Transform3D(Basis(axis, knee), leg[1])


## The body's place (HordeAvatar._pose_model, for the Swarmer; native/src/zd_avatar.cpp sw_pose reckons the same
## numbers in the same order): its lean about its hind or front feet, the lunge and the crouch's draw-back, the
## stride's bob, the rise-in's sink, the death's hop and roll onto its back about its middle and its shrink; then the
## parts' drives (the legs: the pace, or the death's curl) and the eye's glow.
static func place(a: HordeAvatar, energy: float) -> void:
	var d := clampf(a._die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0) if a._die_t >= 0.0 else 0.0
	var crouch := a.crouch_amount()
	var lean := (
		a._wind * LEAN_REAR * (1.0 - a._strike) - a._strike * LEAN_LUNGE - crouch * LEAN_CROUCH
	)
	var px := REAR_X if lean > 0.0 else FRONT_X
	var roll := -d * DEATH_ROLL
	var x := px * (1.0 - cos(lean)) - crouch * DRAW_M + a._strike * LUNGE_M
	var y := (
		-(1.0 - a._rise) * a.height
		- px * sin(lean)
		+ absf(sin(a._walk_t)) * BOB_M * a._walk
		+ BODY_Y * (1.0 - cos(roll))
		+ sin(d * PI) * HOP_M
	)
	var z := -BODY_Y * sin(roll)
	a._place_body(Vector3(x, y, z), lean, roll, 1.0 - 0.35 * d)
	var legs := -d if a._die_t >= 0.0 else a._walk
	var phase := a._walk_t / TAU
	a._pose_parts(Vector4(a._wind, a._strike, legs, phase - floor(phase)))
	a._set_glow(energy * lerpf(0.2, 1.0, a._rise) * (1.0 - d))
