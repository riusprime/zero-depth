class_name FlyerModel
extends RefCounted
## The Cave Bat and the Star Mote on the owner's models (EnemyModels &"cave_bat", &"star_mote", cut by
## scripts/assets/critter_prep.py), posed for HordeAvatar and for CritterCrowd as CritterModel poses the walking
## critters, on the same four drives and grids (CritterModel.GRIDS), so HordeVat bakes them on the horde path and the
## crowd draws them batched. The owner asked for the floating critters to move ("if there is floating enemies like star
## mote make sure to animate them and give them some movement, these models can not walk or be static models that
## look out of place"), so neither is ever still in flight:
## - Cave Bat (Night Rocks): flies at CritterBodies.BAT_FLY_M. Its wings beat, the downstroke faster than the upstroke
##   (the beat's clock runs DOWN_RATE through it), the outer wing lagging the inner; the body rises on each downstroke
##   and hovers; it pitches into a fast flight and banks into its turns (BANK, from how fast it turns); idle, it now and
##   then glides between beats (the clock lingers with the wings spread level). The hit flings the wings up; the death
##   folds them over its back as it tumbles to the floor and lies there.
## - Star Mote (Starfall): floats at CritterBodies.MOTE_FLOAT_M. The star spins slowly about its face, face and all (one
##   gait loop is a whole turn of the body; its points turning past a still face plate showed the cut under it), the
##   tail turning back against the spin so it trails below and wobbles behind in three lagging segments
##   (TAIL_WOBBLES a turn) and streams back with its pace, it bobs and drifts, tilts into its
##   travel, and its eye's glow pulses. The hit jolts it back and flares the eye; the death flares it, breaks the points
##   and the tail apart and shrinks it away.
## Each: the rise-in (up out of the ground to its height); reduced motion (the bat's beat slow and even, no glide, bob
## or hover; the mote's points and tail still, no bob, drift or pulse). Every part's pose is a function of one grid's
## drives only (pose_parts), so the VAT bake of the same code is the live pose. Presentation only (EI-07). +X is the
## front, +Z its right.

## The kinds and their model ids, and the models' heights (m; EnemyModels.SPECS reads them).
const KINDS := {
	WorldReader.KIND_CAVE_BAT: &"cave_bat",
	WorldReader.KIND_STAR_MOTE: &"star_mote",
}
const BAT_H := 0.2
const MOTE_H := 0.25
const MODEL_H := {WorldReader.KIND_CAVE_BAT: BAT_H, WorldReader.KIND_STAR_MOTE: MOTE_H}
## The height (m) each turns, tumbles and shrinks about (the bat's body, the star's middle).
const BAT_MID_Y := 0.1
const MOTE_MID_Y := 0.112
const MID_Y := {WorldReader.KIND_CAVE_BAT: BAT_MID_Y, WorldReader.KIND_STAR_MOTE: MOTE_MID_Y}
## The bat's beat (Hz) idle and at a full flight, with reduced motion; the downstroke's share of the beat (the clock
## runs 0.5 / DOWN_SHARE through it). Starting values.
const IDLE_FLAP_HZ := 3.2
const FLAP_HZ := 4.6
const CALM_FLAP_HZ := 1.6
const DOWN_SHARE := 0.38
## The idle glide: one every GLIDE_PERIOD s, the gate open GLIDE_OPEN of it; the clock slows to GLIDE_RATE within half
## of GLIDE_WIDTH of the phase GLIDE_AT (the wings spread in a shallow V, early in the downstroke), easing back over
## the other half.
const GLIDE_PERIOD := 2.3
const GLIDE_OPEN := 0.3
const GLIDE_RATE := 0.025
const GLIDE_WIDTH := 0.08
const GLIDE_AT := 0.2
## The wings' beat (rad either side of BEAT_BIAS) idle and at a full flight; the outer wing's (rad) and its lag (of a
## beat); their sweep forward on the downstroke (rad). The death's fold over the back (shoulder, elbow: rad); the hit's
## fling (rad).
const BEAT_IDLE := 0.55
const BEAT_FLY := 0.75
const BEAT_BIAS := 0.1
const TIP_BEAT := 0.4
const TIP_LAG := 0.1
const SWEEP := 0.12
const FOLD := Vector2(1.25, 1.5)
const FLING := 0.5
## The bat's body: its rise on the downstroke (m), its hover (m at HOVER_RATE rad/s), its pitch into a full flight
## (rad), its bank (rad at most, BANK_PER rad per rad/s of turn, easing at BANK_EASE rad/s).
const BEAT_BOB := 0.025
const HOVER_M := 0.02
const HOVER_RATE := 1.7
const DIVE := 0.2
const BANK := 0.45
const BANK_PER := 0.12
const BANK_EASE := 3.0
## The bat's death: the fall's share of it, the tumble (rad) over the fall.
const FALL_SHARE := 0.5
const TUMBLE := TAU
## The mote's spin (turns a second: a gait loop is a turn) and the death's extra spin (rad); its tail's wobble (rad,
## TAIL_WOBBLES a turn) and each segment's lag (of a wobble), its streaming back at a full pace (rad); the death's
## break (m).
const SPIN_HZ := 0.3
const TAIL_WOBBLES := 5.0
const DEATH_SPIN := 1.2
const TAIL_SWAY := 0.35
const TAIL_LAG := 0.12
const TAIL_STREAM := 0.35
const BREAK_M := 0.09
## The mote's body: its bob (m at BOB_RATE rad/s), its sway (roll, rad) and drift (yaw, rad), its tilt into a full
## pace (rad), its eye's pulse (Hz).
const BOB_M := 0.03
const BOB_RATE := 2.4
const SWAY := 0.12
const DRIFT := 0.18
const TILT := 0.3
const PULSE_HZ := 1.1


