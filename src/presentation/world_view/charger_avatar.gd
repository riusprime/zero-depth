class_name ChargerAvatar
extends Node3D
## The Charger (v0.2.0 L17; docs/art/enemies_visual_reference.png, first creature): a long red hood with a ridged,
## faceted roof that peaks over a dark shield-shaped face with a glowing red gem visor, a back flap that juts out
## behind, and a charcoal body under it, carried spider-like on four grey segmented legs: a big front pair that
## arches out and curls bone-coloured talons in and forward, and a smaller back pair braced behind.
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time, and nothing here feeds back into the sim. ActorViews puts it under the actor's facing node, so +X is the
## front and +Z the right; it never turns itself.

## The legs: hip (right side; the left mirrors it), yaw (0 is the front, negative turns toward +Z), segment lengths
## (femur, tibia, talon) and their absolute pitch in the leg's plane (0 is level, negative points down).
const FRONT_HIP := Vector3(0.06, 0.56, 0.17)
const FRONT_YAW := -0.7
const FRONT_LEN := [0.27, 0.13, 0.237]
const FRONT_PITCH := [-0.85, -1.5, -1.69]
const BACK_HIP := Vector3(-0.18, 0.4, 0.1)
const BACK_YAW := -2.45
const BACK_LEN := [0.14, 0.19, 0.167]
const BACK_PITCH := [-0.53, -1.0, -1.47]
## The roof's ridge height: the model's height, for the health bar.
const HEIGHT := 0.84
## The front talons curl toward the front as well as in (a twist about the tibia's axis).
const TALON_TWIST := 1.1
## Movement the scuttle is tuned for: metres per full four-leg cycle, and the cycle-rate cap (a charge is 15 m/s).
const STRIDE := 0.55
const MAX_CYCLES := 7.0
const WALK_SPEED := 3.0
## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 40.0
## The rise out of the ground when the spawn ends, in seconds.
const RISE_TIME := 0.35
const OUTLINE_M := 0.018

## Colours sampled from the reference sheet (its lit and shaded tones, as albedo under the game's light).
const HOOD_COLOR := Color("#D8433A")
const FLAP_COLOR := Color("#C63B34")
const FACE_COLOR := Color("#16181D")
const CORE_COLOR := Color("#24272D")
const LEG_COLOR := Color("#6E605D")
const JOINT_COLOR := Color("#34363C")
const TALON_COLOR := Color("#E6B596")
const VISOR_COLOR := Color("#FF2A22")
const VISOR_ENERGY := 1.4

## Parts, read by tests and by ActorViews (flash materials; the visor's glow is its own).
var body: Node3D
var visor: MeshInstance3D
## Hip nodes, front right, front left, back right, back left.
var legs: Array[Node3D] = []
var body_materials: Array[StandardMaterial3D] = []

var _visor_mat := StandardMaterial3D.new()
# Everything hangs from this node, which sinks into the ground before the rise; this node itself is never moved.
var _model := Node3D.new()
var _femurs: Array[Node3D] = []
var _tibias: Array[Node3D] = []
var _talons: Array[Node3D] = []
# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _state := WorldReader.STATE_MOVE
# Smoothed animation state.
var _t := 0.0
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _wind := 0.0
var _lunge := 0.0
var _daze := 0.0
var _rise := 1.0


## Builds the model. technique "xray" adds an enemy-coloured silhouette twin to the hood and the body, as
## ActorViews does for its body pieces; the thin legs have none.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var team := ThemePalette.color(&"enemy_body")
	add_child(_model)
	body = Node3D.new()
	_model.add_child(body)
	_piece(body, _hood_mesh(), HOOD_COLOR, outline_color, team, technique)
	_piece(body, _flap_mesh(), FLAP_COLOR, outline_color, team, technique)
	_piece(body, _core_mesh(), CORE_COLOR, outline_color, team, technique)
	var face := MeshInstance3D.new()
	face.mesh = _face_mesh()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = FACE_COLOR
	fm.roughness = 1.0
	_write_stencil(fm)
	face.material_override = fm
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(face)
	visor = MeshInstance3D.new()
	visor.mesh = _visor_mesh()
	_visor_mat.albedo_color = VISOR_COLOR
	_visor_mat.emission_enabled = true
	_visor_mat.emission = VISOR_COLOR
	_visor_mat.emission_energy_multiplier = VISOR_ENERGY
	_write_stencil(_visor_mat)
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
	apply_state({"tick": reader.tick(), "pos": reader.actor_pos(i), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	if not _fresh and tick > _last_tick:
		var v := (pos - _last_pos) * (60.0 / float(tick - _last_tick))
		_vel = v if v.length() <= TELEPORT_SPEED and tick - _last_tick <= 30 else Vector2.ZERO
	elif tick < _last_tick:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos
	var prev := _state
	_state = s["state"]
	if _state == WorldReader.STATE_SPAWN:
		_rise = 0.0
	elif _fresh and prev != WorldReader.STATE_SPAWN:
		_rise = 1.0
	_fresh = false


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	_speed = lerpf(_speed, _vel.length(), _rate(12.0, dt))
	var st := _state
	_wind = move_toward(_wind, 1.0 if st == WorldReader.STATE_WINDUP else 0.0, dt * 6.0)
	_lunge = move_toward(_lunge, 1.0 if st == WorldReader.STATE_ACTIVE else 0.0, dt * 12.0)
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
				* Vector3(l, -l * 0.22, 0)
			)
		)
	return out


