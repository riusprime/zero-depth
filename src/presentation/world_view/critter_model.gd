class_name CritterModel
extends RefCounted
## The Dust Mite, the Ember Flea and the Ice Crab on the owner's models (EnemyModels &"dust_mite", &"ember_flea",
## &"ice_crab", cut by scripts/assets/critter_prep.py), posed for HordeAvatar and for CritterCrowd. The owner asked for
## the horde critters to stay small and animated ("these models can not walk or be static models that look out of
## place"), and a surge brings dozens, so they stay on the crowd's batched path: one MultiMesh per kind, the body's own
## moves the instance transform (body_xf), the moving parts baked over four drives (HordeVat). A kind whose model is
## missing keeps its code body (CritterBodies).
## The clips:
## - Dust Mite (Ruins): eight legs scuttling in two alternating sets of four, each foot lifted as it swings forward
##   and planted as it pushes back, the cadence growing with the pace, a small bob; idle, the feet shuffle;
## - Ember Flea (Red Canyon): hops in short arcs (CritterBodies.HOP_M at HOP_HZ, as its code body), the big back legs
##   kicking out on the take-off and folding high in the air, the front legs tucking and reaching for the landing, the
##   body pitching up as it rises and down as it falls; its eye and ember cracks pulse;
## - Ice Crab (Frozen Shore): scuttles side-on (the body turns across its path as the pace grows), its legs stepping
##   in two sets, its claws raised and snapping (idle too); it slides a little as it stops (CritterBodies.SLIDE_M);
## - each: the hit (the legs or claws flung up, the body squashed back), the rise-in (up out of the ground), the
##   death (DEATH_SECONDS: a hop and a roll onto its back, the legs curling, the eye going out), and reduced motion
##   (no idle shuffle, no snapping, no hop, no pulse).
## No strike: the critters only touch (contact damage, no windup in the sim). Every part's pose is a function of one
## grid's drives only (pose_parts), so the VAT bake of the same code is the live pose. Presentation only (EI-07).
## +X is the front, +Z its right.