static func takes(kind: int) -> bool:
	return KINDS.has(kind)


## The gait clock's rate (rad a second) at phase `ph` (0..1), pace `walk`, clock `t`: the bat's beat (faster through
## the downstroke, lingering at the idle glide), the mote's spin (none with reduced motion).
static func gait_rate(kind: int, walk: float, calm: bool, ph: float, t: float) -> float:
	if kind == WorldReader.KIND_STAR_MOTE:
		return 0.0 if calm else TAU * SPIN_HZ
	if calm:
		return TAU * CALM_FLAP_HZ
	var hz := lerpf(IDLE_FLAP_HZ, FLAP_HZ, walk)
	var w := fposmod(ph, 1.0)
	hz *= 0.5 / DOWN_SHARE if w < 0.5 else 0.5 / (1.0 - DOWN_SHARE)
	if fposmod(t / GLIDE_PERIOD, 1.0) < GLIDE_OPEN:
		var near := clampf(2.0 * (1.0 - absf(w - GLIDE_AT) / GLIDE_WIDTH), 0.0, 1.0)
		hz *= 1.0 - (1.0 - GLIDE_RATE) * near * (1.0 - walk)
	return TAU * hz


## The body's bank (rad about its front: the wing on the turn's inside dips) eased `dt` s toward its turn of `turn`
## rad a second (+: to its left).
static func bank_step(bank: float, turn: float, dt: float) -> float:
	return move_toward(bank, clampf(-turn * BANK_PER, -BANK, BANK), dt * BANK_EASE)


## The body's transform past its place and facing (the crowd's instance; the avatar's body node): `t` the frame-time
## clock, `ph` the gait's phase, `walk` the pace, `bank` the bat's (rad), `die_t` seconds into the death (< 0 alive),
## `flinch` the hit's (0..1, the crowd's; an avatar's node flinches itself), `rise` the rise-in.
static func body_xf(
	kind: int,
	t: float,
	ph: float,
	walk: float,
	bank: float,
	die_t: float,
	flinch: float,
	rise: float,
	calm: bool
) -> Transform3D:
	var bat := kind == WorldReader.KIND_CAVE_BAT
	var h: float = MODEL_H[kind]
	var fly := CritterBodies.BAT_FLY_M if bat else CritterBodies.MOTE_FLOAT_M
	var y := fly * rise - (1.0 - rise) * h
	var x := 0.0
	var roll := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var s := 1.0
	if die_t < 0.0:
		if bat:
			roll = bank
			pitch = -DIVE * walk
			if not calm:
				y += BEAT_BOB * sin(ph * TAU) + HOVER_M * sin(t * HOVER_RATE)
		else:
			pitch = -TILT * walk
			if not calm:
				y += BOB_M * sin(t * BOB_RATE)
				roll = SWAY * sin(t * 1.3)
				yaw = DRIFT * sin(t * 0.8)
			roll -= ph * TAU  # The spin (none with reduced motion: its clock stands)
	else:
		var d := clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0)
		if bat:  # Tumbles to the floor and lies there
			var f := minf(d / FALL_SHARE, 1.0)
			y = fly * (1.0 - f * f)
			roll = TUMBLE * smoothstep(0.0, 0.85, f)
			s = 1.0 - 0.2 * d
		else:  # A flare, a pop up and away to nothing, still spinning
			y += 0.05 * sin(d * PI)
			roll = -ph * TAU
			s = 1.0 - 0.75 * d
	if flinch != 0.0:  # The recoil: knocked back and up, squashed
		x -= 0.03 * flinch
		y += 0.015 * flinch
		pitch += 0.35 * flinch
	# The yaw, then the pitch about +Z, then the roll about +X (CritterCrowd's common frame builds the same).
	var b := Basis.from_euler(Vector3(roll, yaw, pitch), EULER_ORDER_YZX)
	if s != 1.0:
		b = b * Basis.from_scale(Vector3.ONE * s)
	if flinch != 0.0:
		var q := 0.16 * flinch
		b = b * Basis.from_scale(Vector3(1.0 + 0.5 * q, 1.0 - q, 1.0 + 0.5 * q))
	var mid := Vector3(0.0, float(MID_Y[kind]), 0.0)  # Every turn about its middle
	return Transform3D(b, Vector3(x, y, 0.0) + mid - b * mid)