## The body's height above its rest pose, in metres (negative when it sinks: dazed, or before the rise).
func body_lift() -> float:
	return _model.position.y + body.position.y


func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


func _pose() -> void:
	var rise := smoothstep(0.0, 1.0, _rise)
	var lunge := _lunge * (1.0 - _daze)
	# Body: a scuttling bob, a slow breath when still, rear back on the wind-up (with a tremble), drop its nose and
	# shove forward on the lunge, slump and list to one side when dazed.
	var bob := absf(sin(_phase * 2.0)) * 0.02 * _walk
	var breath := sin(_t * 2.4) * 0.008 * (1.0 - _walk)
	var tremble := sin(_t * 47.0) * 0.006 * _wind
	var drop := _daze * 0.09 - _wind * 0.05 + lunge * 0.02
	var y := bob + breath + tremble - drop
	_model.position = Vector3(0, -(1.0 - rise) * 0.45, 0)
	body.position = Vector3(-_wind * 0.06 + lunge * 0.07, y, 0)
	body.rotation = Vector3(_daze * 0.16, 0, _wind * 0.3 - lunge * 0.14 - _daze * 0.1)
	var glow := (
		VISOR_ENERGY
		* (1.0 + _wind * (1.6 + 0.5 * sin(_t * 30.0)) + lunge * 1.2)
		* (1.0 - _daze * 0.7)
	)
	_visor_mat.emission_energy_multiplier = glow
	for k in legs.size():
		_pose_leg(k, y, lunge, rise)


func _pose_leg(k: int, body_y: float, lunge: float, rise: float) -> void:
	var front := k < 2
	var right := k % 2 == 0
	var hip: Vector3 = FRONT_HIP if front else BACK_HIP
	var pitch: Array = FRONT_PITCH if front else BACK_PITCH
	var lens: Array = FRONT_LEN if front else BACK_LEN
	var side := 1.0 if right else -1.0
	# Diagonal pairs step together: front right with back left, front left with back right.
	var off := 0.0 if (k == 0 or k == 3) else PI
	var s := sin(_phase + off)
	var lift := maxf(0.0, cos(_phase + off)) * 0.45 * _walk
	# Idle: now and then one leg lifts and taps (a slow fidget, never two at once).
	var fidget := maxf(0.0, sin(_t * 0.9 + k * 1.6) - 0.85) * 2.2 * (1.0 - _walk) * (1.0 - _wind)
	var sweep := s * 0.3 * _walk
	var e1: float = pitch[0] + lift + fidget
	var e2: float = pitch[1] + lift * 0.3
	var e3: float = pitch[2]
	var yaw: float = (FRONT_YAW if front else BACK_YAW) + sweep
	if front:
		# Wind-up: claws raised high and pointed forward; lunge: reaching out ahead.
		e1 += _wind * 0.75 + lunge * 0.35
		e2 += _wind * 1.15 + lunge * 0.75
		e3 += _wind * 1.0 + lunge * 0.55
		yaw += _wind * 0.35 + lunge * 0.4
	else:
		# Back legs brace behind on the wind-up and kick back on the lunge.
		e1 += -_wind * 0.15 + lunge * 0.2
		e2 += lunge * 0.4
		yaw += -_wind * 0.15 - lunge * 0.3
	# Dazed: legs splay and the talons go limp.
	e1 += _daze * 0.3
	e3 += _daze * 0.35 + sin(_t * 9.0 + k) * 0.05 * _daze
	yaw -= _daze * 0.15
	# Hips follow the body; the femur tips to keep the feet near the ground (a cheap stand-in for IK).
	e1 += clampf(-body_y / float(lens[0]), -0.6, 0.6)
	# Rising out of the ground the legs start folded up against the body.
	e1 += (1.0 - rise) * 1.2
	e2 += (1.0 - rise) * 1.4
	legs[k].position = Vector3(hip.x + body.position.x, hip.y + body_y, hip.z * side)
	legs[k].rotation = Vector3(0, yaw * side, 0)
	_femurs[k].rotation = Vector3(0, 0, e1)
	_tibias[k].rotation = Vector3(0, 0, e2 - e1)
	_talons[k].rotation = Vector3((TALON_TWIST if front else 0.0) * side, 0, e3 - e2)