## The kinds on a model and their model ids.
const KINDS := {
	WorldReader.KIND_DUST_MITE: &"dust_mite",
	WorldReader.KIND_EMBER_FLEA: &"ember_flea",
	WorldReader.KIND_ICE_CRAB: &"ice_crab",
}
## The flea's glow (its eye and its ember cracks); the mite's and the crab's eye are the family's crimson.
const EMBER := Color("#FF7A2A")
## The drives (natural units): x the hit's flinch (0..1), y the crab's claws open (0..1), z the legs (0..1 the walk's
## pace, the flea's hop on or off; below 0 the death's curl, -1 fully curled), w the gait's phase (loops).
## The grids (VatBake's: [[drive, samples, loops], ...]): the stance over the flinch and the claws; the gait over its
## phase (a loop) and the legs. Starting values (the error: scripts/checks/vat_bake_report.gd).
const GRIDS := [[[0, 9, false], [1, 9, false]], [[3, 96, true], [2, 17, false]]]
## The gait's cadence (Hz) at a full walk and idle (the feet shuffling); the flea's is its hop.
const STEP_HZ := {
	WorldReader.KIND_DUST_MITE: 12.0,
	WorldReader.KIND_EMBER_FLEA: CritterBodies.HOP_HZ,
	WorldReader.KIND_ICE_CRAB: 9.0,
}
const IDLE_HZ := 1.2
## The legs' swing (rad either side) and lift (rad) at a full stride; the idle shuffle; the death's curl (rad); the
## hit's fling (rad).
const SWING := {WorldReader.KIND_DUST_MITE: 0.5, WorldReader.KIND_ICE_CRAB: 0.35}
const LIFT := {WorldReader.KIND_DUST_MITE: 0.55, WorldReader.KIND_ICE_CRAB: 0.45}
const SHUFFLE := 0.08
const CURL := 1.2
const FLING := 0.5
## The legs' sets: a leg's phase offset by its place (r1..r4 front to back on the right, then l1..l4).
const SET_OFFSET := [0.0, 0.5, 0.0, 0.5, 0.5, 0.0, 0.5, 0.0]
## The flea's back legs (rad about +Z, at a full kick, tuck and reach: the thigh, the shin) and its front legs' tuck
## and reach (rad).
const KICK := Vector2(0.55, -0.45)
const TUCK := Vector2(-0.25, 0.5)
const REACH := Vector2(0.2, -0.15)
const FRONT_TUCK := 0.5
const FRONT_REACH := 0.35
## The flea's body: its pitch (rad) through the hop, about its hind feet (FOOT_BACK) or its front feet (FOOT_FRONT).
const PITCH := 0.25
const FOOT_BACK := -0.08
const FOOT_FRONT := 0.1
## The crab: its claws' raise and their open and shut (rad), the snap's rate (Hz); the body's turn across its path at
## a full walk (rad) and its sway (m).
const CLAW_RAISE := 0.35
const CLAW_OPEN := 0.5
const CLAW_SHUT := -0.08
const SNAP_HZ := 1.4
const SIDE_YAW := 1.0
const SWAY_M := 0.01
## The stride's bob (m), the flea's glow pulse (Hz), the hit's lean back (rad) and squash (as AvatarBase's flinch).
const STRIDE_BOB := 0.005
const PULSE_HZ := 1.3
const FLINCH_LEAN := 0.3
const FLINCH_SQUASH := 0.16
## The death: the roll onto its back (rad) about BODY_Y (m), its hop (m).
const DEATH_ROLL := {
	WorldReader.KIND_DUST_MITE: 2.8,
	WorldReader.KIND_EMBER_FLEA: 1.7,
	WorldReader.KIND_ICE_CRAB: 2.9,
}
const BODY_Y := {
	WorldReader.KIND_DUST_MITE: 0.1,
	WorldReader.KIND_EMBER_FLEA: 0.12,
	WorldReader.KIND_ICE_CRAB: 0.09,
}
const DEATH_HOP := {
	WorldReader.KIND_DUST_MITE: 0.1,
	WorldReader.KIND_EMBER_FLEA: 0.1,
	WorldReader.KIND_ICE_CRAB: 0.17,
}

## Whether each kind's model is there (read once).
static var _on := {}


static func takes(kind: int) -> bool:
	return KINDS.has(kind)


## True when `kind` is drawn on the owner's model (its file is there).
static func on_model(kind: int) -> bool:
	if not KINDS.has(kind):
		return false
	if not _on.has(kind):
		_on[kind] = EnemyModels.has_model(KINDS[kind])
	return _on[kind]


## Forgets the models read (tests that point EnemyModels elsewhere).
static func clear_cache() -> void:
	_on.clear()


## The glow colour of `kind` on its model (`family`: the family's eye).
static func eye_color(kind: int, family: Color) -> Color:
	return EMBER if kind == WorldReader.KIND_EMBER_FLEA else family


## The gait clock's rate (rad a second) at the walk's pace `walk`: the flea's is its hop (none with reduced motion).
static func gait_rate(kind: int, walk: float, calm: bool) -> float:
	if kind == WorldReader.KIND_EMBER_FLEA:
		return 0.0 if calm else TAU * float(STEP_HZ[kind])
	return TAU * (IDLE_HZ * (1.0 - walk) * (0.0 if calm else 1.0) + float(STEP_HZ[kind]) * walk)


## The gait's phase (0..1) of `kind` at the clock `t`, its gait clock at `gait_ph`: the flea's is its hop's, on the
## frame-time clock as its code body's (CritterBodies.HOP_HZ).
static func phase(kind: int, t: float, gait_ph: float) -> float:
	if kind == WorldReader.KIND_EMBER_FLEA:
		return fposmod(t * CritterBodies.HOP_HZ, 1.0)
	return gait_ph


