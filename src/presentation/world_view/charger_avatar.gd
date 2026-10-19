class_name ChargerAvatar
extends AvatarBase
## The Charger (v0.2.0 L17; docs/art/enemies_visual_reference.png, first creature): a long red hood with a ridged,
## faceted roof that peaks over a dark shield-shaped face with a glowing red gem visor, a back flap that juts out
## behind, and a charcoal body under it, carried spider-like on four grey segmented legs: a big front pair that
## arches out and curls bone-coloured talons in and forward, and a smaller back pair braced behind.
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time, and nothing here feeds back into the sim. ActorViews puts it under the actor's facing node, so +X is the
## front and +Z the right; it never turns itself.
## v0.8.0 TG (owner O4, Q3): no lane on the ground any more; the windup reads from the body (AvatarBase "tell"): it
## sinks into a crouch and draws back as the windup's progress climbs, the visor brightens and flashes just before
## the charge, and the body holds the locked facing (the sim's) the whole time.
## v0.8.0 P1 (owner O26): the talons rise and hold by STRIKE_RAISE_BY of the windup's progress (AvatarBase.strike_raise,
## the sim's progress, not a timer), then the charge's start (the sim's ACTIVE) throws them out ahead in STRIKE_SNAP_S
## (strike_swing), held through the run, and they come back after it.

## The legs, right side (the left mirrors it): the hip, then per segment (femur, tibia, talon) its length, its yaw
## (0 is the front, negative turns toward +Z, the right) and its pitch (0 is level, negative points down). Each
## segment points its own way, so a front leg can arch out to the side while its talon hooks forward and in.
const FRONT_HIP := Vector3(0.06, 0.56, 0.17)
const FRONT_LEN := [0.27, 0.15, 0.245]
const FRONT_YAW := [-1.0, -0.6, 1.15]
const FRONT_PITCH := [-0.75, -1.1, -0.93]
const BACK_HIP := Vector3(-0.12, 0.42, 0.11)
const BACK_LEN := [0.12, 0.2, 0.17]
const BACK_YAW := [-2.2, -2.6, -2.8]
const BACK_PITCH := [-0.5, -1.25, -1.2]
## The talon mesh's tip sits below its axis: (length, -TALON_DROP * length).
const TALON_DROP := 0.22
## The ridge's highest point (the back corner): the model's height, for the health bar.
const HEIGHT := 0.86
## Movement the scuttle is tuned for: metres per full four-leg cycle, and the cycle-rate cap (a charge is 15 m/s).
const STRIDE := 0.55
const MAX_CYCLES := 7.0
const WALK_SPEED := 3.0
## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 40.0
## The rise out of the ground when the spawn ends, in seconds.
const RISE_TIME := 0.35
const OUTLINE_M := 0.018

## Colours sampled from the reference sheet (its lit and shaded tones, as albedo under the game's light). v0.8.0 EC: the
## hood (body), the back flap (trim), the front legs (grey) and the visor (eye) come from EnemyPalettes per kind.
const FACE_COLOR := Color("#16181D")
const CORE_COLOR := Color("#24272D")
## The back legs sit in the body's shadow on the sheet: a darker grey.
const BACK_LEG_COLOR := Color("#4A4446")
const JOINT_COLOR := Color("#34363C")
const TALON_COLOR := Color("#E6B596")
const VISOR_ENERGY := 1.4

## v0.8.0 FV (owner O87, the horde lag): the body and leg meshes (geometry only: every colour is a per-instance
## material), built once and shared by every Charger and Hatchling, as the Warden's are. A horde respawning a few
## Chargers a second rebuilt about 20 SurfaceTool meshes for each.
static var _meshes := {}

## Parts, read by tests and by ActorViews (flash materials; the visor's glow is its own).
## The kind this model draws (the Charger, or the Brood Mother's Hatchling at two thirds of the size): its colours.
var kind := WorldReader.KIND_CHARGER
var body: Node3D
var visor: MeshInstance3D
## Hip nodes, front right, front left, back right, back left.
var legs: Array[Node3D] = []

