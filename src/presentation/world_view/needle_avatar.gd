class_name NeedleAvatar
extends AvatarBase
## The Needle (owner, v0.2.0 L17; docs/art/enemies_visual_reference.png, middle row): a walking turret. A red
## faceted cube body (each face a shallow pyramid) with grey octagonal pods on its flanks, a dark collar on its
## front with a red slit eye on each side, a square grey cannon barrel pointing forward, and four grey mechanical
## legs (hip hub, thigh, knee joint, steep shin, flat foot) splayed to the corners. Presentation only (EI-07):
## sync() reads the sim through WorldReader once per tick, advance() animates in frame time, and nothing here feeds
## back into the sim. The legs are solved by two-bone IK toward foot targets on the ground, so the feet stay planted
## while the body bobs, crouches or recoils. +X is the front (the cannon) and +Z the right; ActorViews parents this
## under the actor's facing node.
## Its burst lanes are no longer drawn on the ground; the windup reads from the body
## (AvatarBase "tell"): the cube squats and tips its nose down the aim as the windup's progress climbs, the eyes and
## the muzzle charge up and flash just before the burst. The aim is the facing (the sim's, held through the windup).

## The cube body: edge length, centre height, edge bevel and how far each face's centre stands out (the facets).
const BODY := 0.4
const BODY_Y := 0.56
const BODY_BEVEL := 0.018
const BODY_BULGE := 0.014
## The barrel's axis height; the sim spawns the Needle's bolts at the core height (SimPlane.CORE_HEIGHT), ~0.52 m
## ahead of the centre, which is where the muzzle sits.
const BARREL_Y := 0.54
const BARREL_LEN := 0.4
const BARREL_W := 0.1
## Model height (top of the cube), for the health bar.
const HEIGHT := BODY_Y + BODY * 0.5 + BODY_BULGE
## Leg geometry: hips under the cube's corners, feet on the ground further out (front-left, front-right,
## back-right, back-left; diagonal pairs step together).
const HIP := Vector3(0.1, 0.33, 0.12)
const FOOT := Vector3(0.28, 0.0, 0.36)
const THIGH_LEN := 0.22
const SHIN_LEN := 0.26
## Height of the ankle joint above the ground (the foot block's height plus a little).
const ANKLE_H := 0.05
## Gait (starting values): the move speed the gait is tuned for (data/enemies/needle.tres), the foot travel per step
## and how high a swinging foot lifts.
const WALK_SPEED := 3.2
const STRIDE := 0.3
const LIFT := 0.07
## The Needle's attack timing in sim ticks (data/enemies/needle.tres: 0.5 s telegraph, a 3-shot burst 0.1 s
## apart). Cosmetic only: they pace the glow and the recoil kicks, never an outcome.
const WINDUP_TICKS := 30
const BURST_GAP_TICKS := 6
const BURST_COUNT := 3
## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 20.0

## Colours sampled from the reference sheet (the lit faces), as albedo under the game's light. the cube
## (body), the flank pods (trim), the barrel and legs (grey) and the eye slits (eye) come from EnemyPalettes.
const KIND := WorldReader.KIND_NEEDLE
const GREY_LIGHT := Color("#6D625C")
const DARK := Color("#3A383C")
const HOLE := Color("#141417")
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's shift and height, its
## lean (a turn's rotation vector, x and z), its pitch, the barrel's slide, each leg's yaw and its thigh and shin
## angles (LEG0 + 3 k + 0 / 1 / 2: loops, the IK may turn them anywhere), and the muzzle's glow (sent as it is: the
## bore's accent reads it).
const AX := 0
const AY := 1
const LX := 2
const LZ := 3
const PITCH := 4
const BARREL := 5
const LEG0 := 6
const MUZZLE := 18
const LEG_SAMPLES := 256
const VAT_DRIVES := [
	[-0.1, 0.01, false],
	[-0.42, 0.06, false],
	[-0.075, 0.075, false],
	[-0.075, 0.075, false],
	[-0.33, 0.2, false],
	[0.16, 0.27, false],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[-PI, PI, true],
	[0.0, 0.0, false],
]