## The body's transform past its place and facing (the crowd's instance; the avatar's body node): `t` the frame-time
## clock, `ph` the gait's phase (0..1), `walk` the pace, `slide` the crab's (0..1; < 0 none), `die_t` seconds into the
## death (< 0 alive), `flinch` the hit's (0..1, the crowd's; an avatar's node flinches itself), `rise` the rise-in.
static func body_xf(
	kind: int,
	t: float,
	ph: float,
	walk: float,
	slide: float,
	die_t: float,
	flinch: float,
	rise: float,
	calm: bool
) -> Transform3D:
	var live := die_t < 0.0
	var x := 0.0
	var y := -(1.0 - rise) * float(CritterBodies.HEIGHTS[kind])
	if not calm:
		y += (0.5 + 0.5 * sin(t * HordeAvatar.BOB_RATE)) * HordeAvatar.BOB_M
	var lean := 0.0
	if flinch != 0.0:  # The recoil leans back about the hind feet
		lean = FLINCH_LEAN * 0.6 * flinch
		x -= 0.02 * flinch
		y += 0.12 * sin(lean)
	var yaw := 0.0
	var z := 0.0
	match kind:
		WorldReader.KIND_EMBER_FLEA:
			if live and not calm:
				var p := sin(ph * TAU) * PITCH
				var px := FOOT_BACK if p > 0.0 else FOOT_FRONT
				x += px * (1.0 - cos(p))
				y += sin(ph * PI) * CritterBodies.HOP_M - px * sin(p)
				lean += p
		WorldReader.KIND_ICE_CRAB:
			if slide >= 0.0:
				x += sin(clampf(slide, 0.0, 1.0) * PI) * CritterBodies.SLIDE_M
			if walk > 0.0:
				var sw := sin(ph * TAU)
				yaw = SIDE_YAW * walk
				z = sw * SWAY_M * walk
				y += absf(sw) * STRIDE_BOB * walk
		_:
			if walk > 0.0:
				y += absf(sin(ph * TAU)) * STRIDE_BOB * walk
	# Each turn only when it is not none (the common frame, alive and unhit, builds one basis or none).
	var b := Basis.IDENTITY if lean == 0.0 else Basis(Vector3.BACK, lean)
	if not live:  # The death: a hop and a roll onto its back about its middle, shrinking
		var d := clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0)
		var roll := -d * float(DEATH_ROLL[kind])
		var by: float = BODY_Y[kind]
		y += by * (1.0 - cos(roll)) + sin(d * PI) * float(DEATH_HOP[kind])
		z -= by * sin(roll)
		b = b * Basis(Vector3.RIGHT, roll)
		if yaw != 0.0:
			b = b * Basis(Vector3.UP, yaw)
		b = b * Basis.from_scale(Vector3.ONE * (1.0 - 0.35 * d))
	elif yaw != 0.0:
		b = b * Basis(Vector3.UP, yaw)
	if flinch != 0.0:
		b = (
			b
			* Basis.from_scale(
				Vector3(
					1.0 + 0.5 * FLINCH_SQUASH * flinch,
					1.0 - FLINCH_SQUASH * flinch,
					1.0 + 0.5 * FLINCH_SQUASH * flinch
				)
			)
		)
	return Transform3D(b, Vector3(x, y, z))


## The drives (natural units, see GRIDS) of `kind` at the clock `t`, phase `ph`, pace `walk`, death `die_t` (< 0
## alive) and flinch `flinch`.
static func drives(
	kind: int, t: float, ph: float, walk: float, die_t: float, flinch: float, calm: bool
) -> Vector4:
	var legs := walk
	if die_t >= 0.0:
		legs = -clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0)
	elif kind == WorldReader.KIND_EMBER_FLEA:
		legs = 0.0 if calm else 1.0
	var claws := 0.0
	if kind == WorldReader.KIND_ICE_CRAB and die_t < 0.0:
		claws = 0.35 if calm else snap(t)
	return Vector4(clampf(flinch, 0.0, 1.0), claws, legs, ph)