var _visor_mat := StandardMaterial3D.new()
# Everything hangs from this node, which sinks into the ground before the rise; this node itself is never moved.
var _model := Node3D.new()
var _femurs: Array[Node3D] = []
var _tibias: Array[Node3D] = []
var _talons: Array[Node3D] = []
# Sim state from the last sync.
var _state := WorldReader.STATE_MOVE
# Smoothed animation state.
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _wind := 0.0
var _lunge := 0.0
var _daze := 0.0
var _rise := 1.0
# v0.8.0 TG: the windup's progress (0..1) from the last sync.
var _tell_p := 0.0
# v0.8.0 HV: the body's position this pose (the legs' hips follow it) and the visor energy last written.
var _body_pos := Vector3.ZERO
var _visor_e := VISOR_ENERGY


## Builds the model. technique "xray" adds an enemy-coloured silhouette twin to the hood and the body, as
## ActorViews does for its body pieces; the thin legs have none. `p_kind` picks the colours (EnemyPalettes).
func setup(
	outline_color: Color, technique: StringName = &"xray", p_kind := WorldReader.KIND_CHARGER
) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	var team := ThemePalette.color(&"enemy_body")
	add_child(_model)
	body = Node3D.new()
	_model.add_child(body)
	var shell := [
		[_hood_mesh(), EnemyPalettes.color(kind, &"body")],
		[_flap_mesh(), EnemyPalettes.color(kind, &"trim")],
		[_core_mesh(), CORE_COLOR]
	]
	_piece(body, shell, outline_color, team, technique)
	var face := MeshInstance3D.new()
	face.mesh = _face_mesh()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = FACE_COLOR
	fm.roughness = 1.0
	write_stencil(fm)
	face.material_override = fm
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(face)
	visor = MeshInstance3D.new()
	visor.mesh = _visor_mesh()
	var eye := EnemyPalettes.color(kind, &"eye")
	_visor_mat.albedo_color = eye
	_visor_mat.emission_enabled = true
	_visor_mat.emission = eye
	_visor_mat.emission_energy_multiplier = VISOR_ENERGY
	write_stencil(_visor_mat)
	visor.material_override = _visor_mat
	visor.position = Vector3(0.155, 0.51, 0)
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visor)
	for side in [1.0, -1.0]:
		_build_leg(FRONT_HIP, FRONT_LEN, side, true, outline_color, team)
	for side in [1.0, -1.0]:
		_build_leg(BACK_HIP, BACK_LEN, side, false, outline_color, team)
	_pose()


## Reads the actor's state after a sim tick.
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
## windup's progress.
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	_tell_p = clampf(float(s.get("windup", 0.0)), 0.0, 1.0)
	_track_motion(tick, pos, TELEPORT_SPEED)
	var prev := _state
	_state = s["state"]
	strike_note(_state)  # v0.8.0 P1: the charge's start throws the talons out
	if _state == WorldReader.STATE_SPAWN:
		_rise = 0.0
	elif _fresh and prev != WorldReader.STATE_SPAWN:
		_rise = 1.0
	_fresh = false


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	_speed = lerpf(_speed, _vel.length(), _rate(12.0, dt))
	var st := _state
	strike_advance(dt)
	_wind = strike_raised(
		st == WorldReader.STATE_WINDUP, _tell_p, move_toward(_wind, 0.0, dt * 6.0)
	)
	_lunge = strike_swing()
	_daze = move_toward(_daze, 1.0 if st == WorldReader.STATE_RECOVER else 0.0, dt * 4.0)
	if st != WorldReader.STATE_SPAWN:
		_rise = move_toward(_rise, 1.0, dt / RISE_TIME)
	var walking := st == WorldReader.STATE_MOVE or st == WorldReader.STATE_ACTIVE
	var walk_target := clampf(_speed / WALK_SPEED, 0.0, 1.0) if walking else 0.0
	_walk = lerpf(_walk, walk_target, _rate(10.0, dt))
	_phase += minf(_speed / STRIDE, MAX_CYCLES) * TAU * dt
	_pose()