## Parts, read by tests and by ActorViews (flash materials).
var body: Node3D
var barrel: Node3D
var legs: Array[Node3D] = []
var feet: Array[Node3D] = []
## True (set before setup(), ActorViews from
## ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup() builds no piece.
var vat := false
var kind := KIND

var _eye_mat := StandardMaterial3D.new()
var _hole_mat := StandardMaterial3D.new()
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _ankles: Array[Node3D] = []
var _hips: Array[Vector3] = []
var _rests: Array[Vector3] = []
# Sim state from the last sync.
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _shots := 0
# Smoothed animation state.
var _vel_s := Vector3.ZERO
var _phase := 0.0
var _walk := 0.0
var _rise := 0.0
var _brace := 0.0
var _charge := 0.0
var _heat := 0.0
var _kick := 0.0
# The windup's progress (0..1) from the last sync; -1 when the caller gave none.
var _tell_p := -1.0
var _vd := PackedFloat32Array()


## Builds the model.
func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	if vat:  # The crowd draws the body; the legs' hips and rest spots only
		for k in 4:
			_leg_spots(k)
		_pose(0.0)
		return
	body = Node3D.new()
	add_child(body)
	var cube := _chamfer_box(Vector3.ONE * BODY, BODY_BEVEL, BODY_BULGE)
	var red := EnemyPalettes.color(KIND, &"body")
	_piece(body, cube, Vector3(0, BODY_Y, 0), red)
	# The chassis under the cube, which the hips hang from.
	var chassis := _chamfer_box(Vector3(0.3, 0.07, 0.3), 0.015)
	_piece(body, chassis, Vector3(0, HIP.y + 0.02, 0), DARK)
	# The flank pods: big bevels make them octagons from the side; their faces carry the same shallow facets.
	var pod := _chamfer_box(Vector3(0.24, 0.26, 0.1), 0.06, 0.012)
	for side in [-1.0, 1.0]:
		var at := Vector3(-0.03, 0.46, side * (BODY * 0.5 + 0.045))
		_piece(body, pod, at, EnemyPalettes.color(KIND, &"trim"))
	# The collar on the front face that the barrel comes out of, with a red slit eye on each flank.
	var collar := _chamfer_box(Vector3(0.12, 0.25, 0.2), 0.02)
	var collar_x := BODY * 0.5 + 0.03
	_piece(body, collar, Vector3(collar_x, BARREL_Y - 0.01, 0), DARK)
	var glow := EnemyPalettes.color(KIND, &"eye")
	_eye_mat.albedo_color = glow
	_eye_mat.emission_enabled = true
	_eye_mat.emission = glow
	_eye_mat.emission_energy_multiplier = 2.0
	var slit := BoxMesh.new()
	slit.size = Vector3(0.035, 0.11, 0.01)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = slit
		eye.material_override = _eye_mat
		eye.position = Vector3(collar_x + 0.015, BARREL_Y, side * 0.1)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(eye)
	_build_barrel()
	for k in 4:
		_build_leg(k)
	_pose(0.0)


