class_name NeedleAvatar
extends Node3D
## The Needle (owner, v0.2.0 L17; docs/art/enemies_visual_reference.png, middle row): a walking turret. A red
## faceted cube body (each face a shallow pyramid) with grey octagonal pods on its flanks, a dark collar on its
## front with a red slit eye on each side, a square grey cannon barrel pointing forward, and four grey mechanical
## legs (hip hub, thigh, knee joint, steep shin, flat foot) splayed to the corners. Presentation only (EI-07):
## sync() reads the sim through WorldReader once per tick, advance() animates in frame time, and nothing here feeds
## back into the sim. The legs are solved by two-bone IK toward foot targets on the ground, so the feet stay planted
## while the body bobs, crouches or recoils. +X is the front (the cannon) and +Z the right; ActorViews parents this
## under the actor's facing node.

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
const OUTLINE_M := 0.022

## Colours sampled from the reference sheet (the lit faces), as albedo under the game's light.
const RED := Color("#E03C30")
const GREY := Color("#5F5551")
const GREY_LIGHT := Color("#6D625C")
const DARK := Color("#3A383C")
const HOLE := Color("#141417")
const EYE := Color("#FF2A22")

## Parts, read by tests and by ActorViews (flash materials).
var body: Node3D
var barrel: Node3D
var legs: Array[Node3D] = []
var feet: Array[Node3D] = []
var body_materials: Array[StandardMaterial3D] = []

var _eye_mat := StandardMaterial3D.new()
var _hole_mat := StandardMaterial3D.new()
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _ankles: Array[Node3D] = []
var _hips: Array[Vector3] = []
var _rests: Array[Vector3] = []
# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _shots := 0
# Smoothed animation state.
var _t := 0.0
var _vel_s := Vector3.ZERO
var _phase := 0.0
var _walk := 0.0
var _rise := 0.0
var _brace := 0.0
var _charge := 0.0
var _heat := 0.0
var _kick := 0.0


## Builds the model. technique "xray" adds a team-coloured silhouette twin to the cube, the pods and the barrel
## (as ActorViews does for its body pieces); the thin legs have none.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var team := ThemePalette.color(&"enemy_body")
	body = Node3D.new()
	add_child(body)
	var cube := _chamfer_box(Vector3.ONE * BODY, BODY_BEVEL, BODY_BULGE)
	_piece(body, cube, Vector3(0, BODY_Y, 0), RED, outline_color, team, technique)
	# The chassis under the cube, which the hips hang from.
	var chassis := _chamfer_box(Vector3(0.3, 0.07, 0.3), 0.015)
	_piece(body, chassis, Vector3(0, HIP.y + 0.02, 0), DARK, outline_color, team, &"outline")
	# The flank pods: big bevels make them octagons from the side; their faces carry the same shallow facets.
	var pod := _chamfer_box(Vector3(0.24, 0.26, 0.1), 0.06, 0.012)
	for side in [-1.0, 1.0]:
		var at := Vector3(-0.03, 0.46, side * (BODY * 0.5 + 0.045))
		_piece(body, pod, at, GREY, outline_color, team, technique)
	# The collar on the front face that the barrel comes out of, with a red slit eye on each flank.
	var collar := _chamfer_box(Vector3(0.12, 0.25, 0.2), 0.02)
	var collar_x := BODY * 0.5 + 0.03
	_piece(
		body, collar, Vector3(collar_x, BARREL_Y - 0.01, 0), DARK, outline_color, team, &"outline"
	)
	_eye_mat.albedo_color = EYE
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE
	_eye_mat.emission_energy_multiplier = 2.0
	_write_stencil(_eye_mat)
	var slit := BoxMesh.new()
	slit.size = Vector3(0.035, 0.11, 0.01)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = slit
		eye.material_override = _eye_mat
		eye.position = Vector3(collar_x + 0.015, BARREL_Y, side * 0.1)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(eye)
	_build_barrel(outline_color, team, technique)
	for k in 4:
		_build_leg(k, outline_color, team)
	_pose(0.0)