## 0..1 how far into the wind-up pose (reared back, claws raised).
func windup_amount() -> float:
	return _wind


## v0.8.0 TG: 0..1 how deep the windup crouch is (from the windup's progress).
func crouch_amount() -> float:
	return tell_crouch(_tell_p) if _state == WorldReader.STATE_WINDUP else 0.0


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The talon tips in this node's frame, front right, front left, back right, back left.
func leg_tips() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in _talons.size():
		var l: float = (FRONT_LEN if k < 2 else BACK_LEN)[2]
		out.append(
			(
				global_transform.affine_inverse()
				* _talons[k].global_transform
				* Vector3(l, -l * TALON_DROP, 0)
			)
		)
	return out


## The body's height above its rest pose, in metres (negative when it sinks: dazed, or before the rise).
func body_lift() -> float:
	return _model.position.y + body.position.y


func _pose() -> void:
	var rise := smoothstep(0.0, 1.0, _rise)
	var lunge := _lunge * (1.0 - _daze)
	# Body: a scuttling bob, a slow breath when still, rear back on the wind-up (with a tremble), drop its nose and
	# shove forward on the lunge, slump and list to one side when dazed.
	var bob := absf(sin(_phase * 2.0)) * 0.02 * _walk
	var breath := sin(_t * 2.4) * 0.008 * (1.0 - _walk)
	var calm := ViewPrefs.reduced_motion
	var tremble := 0.0 if calm else sin(_t * 47.0) * 0.006 * _wind
	var crouch := crouch_amount()
	var drop := _daze * 0.09 - _wind * 0.05 + lunge * 0.07 + crouch * 0.09
	var y := bob + breath + tremble - drop
	var sink := Vector3(0, -(1.0 - rise) * 0.45, 0)
	if _model.position != sink:  # v0.8.0 HV: still once risen (moving it re-dirties the whole model)
		_model.position = sink
	# The lunge throws the whole hood forward, nose down and stretched long, so it reads from above.
	# v0.8.0 HV: one transform write (rotation then scale, as Node3D composes them) instead of three.
	_body_pos = Vector3(-_wind * 0.06 - crouch * 0.07 + lunge * 0.16, y, 0)
	var rot := Vector3(_daze * 0.16, 0, _wind * 0.3 - lunge * 0.3 - _daze * 0.1)
	var scl := Vector3(1.0 + lunge * 0.14, 1.0 - lunge * 0.06, 1.0 - lunge * 0.04)
	body.transform = Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), _body_pos)
	var shimmer := 0.0 if calm else 0.5 * sin(_t * 30.0)
	var tell := tell_glow(_tell_p, _t, calm) if _state == WorldReader.STATE_WINDUP else 1.0
	var glow := (
		VISOR_ENERGY * (1.0 + _wind * (1.6 + shimmer) + lunge * 1.2) * tell * (1.0 - _daze * 0.7)
	)
	if absf(glow - _visor_e) > 1e-4:  # v0.8.0 HV: written on a change only
		_visor_e = glow
		_visor_mat.emission_energy_multiplier = glow
	for k in legs.size():
		_pose_leg(k, y, lunge, rise)