## Reads the Needle's state after a sim tick.
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"windup": windup_progress(reader, i),
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this); "windup" (0..1, optional) is the
## windup's progress (without it the glow paces itself on WINDUP_TICKS).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	var state: int = s["state"]
	_tell_p = clampf(float(s.get("windup", -1.0)), -1.0, 1.0)
	_track_motion(tick, pos, TELEPORT_SPEED)
	if _fresh or state != _state:
		_state = state
		_state_tick = tick
		_shots = 0
	_ticks_in = tick - _state_tick
	# A shot leaves the muzzle at the start of the burst and every gap after it: kick the barrel back.
	if _state == WorldReader.STATE_ACTIVE and _shots < BURST_COUNT:
		if _ticks_in >= _shots * BURST_GAP_TICKS:
			_shots += 1
			_kick = 1.0
			_heat = 1.0
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose(0.0)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or (body == null and not vat):
		return
	_t += dt
	_vel_s = _vel_s.lerp(Vector3(_vel.x, 0, -_vel.y), _rate(12.0, dt))
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.8))
	var bracing := _state == WorldReader.STATE_WINDUP or _state == WorldReader.STATE_ACTIVE
	_brace = lerpf(_brace, 1.0 if bracing else 0.0, _rate(10.0 if bracing else 4.0, dt))
	var charge_target := 0.0
	if _state == WorldReader.STATE_WINDUP:
		charge_target = clampf(float(_ticks_in) / WINDUP_TICKS, 0.0, 1.0)
		if _tell_p >= 0.0:
			charge_target = _tell_p
	elif _state == WorldReader.STATE_ACTIVE:
		charge_target = 1.0
	_charge = lerpf(_charge, charge_target, _rate(14.0 if charge_target > _charge else 3.0, dt))
	_kick = move_toward(_kick, 0.0, dt * 7.0)
	_heat = move_toward(_heat, 0.0, dt * 1.6)
	_pose(dt)


## The barrel's recoil: how far it has slid back into the collar, in metres (0 at rest).
func barrel_recoil() -> float:
	return -_vd[BARREL] + (BODY * 0.5 + 0.06)


## The eyes' current glow (emission energy).
func eye_energy() -> float:
	return _eye_mat.emission_energy_multiplier


## The muzzle's current glow (emission energy; 0 when cold).
func muzzle_energy() -> float:
	return _hole_mat.emission_energy_multiplier


## The feet's positions in this node's frame.
func foot_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in feet:
		out.append(to_local(f.global_position) if is_inside_tree() else Vector3.ZERO)
	return out


## The windup's progress the tell reads (the sim's, else paced on WINDUP_TICKS); 0 outside the windup.
func tell_progress() -> float:
	if _state != WorldReader.STATE_WINDUP:
		return 0.0
	return _tell_p if _tell_p >= 0.0 else clampf(float(_ticks_in) / WINDUP_TICKS, 0.0, 1.0)


## 0..1 how deep the windup crouch is.
func crouch_amount() -> float:
	return tell_crouch(tell_progress()) if _state == WorldReader.STATE_WINDUP else 0.0


## Recoil curve: a sharp kick back, then an eased return.
func _kick_curve() -> float:
	return _kick * _kick * (3.0 - 2.0 * _kick)