func _build_leg(
	hip: Vector3, lens: Array, side: float, front: bool, outline: Color, team: Color
) -> void:
	var s := 1.0 if front else 0.8
	var root := Node3D.new()
	root.position = Vector3(hip.x, hip.y, hip.z * side)
	_model.add_child(root)
	var femur := Node3D.new()
	root.add_child(femur)
	var l1: float = lens[0]
	var l2: float = lens[1]
	var l3: float = lens[2]
	_piece(femur, _prism(l1, 0.048 * s, 0.04 * s, 5), LEG_COLOR, outline, team, &"outline")
	if not front:
		_piece(femur, _ball(0.055), JOINT_COLOR, outline, team, &"outline")
	var tibia := Node3D.new()
	tibia.position.x = l1
	femur.add_child(tibia)
	_piece(tibia, _ball(0.055 * s), JOINT_COLOR, outline, team, &"outline")
	_piece(tibia, _prism(l2, 0.06 * s, 0.07 * s, 5), LEG_COLOR, outline, team, &"outline")
	var talon := Node3D.new()
	talon.position.x = l2
	tibia.add_child(talon)
	_piece(talon, _talon_mesh(l3, 0.052 * s), TALON_COLOR, outline, team, &"outline")
	legs.append(root)
	_femurs.append(femur)
	_tibias.append(tibia)
	_talons.append(talon)


# --- meshes -------------------------------------------------------------------------------------------------------


## The roof's cross-section rings, front to back: [x, peak y, shoulder (x, y, z), flare (x, y, z), hem (x, y, z)]
## for the right half (the left mirrors it). The front ring is the pointed arch around the face.
static func _hood_rings() -> Array:
	return [
		_ring(
			0.27,
			0.68,
			Vector3(0.25, 0.61, 0.1),
			Vector3(0.2, 0.51, 0.16),
			Vector3(0.12, 0.41, 0.16)
		),
		_ring(
			0.08,
			HEIGHT,
			Vector3(0.09, 0.69, 0.15),
			Vector3(0.07, 0.55, 0.24),
			Vector3(0.04, 0.42, 0.23)
		),
		_ring(
			-0.16,
			0.83,
			Vector3(-0.16, 0.69, 0.16),
			Vector3(-0.17, 0.56, 0.25),
			Vector3(-0.16, 0.47, 0.235)
		),
		_ring(
			-0.38,
			0.78,
			Vector3(-0.39, 0.67, 0.14),
			Vector3(-0.4, 0.6, 0.2),
			Vector3(-0.37, 0.56, 0.18)
		),
	]


## A ring of seven points: hem, flare, shoulder on the left, the ridge, then shoulder, flare, hem on the right.
static func _ring(x: float, peak: float, sh: Vector3, fl: Vector3, hem: Vector3) -> Array:
	var m := Vector3(1, 1, -1)
	return [hem * m, fl * m, sh * m, Vector3(x, peak, 0), sh, fl, hem]


## The hood: a ridged roof from the face's arch back to a tail that juts out behind the ridge.
static func _hood_mesh() -> ArrayMesh:
	var key := _hood_rings()
	# Between each pair of key rings, a ring pushed in or out a little per point: the roof crumples into uneven
	# facets like the sheet's instead of reading as a smooth tent.
	var dents := [0.02, -0.025, 0.03, 0.015, -0.02, 0.03, -0.015]
	var rings := []
	for r in key.size():
		rings.append(key[r])
		if r == key.size() - 1:
			break
		var mid := []
		for k in key[r].size():
			var p: Vector3 = (key[r][k] + key[r + 1][k]) * 0.5
			var d: float = dents[(k + r * 3) % dents.size()]
			mid.append(Vector3(p.x, p.y + d * 0.6, p.z * (1.0 + d)))
		rings.append(mid)
	var tris := []
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in a.size() - 1:
			# Alternate the diagonal so the roof breaks into uneven triangles, as on the sheet.
			if (k + r) % 2 == 0:
				tris.append([a[k], a[k + 1], b[k + 1]])
				tris.append([a[k], b[k + 1], b[k]])
			else:
				tris.append([a[k], a[k + 1], b[k]])
				tris.append([a[k + 1], b[k + 1], b[k]])
	var back: Array = rings[rings.size() - 1]
	var tail := Vector3(-0.5, 0.76, 0)
	var low := Vector3(-0.4, 0.58, 0)
	for k in back.size() - 1:
		tris.append([back[k], back[k + 1], tail])
	tris.append([back[0], low, tail])
	tris.append([back[back.size() - 1], tail, low])
	return _mesh_from(tris, Vector3(-0.05, 0.56, 0))