## v0.8.0 HV (owner O89, the horde lag): the same maths as before in plain floats, no Array built (it made about 40
## Arrays per Charger a frame), and one transform write per segment (tests/unit/presentation/
## test_charger_pose_hv.gd compares it with the old formula).
func _pose_leg(k: int, body_y: float, lunge: float, rise: float) -> void:
	var front := k < 2
	var side := 1.0 if k % 2 == 0 else -1.0
	var hip: Vector3 = FRONT_HIP if front else BACK_HIP
	var l0: float = FRONT_LEN[0] if front else BACK_LEN[0]
	var l1: float = FRONT_LEN[1] if front else BACK_LEN[1]
	var l2: float = FRONT_LEN[2] if front else BACK_LEN[2]
	var y0: float = FRONT_YAW[0] if front else BACK_YAW[0]
	var y1: float = FRONT_YAW[1] if front else BACK_YAW[1]
	var y2: float = FRONT_YAW[2] if front else BACK_YAW[2]
	var p0: float = FRONT_PITCH[0] if front else BACK_PITCH[0]
	var p1: float = FRONT_PITCH[1] if front else BACK_PITCH[1]
	var p2: float = FRONT_PITCH[2] if front else BACK_PITCH[2]
	# Diagonal pairs step together: front right with back left, front left with back right.
	var off := 0.0 if (k == 0 or k == 3) else PI
	var lift := maxf(0.0, cos(_phase + off)) * 0.45 * _walk
	# Idle: now and then one leg lifts and taps (a slow fidget, never two at once).
	var fidget := (
		maxf(0.0, sin(_t * 0.9 + k * 1.6 + 4.0) - 0.85) * 2.2 * (1.0 - _walk) * (1.0 - _wind)
	)
	var sweep := sin(_phase + off) * 0.3 * _walk
	# Hips follow the body; the femur tips to keep the feet near the ground (a cheap stand-in for IK).
	var hold := clampf(-body_y / l0, -0.6, 0.6)
	# Toward the front is +yaw on the right side (the left mirrors it). Each sum adds its terms in the old order.
	var ay0 := sweep
	var ay1 := sweep
	var ay2 := sweep
	var ap0 := lift + fidget + hold
	var ap1 := lift * 0.5
	var ap2 := 0.0
	if front:
		# Wind-up: claws raised high and pointed forward. Lunge: the arms thrown out ahead, talons forward.
		ay0 = ay0 + (_wind * 0.3 + lunge * 0.55)
		ay1 = ay1 + (_wind * 0.2 + lunge * 0.2)
		ay2 = ay2 + -lunge * 0.5
		ap0 = ap0 + (_wind * 0.9 + lunge * 0.55)
		ap1 = ap1 + (_wind * 1.7 + lunge * 1.1)
		ap2 = ap2 + (_wind * 1.5 + lunge * 0.7)
	else:
		# Back legs brace on the wind-up and kick out behind on the lunge.
		ay0 = ay0 + (-_wind * 0.15 - lunge * 0.35)
		ay1 = ay1 + -lunge * 0.3
		ay2 = ay2 + -lunge * 0.3
		ap0 = ap0 + (-_wind * 0.1 + lunge * 0.3)
		ap1 = ap1 + lunge * 0.5
		ap2 = ap2 + lunge * 0.3
	# Dazed: legs splay, the talons go limp and twitch.
	var twitch := sin(_t * 9.0 + k) * 0.05 * _daze
	ay0 = ay0 + -_daze * 0.15
	ay1 = ay1 + -_daze * 0.15
	ay2 = ay2 + -_daze * 0.2
	ap0 = ap0 + _daze * 0.3
	ap1 = ap1 + 0.0
	ap2 = ap2 + (_daze * 0.35 + twitch)
	# Rising out of the ground the legs start folded up against the body.
	ap0 = ap0 + (1.0 - rise) * 1.2
	ap1 = ap1 + (1.0 - rise) * 1.4
	ap2 = ap2 + (1.0 - rise) * 1.0
	legs[k].position = Vector3(hip.x + _body_pos.x, hip.y + body_y, hip.z * side)
	var at := Vector3.ZERO
	at = _pose_seg(_femurs[k], at, (y0 + ay0) * side, p0 + ap0, l0)
	at = _pose_seg(_tibias[k], at, (y1 + ay1) * side, p1 + ap1, l1)
	_pose_seg(_talons[k], at, (y2 + ay2) * side, p2 + ap2, l2)