func _pose(dt: float) -> void:
	# Movement in this node's frame (the facing node turns it; +X is the front).
	var v := _vel_s
	if is_inside_tree():
		v = global_basis.inverse() * _vel_s
	v.y = 0.0
	var speed := v.length()
	var busy := _state != WorldReader.STATE_MOVE
	var walk_target := 0.0 if busy else clampf(speed / WALK_SPEED, 0.0, 1.0)
	_walk = lerpf(_walk, walk_target, _rate(10.0, dt))
	var move_dir := Vector3.RIGHT if speed < 0.01 else v / speed
	# One gait cycle per two strides: in its stance half a foot slides back one stride as the body moves over it.
	_phase = fposmod(_phase + dt * speed / (2.0 * STRIDE) * _walk, 1.0)
	var kick := _kick_curve()
	# The body: an idle hum, a bob on each step, the crouch of the brace, the rise-in, the recoil.
	var hum := sin(_t * 9.0) * 0.003 + sin(_t * 1.7) * 0.01 * (1.0 - _walk)
	var bob := cos(_phase * TAU * 2.0) * 0.012 * _walk
	# The windup squats the cube lower and tips its nose down along the aim (no ground lines any more).
	var calm := ViewPrefs.reduced_motion
	var crouch := crouch_amount()
	var y := hum + bob - _brace * 0.06 - crouch * 0.06 - (1.0 - _rise) * 0.24 + kick * 0.01
	# The pose's numbers first (the VAT drives), then the nodes from them (the old path).
	# Lean into the walk (a turn about the axis across the walk, as its rotation vector's x and z); brace leans back a
	# little; each shot rocks the nose up.
	var lean := Vector3.ZERO
	if _walk > 0.001:
		lean = Vector3.UP.cross(move_dir).normalized() * 0.07 * _walk
	_vd[LX] = lean.x
	_vd[LZ] = lean.z
	_vd[PITCH] = _brace * 0.05 - crouch * 0.1 + kick * 0.12 - (1.0 - _rise) * 0.2
	_vd[AX] = -kick * 0.035 - _brace * 0.015 - crouch * 0.04
	_vd[AY] = y
	_vd[BARREL] = BODY * 0.5 + 0.06 - kick * 0.09
	var bxf := body_xf(_vd[AX], _vd[AY], _vd[LX], _vd[LZ], _vd[PITCH])
	# Glow: the eyes and the muzzle brighten through the wind-up, flare on each shot, cool down after.
	var cool := 1.0 if _state == WorldReader.STATE_RECOVER else 0.0
	var pulse := 0.0 if calm else 0.15 * sin(_t * 3.0)
	var winding := _state == WorldReader.STATE_WINDUP
	var tell := tell_glow(tell_progress(), _t, calm) if winding else 1.0
	_eye_mat.emission_energy_multiplier = (
		((2.0 + pulse + _charge * 4.0) * tell + kick * 3.0 - cool * 0.8) * lerpf(0.2, 1.0, _rise)
	)
	_hole_mat.emission_energy_multiplier = maxf(_charge * 3.5 * tell, _heat * 2.0) + kick * 6.0
	_vd[MUZZLE] = _hole_mat.emission_energy_multiplier
	if not vat:
		body.transform = bxf
		barrel.position.x = _vd[BARREL]
	# The legs: each foot steps around its rest spot, then IK from the hip (on the moving body) to the foot.
	for k in _hips.size():
		var p := fposmod(_phase + (0.5 if k % 2 == 1 else 0.0), 1.0)
		var u := 1.0 - 4.0 * p if p < 0.5 else -1.0 + 4.0 * (p - 0.5)
		var lift := 0.0 if p < 0.5 else sin((p - 0.5) * TAU) * LIFT
		var rest := _rests[k]
		var foot := Vector3(rest.x, 0.0, rest.z) * lerpf(0.55, 1.0, _rise)
		foot += move_dir * u * STRIDE * 0.5 * _walk
		foot.y = lift * _walk
		var hip := bxf * _hips[k]
		var ik := leg_ik(hip, foot)
		for a in 3:
			_vd[LEG0 + 3 * k + a] = ik[a]
		if not vat:
			_place_leg(k, hip, ik)


## The body's transform from its numbers: shifted by (ax, ay), pivoting about the hips, so a pitch
## rocks the cube instead of swinging it about the ground; its turn is the lean (rotation vector (lx, 0, lz)) after
## the pitch about Z.
static func body_xf(ax: float, ay: float, lx: float, lz: float, pitch: float) -> Transform3D:
	var pivot := Vector3(0, HIP.y, 0)
	return (
		Transform3D(lean_basis(lx, lz), Vector3(ax, ay, 0) + pivot)
		* Transform3D(Basis(Vector3.BACK, pitch), Vector3.ZERO)
		* Transform3D(Basis.IDENTITY, -pivot)
	)


## The lean's turn from its rotation vector (lx, 0, lz) (none at zero).
static func lean_basis(lx: float, lz: float) -> Basis:
	var r := Vector3(lx, 0, lz)
	var a := r.length()
	return Basis(r / a, a) if a > 1e-9 else Basis.IDENTITY