## The drives (natural units, CritterModel.GRIDS): x the hit's flinch, y none, z the pace (below 0 the death, -1 its
## end), w the gait's phase.
static func drives(ph: float, walk: float, die_t: float, flinch: float) -> Vector4:
	var z := walk
	if die_t >= 0.0:
		z = -clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0)
	return Vector4(clampf(flinch, 0.0, 1.0), 0.0, z, ph)


## The eye's glow at the clock `t`: the mote's pulsing and flaring with a hit; the death's flare (the mote) and out.
static func energy(
	kind: int, t: float, rise: float, die_t: float, flinch: float, calm: bool
) -> float:
	var e := 1.5 * lerpf(0.2, 1.0, rise)
	var mote := kind == WorldReader.KIND_STAR_MOTE
	if die_t >= 0.0:
		var d := clampf(die_t / HordeAvatar.DEATH_SECONDS, 0.0, 1.0)
		return e * (1.0 - d) * ((1.0 + 3.0 * sin(d * PI)) if mote else 1.0)
	if mote:
		if not calm:
			e *= 0.7 + 0.6 * (0.5 + 0.5 * sin(t * TAU * PULSE_HZ))
		e *= 1.0 + 1.5 * clampf(flinch, 0.0, 1.0)
	return e


## Rebuilds the parts of `a` (HordeAvatar._build_model's flat pivots) into the joints. The bat: each inner wing a gait
## node at its shoulder (the beat, the fold) holding its own node (the hit's fling), the outer wing on it at its elbow
## (gait). The mote: each point turns on its own (gait); the tail's root a gait node (the wobble) holding tail_1 (the
## fling), tail_2 on it and tail_3 on tail_2 (gait). Each node's rest place is kept in the avatar's meta, with each
## point's direction out from the star's middle.
static func rig_nodes(a: HordeAvatar) -> void:
	var rest := {}
	var out := {}
	if a.kind == WorldReader.KIND_CAVE_BAT:
		for side: String in ["r", "l"]:
			if not a.parts.has("wing_" + side):
				continue
			var g := _gait_node(a, "wing_" + side)
			var tip := a.parts["wtip_" + side] as Node3D
			var at := tip.position - g.position
			tip.reparent(a.parts["wing_" + side], false)
			tip.position = at
			rest["wing_%s_g" % side] = g.position
			rest["wtip_" + side] = at
	else:
		for k in 5:
			var pname := "pt_%d" % (k + 1)
			var n := a.parts[pname] as Node3D
			rest[pname] = n.position
			var c := ((n.get_child(0) as MeshInstance3D).mesh as Mesh).get_aabb().get_center()
			out[pname] = Vector3(0.0, c.y, c.z).normalized()
		var g := _gait_node(a, "tail_1")
		rest["tail_1_g"] = g.position
		var up := a.parts["tail_1"] as Node3D
		var base := g.position
		for k in [2, 3]:
			var n := a.parts["tail_%d" % k] as Node3D
			var at := n.position - base
			base = n.position
			n.reparent(up, false)
			n.position = at
			rest["tail_%d" % k] = at
			up = n
	a.set_meta(&"flyer_rest", rest)
	a.set_meta(&"flyer_out", out)


## A gait node at part `pname`'s pivot holding it.
static func _gait_node(a: HordeAvatar, pname: String) -> Node3D:
	var n := a.parts[pname] as Node3D
	var g := Node3D.new()
	g.name = pname.to_pascal_case() + "Gait"
	g.position = n.position
	a.model.add_child(g)
	n.reparent(g, false)
	n.position = Vector3.ZERO
	a.parts[pname + "_g"] = g
	return g


## The joints (HordeVat.joint_spec) past the body, a parent before its children.
static func joints(a: HordeAvatar) -> Array:
	var p := a.parts
	var g := VatBake.GRID_GAIT
	var s := VatBake.GRID_STANCE
	if a.kind == WorldReader.KIND_CAVE_BAT:
		var out: Array = []
		for side: String in ["r", "l"]:
			out.append_array(
				[[p["wing_%s_g" % side], g], [p["wing_" + side], s], [p["wtip_" + side], g]]
			)
		return out
	var out: Array = []
	for k in 5:
		out.append([p["pt_%d" % (k + 1)], g])
	out.append_array([[p["tail_1_g"], g], [p["tail_1"], s], [p["tail_2"], g], [p["tail_3"], g]])
	return out