## One leg segment at `at`, turned (yaw y, pitch p), in one transform write; returns where the next one starts.
static func _pose_seg(seg: Node3D, at: Vector3, y: float, p: float, reach: float) -> Vector3:
	seg.transform = Transform3D(Basis.from_euler(Vector3(0, y, p)), at)
	return at + Vector3(cos(p) * cos(y), sin(p), -cos(p) * sin(y)) * reach


func _build_leg(
	hip: Vector3, lens: Array, side: float, front: bool, outline: Color, team: Color
) -> void:
	var s := 1.0 if front else 0.8
	var c := EnemyPalettes.color(kind, &"grey") if front else BACK_LEG_COLOR
	var root := Node3D.new()
	root.position = Vector3(hip.x, hip.y, hip.z * side)
	_model.add_child(root)
	# Each segment is one mesh node (its knuckle and its plate as two surfaces), hanging from the hip side by
	# side; _pose_leg chains them end to end. Few nodes per Charger: a fight holds many of them.
	var l1: float = lens[0]
	var l2: float = lens[1]
	var l3: float = lens[2]
	var femur_parts := [[_plate(l1, 0.046 * s, 0.042 * s), c]]
	if not front:
		femur_parts.append([_ball(0.05), JOINT_COLOR])
	var femur := _piece(root, femur_parts, outline, team, &"outline")
	var tibia_parts := [[_ball(0.05 * s), JOINT_COLOR], [_plate(l2, 0.055 * s, 0.068 * s), c]]
	var tibia := _piece(root, tibia_parts, outline, team, &"outline")
	var talon_parts := [[_ball(0.042 * s), JOINT_COLOR], [_talon_mesh(l3, 0.05 * s), TALON_COLOR]]
	var talon := _piece(root, talon_parts, outline, team, &"outline")
	legs.append(root)
	_femurs.append(femur)
	_tibias.append(tibia)
	_talons.append(talon)


# --- meshes -------------------------------------------------------------------------------------------------------


## The roof's cross-section rings, front to back: [x, ridge y, shoulder (x, y, z), flare (x, y, z), hem (x, y, z)]
## for the right half (the left mirrors it). The front ring is the pointed arch around the face. The ridge climbs a
## little toward the back and the hem climbs steeply, so from the side the roof is a long flat wedge whose lower
## edge cuts up diagonally to the sharp back corner, leaving the mantle below it showing.
static func _hood_rings() -> Array:
	return [
		_ring(
			0.27, 0.7, Vector3(0.25, 0.62, 0.1), Vector3(0.2, 0.52, 0.16), Vector3(0.12, 0.41, 0.16)
		),
		_ring(
			0.06,
			0.8,
			Vector3(0.07, 0.69, 0.15),
			Vector3(0.05, 0.56, 0.235),
			Vector3(0.02, 0.43, 0.23)
		),
		_ring(
			-0.18,
			0.83,
			Vector3(-0.18, 0.72, 0.16),
			Vector3(-0.19, 0.62, 0.24),
			Vector3(-0.2, 0.55, 0.235)
		),
		_ring(
			-0.42,
			HEIGHT - 0.01,
			Vector3(-0.43, 0.77, 0.15),
			Vector3(-0.45, 0.72, 0.2),
			Vector3(-0.46, 0.69, 0.18)
		),
	]


## A ring of seven points: hem, flare, shoulder on the left, the ridge, then shoulder, flare, hem on the right.
static func _ring(x: float, peak: float, sh: Vector3, fl: Vector3, hem: Vector3) -> Array:
	var m := Vector3(1, 1, -1)
	return [hem * m, fl * m, sh * m, Vector3(x, peak, 0), sh, fl, hem]


## The hood: a ridged roof from the face's arch back to a sharp corner that juts out behind the ridge.
static func _hood_mesh() -> ArrayMesh:
	var key: String = "hood"
	if not _meshes.has(key):
		_meshes[key] = _build_hood_mesh()
	return _meshes[key]