## The crab's claws (0 shut .. 1 open) at the clock `t`: they open slowly and snap shut.
static func snap(t: float) -> float:
	var u := fposmod(t * SNAP_HZ, 1.0)
	if u < 0.7:
		return sin(u / 0.7 * PI * 0.5)
	var c := (u - 0.7) / 0.3
	return (1.0 - c) * (1.0 - c)


## The accent's glow (the eye; the flea's cracks, pulsing) at the clock `t`.
static func energy(kind: int, t: float, rise: float, die_t: float, calm: bool) -> float:
	var d := clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0) if die_t >= 0.0 else 0.0
	var e := 1.5 * lerpf(0.2, 1.0, rise) * (1.0 - d)
	if kind == WorldReader.KIND_EMBER_FLEA and not calm:
		e *= 0.8 + 0.5 * (0.5 + 0.5 * sin(t * TAU * PULSE_HZ))
	return e


## HordeVat: the drives in the grids' units (the legs -1..1 to 0..1, the phase wrapped).
static func grid_of(d: Vector4) -> Vector4:
	return Vector4(d.x, d.y, (d.z + 1.0) / 2.0, fposmod(d.w, 1.0))


## The inverse of grid_of at stance grid point `u` and gait phase `phase`.
static func natural(u: Vector3, phase: float) -> Vector4:
	return Vector4(u.x, u.y, u.z * 2.0 - 1.0, phase)


## Rebuilds the parts of `a` (HordeAvatar._build_model's flat pivots) into the joints: each limb a gait node at its
## pivot (the step, the hop's kick, the death's curl) holding its own node (the stance: the hit's fling, the claws'
## snap); the flea's shin under its thigh. Each limb's [name, pivot, lift axis, side, phase offset] is kept in the
## avatar's meta.
static func rig_nodes(a: HordeAvatar) -> void:
	var limbs: Array = []
	var names: Array = a.parts.keys()
	names.sort()
	for pname: String in names:
		if pname == "body" or pname.begins_with("shin"):
			continue
		var n := a.parts[pname] as Node3D
		var g := Node3D.new()
		g.name = pname.to_pascal_case() + "Gait"
		g.position = n.position
		a.model.add_child(g)
		n.reparent(g, false)
		n.position = Vector3.ZERO
		a.parts[pname + "_g"] = g
		var mesh := (n.get_child(0) as MeshInstance3D).mesh
		var c := mesh.get_aabb().get_center()
		var out := Vector3(c.x, 0.0, c.z).normalized()
		var side := signf(g.position.z)
		var k := _set_index(pname)
		limbs.append(
			[
				pname,
				g.position,
				out.cross(Vector3.UP).normalized(),
				side,
				float(SET_OFFSET[k]) if k >= 0 else 0.0
			]
		)
	for side: String in ["l", "r"]:
		if a.parts.has("shin_" + side):
			var shin := a.parts["shin_" + side] as Node3D
			var thigh := a.parts["thigh_" + side] as Node3D
			var knee := shin.position - (a.parts["thigh_%s_g" % side] as Node3D).position
			shin.reparent(thigh, false)
			shin.position = knee
	a.set_meta(&"critter_limbs", limbs)


## The leg's place in SET_OFFSET (leg_r1..leg_r4, leg_l1..leg_l4), or -1.
static func _set_index(pname: String) -> int:
	if not pname.begins_with("leg_"):
		return -1
	return (0 if pname[4] == "r" else 4) + int(pname.substr(5)) - 1


## The joints (HordeVat.joint_spec) past the body, a parent before its children.
static func joints(a: HordeAvatar) -> Array:
	var out: Array = []
	for limb: Array in a.get_meta(&"critter_limbs"):
		var pname: String = limb[0]
		out.append_array(
			[[a.parts[pname + "_g"], VatBake.GRID_GAIT], [a.parts[pname], VatBake.GRID_STANCE]]
		)
		if pname.begins_with("thigh"):
			out.append([a.parts["shin" + pname.trim_prefix("thigh")], VatBake.GRID_GAIT])
	return out