## Two-bone IK from the hip to the foot (knee up and out like the reference's): the leg's yaw toward the foot and the
## thigh's and shin's angles (the numbers only; _place_leg writes them).
static func leg_ik(hip: Vector3, foot: Vector3) -> Vector3:
	var flat := Vector2(foot.x - hip.x, foot.z - hip.z)
	var yaw := atan2(-flat.y, flat.x)
	var d := flat.length()
	var dz := foot.y + ANKLE_H - hip.y
	var r := clampf(Vector2(d, dz).length(), 0.05, THIGH_LEN + SHIN_LEN - 0.001)
	var base := atan2(dz, d)
	var cos_a := (THIGH_LEN * THIGH_LEN + r * r - SHIN_LEN * SHIN_LEN) / (2.0 * THIGH_LEN * r)
	var a1 := base + acos(clampf(cos_a, -1.0, 1.0))
	var knee := Vector2(cos(a1), sin(a1)) * THIGH_LEN
	var a2 := atan2(dz - knee.y, d - knee.x)
	return Vector3(yaw, a1, a2)


## Places leg k's root at the hip, turns it toward the foot and bends thigh, knee and ankle by `ik` (leg_ik's).
func _place_leg(k: int, hip: Vector3, ik: Vector3) -> void:
	legs[k].position = hip
	legs[k].rotation = Vector3(0, ik.x, 0)
	_thighs[k].rotation = Vector3(0, 0, ik.y)
	_knees[k].rotation = Vector3(0, 0, ik.z - ik.y)
	_ankles[k].rotation = Vector3(0, 0, -ik.z)


# --- v0.10.5 W3-V4c: the VAT rig (SoloVat) -----------------------------------------------------------------------


## The Needle stands on its feet: nothing lifts the whole body.
func vat_lift() -> float:
	return 0.0


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The eyes' glow (the instance's; the muzzle's is the MUZZLE drive).
func glow_energy() -> float:
	return _eye_mat.emission_energy_multiplier


## The body: its shift and height, the lean about the hips' pivot, the pitch (body_xf's parts); the barrel slides on
## it. A leg's root sits at the body's hip with no turn of the body's (the body's chain, the hip, then the pitch and
## the lean undone), turned by its yaw; the thigh turns by a1, the knee by a2 - a1 (-a1 then a2), the ankle by -a2.
func vat_rig() -> Dictionary:
	var pivot := Vector3(0, HIP.y, 0)
	var z := Vector3.BACK
	var j: Array = [
		[AX, -1, null, SoloVat.slide(Vector3.RIGHT)],
		[AY, 0, null, SoloVat.slide(Vector3.UP)],
		[2, 1, null, _lean_joint.bind(pivot, false)],
		[3, 2, body, SoloVat.turn(z, 1.0, Transform3D.IDENTITY, SoloVat.at(-pivot))],
		[4, 3, barrel, SoloVat.slide(Vector3.RIGHT, Vector3(0, BARREL_Y, 0))],
	]
	for k in legs.size():
		var g := 5 + 3 * k
		j.append([3, 3, null, SoloVat.turn(z, -1.0, SoloVat.at(_hips[k]))])
		j.append([2, j.size() - 1, null, _lean_joint.bind(Vector3.ZERO, true)])
		j.append([g, j.size() - 1, legs[k], SoloVat.turn(Vector3.UP)])
		j.append([g + 1, j.size() - 1, _thighs[k], SoloVat.turn(z)])
		j.append(
			[g + 1, j.size() - 1, null, SoloVat.turn(z, -1.0, SoloVat.at(Vector3(THIGH_LEN, 0, 0)))]
		)
		j.append([g + 2, j.size() - 1, _knees[k], SoloVat.turn(z)])
		j.append(
			[
				g + 2,
				j.size() - 1,
				_ankles[k],
				SoloVat.turn(z, -1.0, SoloVat.at(Vector3(SHIN_LEN, 0, 0)))
			]
		)
	# Grids: 0 AX, 1 AY, 2 the lean (LX x LZ), 3 PITCH, 4 BARREL, then per leg its yaw, a1, a2.
	var grids: Array = [[[AX, 2]], [[AY, 2]], [[LX, 9], [LZ, 9]], [[PITCH, 33]], [[BARREL, 2]]]
	for d in range(LEG0, MUZZLE):
		grids.append([[d, LEG_SAMPLES]])
	return SoloVat.rig("needle", VAT_DRIVES, grids, j, false)