static func _build_hood_mesh() -> ArrayMesh:
	var rings := _crumple(_hood_rings(), 1)
	var tris := _shell(rings)
	var back: Array = rings[rings.size() - 1]
	var tail := Vector3(-0.58, HEIGHT, 0)
	var low := Vector3(-0.47, 0.7, 0)
	for k in back.size() - 1:
		tris.append([back[k], back[k + 1], tail])
	tris.append([back[0], low, tail])
	tris.append([back[back.size() - 1], tail, low])
	return flat_mesh(tris, Vector3(-0.08, 0.6, 0))


## Key rings with `n` in-between rings after each, each point pushed in or out a little: the cloth crumples into
## small uneven facets like the sheet's instead of reading as a smooth tent.
static func _crumple(key: Array, n: int) -> Array:
	var dents := [0.02, -0.025, 0.03, 0.012, -0.02, 0.028, -0.015, 0.01, -0.03]
	var rings := []
	for r in key.size():
		rings.append(key[r])
		if r == key.size() - 1:
			break
		for j in n:
			var f := float(j + 1) / float(n + 1)
			var mid := []
			for k in key[r].size():
				var q: Vector3 = key[r][k].lerp(key[r + 1][k], f)
				var d: float = dents[(k * 2 + r * 3 + j * 5) % dents.size()]
				# The ridge point stays on the centre line.
				mid.append(Vector3(q.x, q.y + d * 0.5, q.z * (1.0 + d)))
			rings.append(mid)
	return rings


## Joins consecutive rings into a shell. Each quad becomes four triangles round a centre nudged in or out, which
## breaks the surface into small facets.
static func _shell(rings: Array) -> Array:
	var tris := []
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in a.size() - 1:
			var c: Vector3 = (a[k] + a[k + 1] + b[k] + b[k + 1]) * 0.25
			var n: Vector3 = (a[k + 1] - a[k]).cross(b[k] - a[k])
			var bump := 0.007 if (k + r) % 3 == 0 else (-0.004 if (k + r) % 3 == 1 else 0.0)
			if n.length_squared() > 1e-10:
				var axis := Vector3(c.x, 0.5, 0)
				var out := n.normalized()
				if out.dot(c - axis) < 0.0:
					out = -out
				c += out * bump
			tris.append([a[k], a[k + 1], c])
			tris.append([a[k + 1], b[k + 1], c])
			tris.append([b[k + 1], b[k], c])
			tris.append([b[k], a[k], c])
	return tris


## A second, lower layer under the roof: a mantle whose hem runs level from the face to the back, so it shows
## below the roof's rising lower edge and juts out to a corner behind and at the back sides.
static func _flap_mesh() -> ArrayMesh:
	var key: String = "flap"
	if not _meshes.has(key):
		_meshes[key] = _build_flap_mesh()
	return _meshes[key]


static func _build_flap_mesh() -> ArrayMesh:
	var key := [
		_ring(
			0.04,
			0.66,
			Vector3(0.04, 0.6, 0.15),
			Vector3(0.03, 0.5, 0.215),
			Vector3(0.04, 0.4, 0.24)
		),
		_ring(
			-0.2,
			0.72,
			Vector3(-0.2, 0.66, 0.15),
			Vector3(-0.21, 0.56, 0.225),
			Vector3(-0.22, 0.4, 0.285)
		),
		_ring(
			-0.44,
			0.76,
			Vector3(-0.45, 0.71, 0.13),
			Vector3(-0.47, 0.62, 0.2),
			Vector3(-0.5, 0.44, 0.27)
		),
	]
	var rings := _crumple(key, 1)
	var tris := _shell(rings)
	var back: Array = rings[rings.size() - 1]
	var tail := Vector3(-0.64, 0.5, 0)
	for k in back.size() - 1:
		tris.append([back[k], back[k + 1], tail])
	return flat_mesh(tris, Vector3(-0.2, 0.62, 0))