## Poses the parts of `a` at drives `d` (natural units, see GRIDS): the live pose and the VAT bake both pose through
## here. Each node's transform is set whole from its own grid's drives.
static func pose_parts(a: HordeAvatar, d: Vector4) -> void:
	var p := a.parts
	var walk := maxf(d.z, 0.0)
	var dead := clampf(-d.z, 0.0, 1.0)
	var live := 1.0 - dead
	var flea := a.kind == WorldReader.KIND_EMBER_FLEA
	var w := fposmod(d.w, 1.0)
	# The flea's hop in three beats: the kick off the ground, the tuck in the air, the reach for the landing.
	var push := pow(sin(PI * w / 0.2), 2.0) if w < 0.2 else 0.0
	var tuck := pow(sin(PI * (w - 0.2) / 0.6), 2.0) if w >= 0.2 and w < 0.8 else 0.0
	var reach := pow(sin(PI * (w - 0.8) / 0.2), 2.0) if w >= 0.8 else 0.0
	for limb: Array in a.get_meta(&"critter_limbs"):
		var pname: String = limb[0]
		var axis: Vector3 = limb[2]
		var side: float = limb[3]
		var g := p[pname + "_g"] as Node3D
		var n := p[pname] as Node3D
		if pname.begins_with("thigh"):
			var th := (KICK.x * push + TUCK.x * tuck + REACH.x * reach) * walk - CURL * 0.5 * dead
			var sh := (KICK.y * push + TUCK.y * tuck + REACH.y * reach) * walk + CURL * dead
			g.transform = Transform3D(Basis(Vector3.BACK, th), limb[1])
			n.transform = Transform3D(Basis(Vector3.BACK, -FLING * d.x), Vector3.ZERO)
			var shin := p["shin" + pname.trim_prefix("thigh")] as Node3D
			shin.transform = Transform3D(Basis(Vector3.BACK, sh), shin.position)
			continue
		if pname.begins_with("claw"):
			var at := (w + (0.0 if side > 0.0 else 0.5)) * TAU
			var raise := CLAW_RAISE * live + 0.12 * sin(at) * walk - 0.4 * dead
			g.transform = Transform3D(Basis(Vector3.BACK, raise), limb[1])
			var open := lerpf(CLAW_SHUT, CLAW_OPEN, d.y)
			n.transform = Transform3D(
				Basis(Vector3.UP, -side * open) * Basis(Vector3.BACK, FLING * d.x), Vector3.ZERO
			)
			continue
		var yaw := 0.0
		var hip := 0.0
		if flea:  # The front legs tuck in the air and reach for the landing
			hip = (FRONT_TUCK * tuck - 0.2 * push) * walk + CURL * dead
			yaw = side * FRONT_REACH * reach * walk
		else:
			var at: float = (w + float(limb[4])) * TAU
			var up := maxf(0.0, cos(at))
			var swing: float = SWING[a.kind]
			yaw = side * sin(at) * (swing * walk + SHUFFLE * (1.0 - walk) * live)
			hip = up * float(LIFT[a.kind]) * walk + CURL * dead
		g.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(axis, hip), limb[1])
		n.transform = Transform3D(Basis(axis, FLING * d.x), Vector3.ZERO)


## The body's place and the parts' drives of `a` this frame (HordeAvatar._pose_model; the crowd reckons the same with
## body_xf and drives): the body node's transform (a VAT avatar's offset), then the parts and the eye's glow.
static func place(a: HordeAvatar) -> void:
	var calm := ViewPrefs.reduced_motion
	var ph := phase(a.kind, a._t, fposmod(a._walk_t / TAU, 1.0))
	var xf := body_xf(a.kind, a._t, ph, a._walk, a._slide, a._die_t, 0.0, a._rise, calm)
	if a.vat:
		a._vat_body = xf
	else:
		a.body.transform = xf
	var k := maxf(a.flinch_amount(), 0.0)
	a._pose_parts(drives(a.kind, a._t, ph, a._walk, a._die_t, k, calm))
	a._set_glow(energy(a.kind, a._t, a._rise, a._die_t, calm))