## Poses the parts of `a` at drives `d` (natural units): the live pose and the VAT bake both pose through here. Each
## node's transform is set whole from its own grid's drives.
static func pose_parts(a: HordeAvatar, d: Vector4) -> void:
	var p := a.parts
	var rest: Dictionary = a.get_meta(&"flyer_rest")
	var walk := maxf(d.z, 0.0)
	var dead := clampf(-d.z, 0.0, 1.0)
	var live := 1.0 - dead
	var w := fposmod(d.w, 1.0)
	if a.kind == WorldReader.KIND_CAVE_BAT:
		var amp := lerpf(BEAT_IDLE, BEAT_FLY, walk)
		var sh := (amp * cos(w * TAU) + BEAT_BIAS) * live + FOLD.x * dead
		var el := (TIP_BEAT * amp * cos((w - TIP_LAG) * TAU)) * live + FOLD.y * dead
		var sw := SWEEP * sin(w * TAU) * live
		for side: String in ["r", "l"]:
			var sg := 1.0 if side == "r" else -1.0
			(p["wing_%s_g" % side] as Node3D).transform = Transform3D(
				Basis(Vector3.UP, sg * sw) * Basis(Vector3.RIGHT, -sg * sh),
				rest["wing_%s_g" % side]
			)
			(p["wing_" + side] as Node3D).transform = Transform3D(
				Basis(Vector3.RIGHT, -sg * FLING * d.x), Vector3.ZERO
			)
			(p["wtip_" + side] as Node3D).transform = Transform3D(
				Basis(Vector3.RIGHT, -sg * el), rest["wtip_" + side]
			)
		return
	var out: Dictionary = a.get_meta(&"flyer_out")
	var spin := Basis(Vector3.RIGHT, -DEATH_SPIN * dead)
	for k in 5:
		var pname := "pt_%d" % (k + 1)
		var o: Vector3 = out[pname]
		(p[pname] as Node3D).transform = Transform3D(
			spin * Basis(o.cross(Vector3.RIGHT).normalized(), 0.6 * dead),
			rest[pname] + spin * o * BREAK_M * dead
		)
	var sway := TAIL_SWAY * live
	(p["tail_1_g"] as Node3D).transform = Transform3D(
		(
			Basis(Vector3.RIGHT, w * TAU)  # Back against the body's spin
			* Basis(Vector3.UP, sway * sin(w * TAU * TAIL_WOBBLES))
			* Basis(Vector3.BACK, TAIL_STREAM * walk)
		),
		rest["tail_1_g"] + Vector3(-0.6, -1.0, -0.4) * BREAK_M * 0.5 * dead
	)
	(p["tail_1"] as Node3D).transform = Transform3D(Basis(Vector3.BACK, FLING * d.x), Vector3.ZERO)
	for k in [2, 3]:
		var at: Vector3 = rest["tail_%d" % k]
		(p["tail_%d" % k] as Node3D).transform = Transform3D(
			Basis(Vector3.UP, sway * 1.3 * sin((w * TAIL_WOBBLES - TAIL_LAG * (k - 1)) * TAU)),
			at + at.normalized() * BREAK_M * 0.6 * dead
		)


## The body's place and the parts' drives of `a` this frame (HordeAvatar._pose_model through CritterModel.place; the
## crowd reckons the same): the body node's transform (a VAT avatar's offset), the parts and the eye's glow. The bat's
## bank follows how fast its holder turns.
static func place(a: HordeAvatar) -> void:
	var calm := ViewPrefs.reduced_motion
	var ph := fposmod(a._walk_t / TAU, 1.0)
	var bank := 0.0
	if a.kind == WorldReader.KIND_CAVE_BAT:
		var f := a.get_parent() as Node3D
		var yaw := f.rotation.y if f != null else 0.0
		var dt: float = a._t - float(a.get_meta(&"flyer_t", a._t))
		var turn := 0.0
		if dt > 0.0:
			turn = angle_difference(float(a.get_meta(&"flyer_yaw", yaw)), yaw) / dt
		bank = bank_step(
			float(a.get_meta(&"flyer_bank", 0.0)), 0.0 if a._die_t >= 0.0 else turn, dt
		)
		a.set_meta(&"flyer_bank", bank)
		a.set_meta(&"flyer_yaw", yaw)
		a.set_meta(&"flyer_t", a._t)
	var xf := body_xf(a.kind, a._t, ph, a._walk, bank, a._die_t, 0.0, a._rise, calm)
	if a.vat:
		a._vat_body = xf
	else:
		a.body.transform = xf
	var k := maxf(a.flinch_amount(), 0.0)
	a._pose_parts(drives(ph, a._walk, a._die_t, k))
	a._set_glow(energy(a.kind, a._t, a._rise, a._die_t, k, calm))