## The dark body under the hood: a squat faceted lump that closes the hood's open bottom.
static func _core_mesh() -> ArrayMesh:
	var key: String = "core"
	if not _meshes.has(key):
		_meshes[key] = _build_core_mesh()
	return _meshes[key]


static func _build_core_mesh() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.24
	sm.radial_segments = 7
	sm.rings = 3
	var st := SurfaceTool.new()
	st.create_from(sm, 0)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		verts[k] = Vector3(verts[k].x * 1.3 - 0.1, verts[k].y + 0.46, verts[k].z)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tris := []
	for k in range(0, idx.size(), 3):
		tris.append([verts[idx[k]], verts[idx[k + 1]], verts[idx[k + 2]]])
	return flat_mesh(tris, Vector3(-0.1, 0.46, 0))


## The face: the roof's front arch set back into the hood, a dark collar joining the two, and a chin point under
## the visor.
static func _face_mesh() -> ArrayMesh:
	var key: String = "face"
	if not _meshes.has(key):
		_meshes[key] = _build_face_mesh()
	return _meshes[key]


static func _build_face_mesh() -> ArrayMesh:
	var rim: Array = _hood_rings()[0]
	var inner := []
	var mid := Vector3(0.15, 0.52, 0)
	for p: Vector3 in rim:
		var q := mid + (p - mid) * 0.9
		inner.append(Vector3(p.x - 0.06, q.y, q.z))
	var chin := Vector3(0.1, 0.33, 0)
	inner.append(chin)
	var tris := []
	for k in rim.size() - 1:
		tris.append([rim[k], rim[k + 1], inner[k + 1]])
		tris.append([rim[k], inner[k + 1], inner[k]])
	var centre := Vector3(0.13, 0.51, 0)
	var n := inner.size()
	for k in n:
		tris.append([inner[k], inner[(k + 1) % n], centre])
	tris.append([rim[0], inner[n - 1], rim[rim.size() - 1]])
	return flat_mesh(tris, Vector3(-0.2, 0.52, 0))


## The visor: a tall hexagonal gem, its point toward the front.
static func _visor_mesh() -> ArrayMesh:
	var key: String = "visor"
	if not _meshes.has(key):
		_meshes[key] = _build_visor_mesh()
	return _meshes[key]


static func _build_visor_mesh() -> ArrayMesh:
	var w := 0.032
	var h := 0.062
	var ring := [
		Vector3(0, h, 0),
		Vector3(0, h * 0.45, w),
		Vector3(0, -h * 0.45, w),
		Vector3(0, -h, 0),
		Vector3(0, -h * 0.45, -w),
		Vector3(0, h * 0.45, -w),
	]
	var tip := Vector3(0.02, 0, 0)
	var back := Vector3(-0.02, 0, 0)
	var tris := []
	for k in ring.size():
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % ring.size()]
		tris.append([a, b, tip])
		tris.append([a, back, b])
	return flat_mesh(tris, Vector3.ZERO)


## An armoured limb segment along +X: a six-sided plate, uneven round its sides, narrow at the joint, swelling to
## its widest three quarters down and bevelled in at the far end, with a raised ridge along its back.
static func _plate(length: float, r0: float, r1: float) -> ArrayMesh:
	var key: String = "plate %s %s %s" % [length, r0, r1]
	if not _meshes.has(key):
		_meshes[key] = _build_plate(length, r0, r1)
	return _meshes[key]