## A second, lower layer under the roof's back half: a mantle whose hem sticks out behind and to the sides.
static func _flap_mesh() -> ArrayMesh:
	var top := [
		Vector3(0.02, 0.5, -0.22),
		Vector3(-0.2, 0.55, -0.22),
		Vector3(-0.38, 0.63, -0.17),
		Vector3(-0.45, 0.66, 0.0),
		Vector3(-0.38, 0.63, 0.17),
		Vector3(-0.2, 0.55, 0.22),
		Vector3(0.02, 0.5, 0.22),
	]
	var hem := [
		Vector3(0.03, 0.42, -0.25),
		Vector3(-0.22, 0.41, -0.29),
		Vector3(-0.47, 0.44, -0.24),
		Vector3(-0.58, 0.5, 0.0),
		Vector3(-0.47, 0.44, 0.24),
		Vector3(-0.22, 0.41, 0.29),
		Vector3(0.03, 0.42, 0.25),
	]
	var tris := []
	for k in top.size() - 1:
		tris.append([top[k], top[k + 1], hem[k + 1]])
		tris.append([top[k], hem[k + 1], hem[k]])
	return _mesh_from(tris, Vector3(-0.15, 0.62, 0))


## The dark body under the hood: a squat faceted lump that closes the hood's open bottom.
static func _core_mesh() -> ArrayMesh:
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
	return _mesh_from(tris, Vector3(-0.1, 0.46, 0))


## The face: the roof's front arch set back into the hood, a dark collar joining the two, and a chin point under
## the visor.
static func _face_mesh() -> ArrayMesh:
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
	return _mesh_from(tris, Vector3(-0.2, 0.52, 0))


## The visor: a tall hexagonal gem, its point toward the front.
static func _visor_mesh() -> ArrayMesh:
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
	return _mesh_from(tris, Vector3.ZERO)


## A faceted limb segment along +X: an n-sided prism from radius r0 to r1 with blunt pointed ends.
static func _prism(length: float, r0: float, r1: float, n: int) -> ArrayMesh:
	var a := []
	var b := []
	for k in n:
		var ang := TAU * (k + 0.5) / n
		a.append(Vector3(0.0, cos(ang) * r0, sin(ang) * r0))
		b.append(Vector3(length, cos(ang) * r1, sin(ang) * r1))
	var e0 := Vector3(-r0 * 0.45, 0, 0)
	var e1 := Vector3(length + r1 * 0.45, 0, 0)
	var tris := []
	for k in n:
		var k2 := (k + 1) % n
		tris.append([a[k], a[k2], b[k2]])
		tris.append([a[k], b[k2], b[k]])
		tris.append([a[k], e0, a[k2]])
		tris.append([b[k], b[k2], e1])
	return _mesh_from(tris, Vector3(length * 0.5, 0, 0))


## A low-poly joint knuckle at the pivot.
static func _ball(r: float) -> ArrayMesh:
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
	return _mesh_from(tris, Vector3.ZERO)


## A talon along +X that curls toward -Y: a five-sided base, a bent middle ring and a sharp point.
static func _talon_mesh(length: float, r: float) -> ArrayMesh:
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
	var tip := Vector3(length, -length * 0.22, 0)
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
	return _mesh_from(tris, Vector3(length * 0.4, -0.01, 0))


## Flat-shaded triangles, each wound to face away from `centre`.
static func _mesh_from(tris: Array, centre: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		# Godot's front faces wind clockwise.
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## The face and visor mark the stencil like the body pieces do, so the hood's X-ray twin behind them stays hidden.
static func _write_stencil(m: StandardMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


func _piece(
	parent: Node3D, mesh: Mesh, c: Color, outline: Color, team: Color, technique: StringName
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = OUTLINE_M
	mi.material_override = mat
	parent.add_child(mi)
	body_materials.append(mat)
	if technique == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(team, 0.85)
		ghost.material_override = gm
		ghost.scale = Vector3.ONE * 0.96
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
	return mi