## Reads the Needle's state after a sim tick.
func sync(reader: WorldReader, i: int) -> void:
	apply_state({"tick": reader.tick(), "pos": reader.actor_pos(i), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	var state: int = s["state"]
	if not _fresh and tick > _last_tick:
		var v := (pos - _last_pos) * (60.0 / float(tick - _last_tick))
		_vel = v if v.length() <= TELEPORT_SPEED and tick - _last_tick <= 30 else Vector2.ZERO
	elif tick < _last_tick:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos
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


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
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
	elif _state == WorldReader.STATE_ACTIVE:
		charge_target = 1.0
	_charge = lerpf(_charge, charge_target, _rate(14.0 if charge_target > _charge else 3.0, dt))
	_kick = move_toward(_kick, 0.0, dt * 7.0)
	_heat = move_toward(_heat, 0.0, dt * 1.6)
	_pose(dt)


## The barrel's recoil: how far it has slid back into the collar, in metres (0 at rest).
func barrel_recoil() -> float:
	return -barrel.position.x + (BODY * 0.5 + 0.06)


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


func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


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
	var y := hum + bob - _brace * 0.06 - (1.0 - _rise) * 0.24 + kick * 0.01
	# Lean into the walk; brace leans back a little; each shot rocks the nose up.
	var lean := (
		Basis(Vector3.UP.cross(move_dir).normalized(), 0.07 * _walk) if _walk > 0.001 else Basis()
	)
	var pitch := Basis(Vector3.BACK, _brace * 0.05 + kick * 0.12 - (1.0 - _rise) * 0.2)
	# Pivot about the hips, so a pitch rocks the cube instead of swinging it about the ground.
	var b := lean * pitch
	var pivot := Vector3(0, HIP.y, 0)
	var at := Vector3(-kick * 0.035 - _brace * 0.015, y, 0)
	body.transform = Transform3D(b, at + pivot - b * pivot)
	barrel.position.x = BODY * 0.5 + 0.06 - kick * 0.09
	# Glow: the eyes and the muzzle brighten through the wind-up, flare on each shot, cool down after.
	var cool := 1.0 if _state == WorldReader.STATE_RECOVER else 0.0
	var pulse := 0.15 * sin(_t * 3.0)
	_eye_mat.emission_energy_multiplier = (
		(2.0 + pulse + _charge * 4.0 + kick * 3.0 - cool * 0.8) * lerpf(0.2, 1.0, _rise)
	)
	_hole_mat.emission_energy_multiplier = maxf(_charge * 3.5, _heat * 2.0) + kick * 6.0
	# The legs: each foot steps around its rest spot, then IK from the hip (on the moving body) to the foot.
	for k in legs.size():
		var p := fposmod(_phase + (0.5 if k % 2 == 1 else 0.0), 1.0)
		var u := 1.0 - 4.0 * p if p < 0.5 else -1.0 + 4.0 * (p - 0.5)
		var lift := 0.0 if p < 0.5 else sin((p - 0.5) * TAU) * LIFT
		var rest := _rests[k]
		var foot := Vector3(rest.x, 0.0, rest.z) * lerpf(0.55, 1.0, _rise)
		foot += move_dir * u * STRIDE * 0.5 * _walk
		foot.y = lift * _walk
		_solve_leg(k, body.transform * _hips[k], foot)


## Places leg k's root at the hip, turns it toward the foot and bends thigh, knee and ankle to reach it (two-bone
## IK, knee up and out like the reference's).
func _solve_leg(k: int, hip: Vector3, foot: Vector3) -> void:
	var root := legs[k]
	root.position = hip
	var flat := Vector2(foot.x - hip.x, foot.z - hip.z)
	root.rotation = Vector3(0, atan2(-flat.y, flat.x), 0)
	var d := flat.length()
	var dz := foot.y + ANKLE_H - hip.y
	var r := clampf(Vector2(d, dz).length(), 0.05, THIGH_LEN + SHIN_LEN - 0.001)
	var base := atan2(dz, d)
	var cos_a := (THIGH_LEN * THIGH_LEN + r * r - SHIN_LEN * SHIN_LEN) / (2.0 * THIGH_LEN * r)
	var a1 := base + acos(clampf(cos_a, -1.0, 1.0))
	var knee := Vector2(cos(a1), sin(a1)) * THIGH_LEN
	var a2 := atan2(dz - knee.y, d - knee.x)
	_thighs[k].rotation = Vector3(0, 0, a1)
	_knees[k].rotation = Vector3(0, 0, a2 - a1)
	_ankles[k].rotation = Vector3(0, 0, -a2)


func _build_barrel(outline_color: Color, team: Color, technique: StringName) -> void:
	barrel = Node3D.new()
	barrel.position = Vector3(BODY * 0.5 + 0.06, BARREL_Y, 0)
	body.add_child(barrel)
	var tube := _chamfer_box(Vector3(BARREL_LEN, BARREL_W, BARREL_W), 0.012)
	_piece(barrel, tube, Vector3(BARREL_LEN * 0.5, 0, 0), GREY, outline_color, team, technique)
	# A slightly wider sleeve at the muzzle, as on the sheet's side view.
	var sleeve := _chamfer_box(Vector3(0.07, BARREL_W + 0.012, BARREL_W + 0.012), 0.012)
	_piece(barrel, sleeve, Vector3(BARREL_LEN - 0.035, 0, 0), GREY, outline_color, team, &"outline")
	# The square bore: dark when cold; it glows the hostile-shot colour while charging and firing.
	var shot := ThemePalette.color(&"proj_hostile")
	_hole_mat.albedo_color = HOLE
	_hole_mat.emission_enabled = true
	_hole_mat.emission = shot
	_hole_mat.emission_energy_multiplier = 0.0
	_write_stencil(_hole_mat)
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
func _build_leg(k: int, outline_color: Color, team: Color) -> void:
	var sx := 1.0 if k < 2 else -1.0
	var sz := 1.0 if k == 1 or k == 2 else -1.0
	_hips.append(Vector3(HIP.x * sx, HIP.y, HIP.z * sz))
	_rests.append(Vector3(FOOT.x * sx, 0.0, FOOT.z * sz))
	var root := Node3D.new()
	add_child(root)
	legs.append(root)
	var hub := _prism(0.05, 0.08, 8)
	_piece(root, hub, Vector3.ZERO, DARK, outline_color, team, &"outline")
	var thigh := Node3D.new()
	root.add_child(thigh)
	_thighs.append(thigh)
	var tm := _chamfer_box(Vector3(THIGH_LEN, 0.075, 0.07), 0.014)
	_piece(thigh, tm, Vector3(THIGH_LEN * 0.5, 0, 0), GREY, outline_color, team, &"outline")
	var knee := Node3D.new()
	knee.position.x = THIGH_LEN
	thigh.add_child(knee)
	_knees.append(knee)
	_piece(knee, _prism(0.042, 0.1, 8), Vector3.ZERO, GREY_LIGHT, outline_color, team, &"outline")
	var sm := _chamfer_box(Vector3(SHIN_LEN, 0.085, 0.08), 0.016)
	_piece(knee, sm, Vector3(SHIN_LEN * 0.5, 0, 0), GREY, outline_color, team, &"outline")
	var ankle := Node3D.new()
	ankle.position.x = SHIN_LEN
	knee.add_child(ankle)
	_ankles.append(ankle)
	_piece(ankle, _prism(0.03, 0.09, 6), Vector3.ZERO, DARK, outline_color, team, &"outline")
	var fm := _chamfer_box(Vector3(0.13, 0.045, 0.1), 0.012)
	var foot := Node3D.new()
	foot.position = Vector3(0.015, -ANKLE_H + 0.0225, 0)
	ankle.add_child(foot)
	_piece(foot, fm, Vector3.ZERO, GREY_LIGHT, outline_color, team, &"outline")
	feet.append(foot)


## The eyes and the bore mark the stencil like the body pieces do, so the X-ray twins behind them stay hidden.
static func _write_stencil(m: StandardMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


func _piece(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	outline: Color,
	team: Color,
	technique: StringName
) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = OUTLINE_M
	piece.material_override = mat
	parent.add_child(piece)
	body_materials.append(mat)
	if technique == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(team, 0.85)
		ghost.material_override = gm
		ghost.position = at
		ghost.scale = Vector3.ONE * 0.96
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
	return piece


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