## The lean's joint at its grid's values (lx, lz): the turn at the pivot, or (`inverse`) the turn undone.
static func _lean_joint(v: Array, at: Vector3, inverse: bool) -> Transform3D:
	var b := lean_basis(v[0], v[1])
	return Transform3D(b.inverse() if inverse else b, at)


func _build_barrel() -> void:
	barrel = Node3D.new()
	barrel.position = Vector3(BODY * 0.5 + 0.06, BARREL_Y, 0)
	body.add_child(barrel)
	var tube := _chamfer_box(Vector3(BARREL_LEN, BARREL_W, BARREL_W), 0.012)
	_piece(barrel, tube, Vector3(BARREL_LEN * 0.5, 0, 0), EnemyPalettes.color(KIND, &"grey"))
	# A slightly wider sleeve at the muzzle, as on the sheet's side view.
	var sleeve := _chamfer_box(Vector3(0.07, BARREL_W + 0.012, BARREL_W + 0.012), 0.012)
	_piece(barrel, sleeve, Vector3(BARREL_LEN - 0.035, 0, 0), EnemyPalettes.color(KIND, &"grey"))
	# The square bore: dark when cold; it glows the hostile-shot colour while charging and firing.
	var shot := ThemePalette.color(&"proj_hostile")
	_hole_mat.albedo_color = HOLE
	_hole_mat.emission_enabled = true
	_hole_mat.emission = shot
	_hole_mat.emission_energy_multiplier = 0.0
	_hole_mat.set_meta(SoloVat.GLOW, MUZZLE + 1)  # A VAT Needle's bore glows at its MUZZLE drive
	var hole := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.01, BARREL_W * 0.72, BARREL_W * 0.72)
	hole.mesh = hb
	hole.material_override = _hole_mat
	hole.position = Vector3(BARREL_LEN + 0.001, 0, 0)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	barrel.add_child(hole)


## One leg: a root at the hip (turned toward the foot), the hip hub, the thigh, the knee joint, the shin, and the
## flat foot under an ankle that keeps it level.
func _build_leg(k: int) -> void:
	_leg_spots(k)
	var root := Node3D.new()
	add_child(root)
	legs.append(root)
	var hub := _prism(0.05, 0.08, 8)
	_piece(root, hub, Vector3.ZERO, DARK)
	var thigh := Node3D.new()
	root.add_child(thigh)
	_thighs.append(thigh)
	var tm := _chamfer_box(Vector3(THIGH_LEN, 0.075, 0.07), 0.014)
	_piece(thigh, tm, Vector3(THIGH_LEN * 0.5, 0, 0), EnemyPalettes.color(KIND, &"grey"))
	var knee := Node3D.new()
	knee.position.x = THIGH_LEN
	thigh.add_child(knee)
	_knees.append(knee)
	_piece(knee, _prism(0.042, 0.1, 8), Vector3.ZERO, GREY_LIGHT)
	var sm := _chamfer_box(Vector3(SHIN_LEN, 0.085, 0.08), 0.016)
	_piece(knee, sm, Vector3(SHIN_LEN * 0.5, 0, 0), EnemyPalettes.color(KIND, &"grey"))
	var ankle := Node3D.new()
	ankle.position.x = SHIN_LEN
	knee.add_child(ankle)
	_ankles.append(ankle)
	_piece(ankle, _prism(0.03, 0.09, 6), Vector3.ZERO, DARK)
	var fm := _chamfer_box(Vector3(0.13, 0.045, 0.1), 0.012)
	var foot := Node3D.new()
	foot.position = Vector3(0.015, -ANKLE_H + 0.0225, 0)
	ankle.add_child(foot)
	_piece(foot, fm, Vector3.ZERO, GREY_LIGHT)
	feet.append(foot)