static func _build_plate(length: float, r0: float, r1: float) -> ArrayMesh:
	var shape := [1.25, 0.95, 0.85, 1.05, 0.85, 0.95]
	var stations := [
		[0.0, r0 * 0.75],
		[0.18, r0],
		[0.72, r1 * 1.08],
		[1.0, r1 * 0.72],
	]
	var rings := []
	for st: Array in stations:
		var ring := []
		for k in 6:
			var ang := TAU * k / 6.0
			var rr: float = st[1] * shape[k]
			ring.append(Vector3(length * st[0], cos(ang) * rr, sin(ang) * rr))
		rings.append(ring)
	var tris := []
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in 6:
			var k2 := (k + 1) % 6
			tris.append([a[k], a[k2], b[k2]])
			tris.append([a[k], b[k2], b[k]])
	var e0 := Vector3(-r0 * 0.3, 0, 0)
	var e1 := Vector3(length + r1 * 0.3, 0, 0)
	for k in 6:
		tris.append([rings[0][k], e0, rings[0][(k + 1) % 6]])
		tris.append([rings[3][k], rings[3][(k + 1) % 6], e1])
	return flat_mesh(tris, Vector3(length * 0.5, 0, 0))


## A low-poly joint knuckle at the pivot.
static func _ball(r: float) -> ArrayMesh:
	var key: String = "ball %s" % r
	if not _meshes.has(key):
		_meshes[key] = _build_ball(r)
	return _meshes[key]


static func _build_ball(r: float) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 2
	var st := SurfaceTool.new()
	st.create_from(sm, 0)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tris := []
	for k in range(0, idx.size(), 3):
		tris.append([verts[idx[k]], verts[idx[k + 1]], verts[idx[k + 2]]])
	return flat_mesh(tris, Vector3.ZERO)


## A talon along +X that curls toward -Y: a five-sided base, a bent middle ring and a sharp point.
static func _talon_mesh(length: float, r: float) -> ArrayMesh:
	var key: String = "talon %s %s" % [length, r]
	if not _meshes.has(key):
		_meshes[key] = _build_talon_mesh(length, r)
	return _meshes[key]


static func _build_talon_mesh(length: float, r: float) -> ArrayMesh:
	var n := 5
	var rings := []
	var spine := [
		[Vector3(-0.01, 0, 0), r],
		[Vector3(length * 0.42, 0.004, 0), r * 0.82],
		[Vector3(length * 0.75, -length * 0.07, 0), r * 0.45],
	]
	for sp: Array in spine:
		var c: Vector3 = sp[0]
		var rr: float = sp[1]
		var ring := []
		for k in n:
			var ang := TAU * k / n
			ring.append(c + Vector3(0, cos(ang) * rr, sin(ang) * rr))
		rings.append(ring)
	var tip := Vector3(length, -length * TALON_DROP, 0)
	var base := Vector3(-0.02, 0, 0)
	var tris := []
	for r2 in rings.size() - 1:
		var a: Array = rings[r2]
		var b: Array = rings[r2 + 1]
		for k in n:
			var k2 := (k + 1) % n
			tris.append([a[k], a[k2], b[k2]])
			tris.append([a[k], b[k2], b[k]])
	var last: Array = rings[rings.size() - 1]
	for k in n:
		tris.append([last[k], last[(k + 1) % n], tip])
		tris.append([rings[0][k], base, rings[0][(k + 1) % n]])
	return flat_mesh(tris, Vector3(length * 0.4, -0.01, 0))


## One mesh node from several [mesh, colour] parts, a surface each with its own outlined, flashable material;
## technique "xray" adds one silhouette twin for the whole node.
func _piece(
	parent: Node3D, parts: Array, outline: Color, team: Color, technique: StringName
) -> MeshInstance3D:
	var key := "piece"
	for part: Array in parts:
		key += " %d" % (part[0] as Object).get_instance_id()
	var merged: ArrayMesh = _meshes.get(key)
	if merged == null:  # v0.8.0 FV: one merged mesh per set of parts, shared
		merged = ArrayMesh.new()
		for part: Array in parts:
			var m: ArrayMesh = part[0]
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
		_meshes[key] = merged
	var mi := MeshInstance3D.new()
	mi.mesh = merged
	for k in parts.size():
		var mat := outline_material(parts[k][1], outline, OUTLINE_M)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(k, mat)
		body_materials.append(ActorViews.flashable(mat))
	parent.add_child(mi)
	if technique == &"xray":
		xray_twin(parent, merged, parts[0][1], team)
	return mi