## Leg k's hip (under the cube's corner) and its foot's rest spot (front-left, front-right, back-right, back-left).
func _leg_spots(k: int) -> void:
	var sx := 1.0 if k < 2 else -1.0
	var sz := 1.0 if k == 1 or k == 2 else -1.0
	_hips.append(Vector3(HIP.x * sx, HIP.y, HIP.z * sz))
	_rests.append(Vector3(FOOT.x * sx, 0.0, FOOT.z * sz))


func _piece(parent: Node3D, mesh: Mesh, at: Vector3, c: Color) -> MeshInstance3D:
	return _body_piece(parent, mesh, at, c)


## A box with bevelled edges and cut corners, centred on the origin, flat-shaded. With `bulge` each of the six faces
## is a shallow pyramid whose centre stands that far out, so its four triangles catch the light differently.
static func _chamfer_box(size: Vector3, bevel: float, bulge: float = 0.0) -> ArrayMesh:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.95)
	var tris := []
	# P(s, a): the corner `s` (signs per axis) pulled in by the bevel on every axis but a.
	var pt := func(s: Vector3, a: int) -> Vector3:
		var p := Vector3.ZERO
		for c in 3:
			p[c] = s[c] * (h[c] if c == a else h[c] - b)
		return p
	for a in 3:
		var c := (a + 1) % 3
		var d := (a + 2) % 3
		for sa in [-1.0, 1.0]:
			# The face on axis a.
			var quad := []
			for sc_sd in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3.ZERO
				s[a] = sa
				s[c] = sc_sd.x
				s[d] = sc_sd.y
				quad.append(pt.call(s, a))
			if bulge > 0.0:
				var mid := Vector3.ZERO
				mid[a] = sa * (h[a] + bulge)
				for q in 4:
					tris.append([quad[q], quad[(q + 1) % 4], mid])
			else:
				tris.append([quad[0], quad[1], quad[2]])
				tris.append([quad[0], quad[2], quad[3]])
			# The bevel strips between this face and the face on axis c (each pair once).
			for sc in [-1.0, 1.0]:
				var e := []
				for sd in [-1.0, 1.0]:
					var s := Vector3.ZERO
					s[a] = sa
					s[c] = sc
					s[d] = sd
					e.append(pt.call(s, a))
					e.append(pt.call(s, c))
				tris.append([e[0], e[1], e[3]])
				tris.append([e[0], e[3], e[2]])
	# The corner triangles.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				tris.append([pt.call(s, 0), pt.call(s, 1), pt.call(s, 2)])
	return _mesh_from(tris)


## A flat-shaded prism along Z (a joint pin): `sides` sides of circumradius r, `length` long, centred.
static func _prism(r: float, length: float, sides: int) -> ArrayMesh:
	var tris := []
	var z := length * 0.5
	for k in sides:
		var a0 := TAU * (k + 0.5) / sides
		var a1 := TAU * (k + 1.5) / sides
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		var f := Vector3(0, 0, z)
		tris.append([p0 - f, p1 - f, p1 + f])
		tris.append([p0 - f, p1 + f, p0 + f])
		tris.append([-f, p0 - f, p1 - f])
		tris.append([f, p1 + f, p0 + f])
	return _mesh_from(tris)


## Flat-shaded triangles of a convex solid around the origin: each faces away from it (Godot's front faces wind
## clockwise).
static func _mesh_from(tris: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		if n.dot(a + b + c) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
