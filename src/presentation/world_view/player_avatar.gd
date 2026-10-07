class_name PlayerAvatar
extends Node3D
## The player's hooded wanderer (owner, 2026-10-07; docs/art/main-character-sheet.png, the primary reference): a
## forward-tipped hood that tapers from a wide, square back to a shield-shaped front (flat top, a point at the
## chin), a recessed black face of the same shape with a centred landscape cyan visor; a diamond poncho (its hem
## corners point front, back, left and right; the front corner hangs lowest, a V-neck notch sits under the chin)
## about twice the hood's width; two chunky charcoal legs with lighter boot blocks. Presentation only (EI-07):
## sync() reads the sim through WorldReader once per tick, advance() animates in frame time, and nothing here feeds
## back into the sim. The poncho's hem points are damped springs in this node's frame (which never rotates), so
## they lag behind acceleration and turns, stream back on a dash and settle when the wanderer stops.
## +X is the front and +Z the right in every local frame; the sim (x, y) maps to 3D (x, h, -y) as in SimPlane.

const HIP_Y := 0.42
const LEG_LEN := 0.42
## Leg centres sit this far either side of the middle: a gap about one leg wide between them.
const LEG_GAP := 0.115
const LEG_W := 0.13
const NECK_Y := 0.91
## Hem points: the four diamond corners (front, right, back, left) and a fold point between each pair.
const CLOAK_SIDES := 8
## Hem corner heights and reaches (front, side, back), in metres from the ground / the body axis.
const HEM_FRONT := Vector2(0.32, 0.36)
const HEM_SIDE := Vector2(0.5, 0.39)
const HEM_BACK := Vector2(0.34, 0.37)
## The hood tips forward, as in the sheet's side view.
const HOOD_TILT := 0.1
## The hood's open front and the face plate recessed behind it (hood-local x).
const HOOD_HALF_LEN := 0.25
const HOOD_FRONT_SCALE := 0.82
const HOOD_MID_Y := 0.015
const FACE_X := HOOD_HALF_LEN - 0.02
## The face's point, below the hood's bottom (hood-local y).
const CHIN_Y := -0.3
## The avatar's rim is thinner than the other actors' (the sheet has a light line, not a heavy one).
const OUTLINE_M := 0.014
## Walking speed the gait is tuned for (the sim's 6 m/s) and the stride (metres per full two-step cycle).
const WALK_SPEED := 6.0
const STRIDE := 1.25
## Cloak springs (starting values): stiffness, damping, air drag, max offset from rest, sub-step length.
const SPRING_K := 110.0
const SPRING_C := 6.5
const AIR_DRAG := 1.0
## How much of the body's acceleration the cloak feels (1 would be a free cloth; less keeps it subtle).
const INERTIA := 0.3
const MAX_OFFSET := 0.22
const SUB_STEP := 1.0 / 120.0
## Faster than this between two ticks is a teleport (blink, a new floor), not motion: the dash is ~27 m/s.
const TELEPORT_SPEED := 40.0

const CLOAK_COLOR := Color("#EBDCCB")
const HOOD_COLOR := Color("#EBDCCB")
## The poncho's underside: the same cream in shade.
const UNDER_COLOR := Color("#C9B8A6")
## The poncho's inside at the neck, deep in the hood's shadow.
const NECK_SHADE := Color("#1E1F24")
const FACE_COLOR := Color("#15161A")
const LEG_COLOR := Color("#3A3D44")
const BOOT_COLOR := Color("#50535B")

## Parts, read by tests and by ActorViews (flash materials).
var hood: Node3D
var visor: MeshInstance3D
var face: MeshInstance3D
var cloak: MeshInstance3D
var legs: Array[Node3D] = []
var body_materials: Array[StandardMaterial3D] = []

var _pelvis := Node3D.new()
var _head_yaw := Node3D.new()
var _leg_root := Node3D.new()
var _cloak_mesh := ArrayMesh.new()
var _visor_mat := StandardMaterial3D.new()
# Rest cloak rings in the cloak frame (pelvis * cloak yaw): top (fixed), flare (springs), hem (springs).
var _top_rest: Array[Vector3] = []
var _spring_rest: Array[Vector3] = []
var _spring_pos: Array[Vector3] = []
var _spring_vel: Array[Vector3] = []
var _spring_target: Array[Vector3] = []
# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _aim_yaw := 0.0
var _dashing := false
var _swing := 0.0
var _swing_dir := 1.0
var _guarding := false
var _dead := false
# Smoothed animation state.
var _t := 0.0
var _vel_s := Vector3.ZERO
var _body_yaw := 0.0
var _leg_yaw := 0.0
var _phase := 0.0
var _walk := 0.0
var _dash := 0.0
var _twist := 0.0
var _crouch := 0.0
var _slump := 0.0
var _lean := Vector3.ZERO


## Builds the model. technique "xray" adds a team-coloured silhouette twin to the hood and the cloak (as
## ActorViews does for its body pieces); the legs, mostly under the cloak, have none.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var team := ThemePalette.color(&"player_core")
	_pelvis.position.y = HIP_Y
	add_child(_pelvis)
	_pelvis.add_child(_head_yaw)
	hood = Node3D.new()
	hood.position = Vector3(0.05, NECK_Y - HIP_Y, 0)
	_head_yaw.add_child(hood)
	var shell := _mesh_piece(hood, _hood_mesh(), HOOD_COLOR, outline_color, team, technique)
	(shell.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	face = MeshInstance3D.new()
	face.mesh = _face_mesh()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = FACE_COLOR
	fm.roughness = 1.0
	_write_stencil(fm)
	face.material_override = fm
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hood.add_child(face)
	visor = MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.012, 0.085, 0.13)
	visor.mesh = vb
	_visor_mat.albedo_color = team
	_visor_mat.emission_enabled = true
	_visor_mat.emission = team
	_visor_mat.emission_energy_multiplier = 2.4
	_write_stencil(_visor_mat)
	visor.material_override = _visor_mat
	visor.position = Vector3(FACE_X + 0.006, 0.0, 0)
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hood.add_child(visor)
	_build_cloak_rest()
	# The poncho's colour comes from its vertices: cream outside, the shaded cream underneath.
	cloak = _mesh_piece(self, _cloak_mesh, Color.WHITE, outline_color, team, technique)
	var cm := cloak.material_override as StandardMaterial3D
	cm.vertex_color_use_as_albedo = true
	cm.vertex_color_is_srgb = true
	_leg_root.position.y = HIP_Y
	add_child(_leg_root)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0, side * LEG_GAP)
		_leg_root.add_child(pivot)
		var leg := BoxMesh.new()
		leg.size = Vector3(LEG_W, LEG_LEN - 0.1, LEG_W)
		var shin := Node3D.new()
		shin.position.y = -(LEG_LEN - 0.1) * 0.5
		pivot.add_child(shin)
		_mesh_piece(shin, leg, LEG_COLOR, outline_color, team, &"outline")
		# The boot: a slightly larger, lighter block with a low toe stepping out in front.
		var boot := BoxMesh.new()
		boot.size = Vector3(LEG_W + 0.025, 0.15, LEG_W + 0.02)
		var foot := Node3D.new()
		foot.position = Vector3(0.0, -LEG_LEN + 0.075, 0)
		pivot.add_child(foot)
		_mesh_piece(foot, boot, BOOT_COLOR, outline_color, team, &"outline")
		var toe := BoxMesh.new()
		toe.size = Vector3(0.06, 0.055, LEG_W + 0.02)
		var toe_at := Node3D.new()
		toe_at.position = Vector3((LEG_W + 0.025) * 0.5 + 0.025, -LEG_LEN + 0.0275, 0)
		pivot.add_child(toe_at)
		_mesh_piece(toe_at, toe, BOOT_COLOR, outline_color, team, &"outline")
		legs.append(pivot)
	_pose(0.0)
	_rebuild_cloak()


## Reads the player's state after a sim tick.
func sync(reader: WorldReader) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.player_pos(),
			"aim": reader.aim_angle(),
			"dashing": reader.is_dashing(),
			"swing_t": reader.swing_tick(),
			"swing_ticks": reader.swing_ticks(),
			"swing_angle": reader.swing_angle(),
			"combo": reader.combo_step(),
			"guarding": reader.guarding(),
			"dead": reader.player_dead(),
		}
	)


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
	_aim_yaw = SimPlane.yaw_of(s["aim"])
	_dashing = s["dashing"]
	_guarding = s["guarding"]
	_dead = s["dead"]
	var st: int = s["swing_t"]
	_swing = 0.0
	if st > 0:
		_swing = clampf(float(st) / maxf(1.0, float(s["swing_ticks"])), 0.0, 1.0)
		_aim_yaw = SimPlane.yaw_of(s["swing_angle"])
		_swing_dir = 1.0 if int(s["combo"]) % 2 == 0 else -1.0
	if _fresh:
		_fresh = false
		_body_yaw = _aim_yaw
		_leg_yaw = _aim_yaw
		_pose(0.0)
		_reset_springs()


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation and the cloak springs by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or hood == null:
		return
	_t += dt
	var v3 := Vector3(_vel.x, 0, -_vel.y)
	var prev_vel := _vel_s
	_vel_s = _vel_s.lerp(v3, _rate(14.0, dt))
	var accel := (_vel_s - prev_vel) / dt
	accel = accel.limit_length(80.0)
	_dash = move_toward(_dash, 1.0 if _dashing else 0.0, dt * (14.0 if _dashing else 4.0))
	_crouch = lerpf(_crouch, 1.0 if _guarding else 0.0, _rate(12.0, dt))
	_slump = move_toward(_slump, 1.0 if _dead else 0.0, dt * (2.2 if _dead else 4.0))
	_pose(dt)
	_step_springs(dt, accel)
	_rebuild_cloak()


## Largest distance of a cloak spring from its rest target (0 when the cloak has settled).
func cloak_offset() -> float:
	var worst := 0.0
	for k in _spring_pos.size():
		worst = maxf(worst, _spring_pos[k].distance_to(_spring_target[k]))
	return worst


## Mean horizontal spread of the cloak's flare ring around its centre, in metres.
func cloak_flare() -> float:
	var centre := Vector3.ZERO
	for k in CLOAK_SIDES:
		centre += _spring_pos[k]
	centre /= CLOAK_SIDES
	var sum := 0.0
	for k in CLOAK_SIDES:
		var d := _spring_pos[k] - centre
		sum += Vector2(d.x, d.z).length()
	return sum / CLOAK_SIDES


## The poncho's hem points (diamond corners and the fold points between them) in this node's frame: the front
## corner first, then round through the body's right. A copy; tests read the shape through it.
func cloak_hem() -> Array[Vector3]:
	return _spring_pos.duplicate()


## 0 standing, 1 fully collapsed.
func slump_amount() -> float:
	return _slump


## The head's current yaw (radians, SimPlane.yaw_of convention), where the visor looks.
func body_yaw() -> float:
	return _body_yaw + _twist


func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


func _turn_toward(from: float, to: float, k: float) -> float:
	return from + wrapf(to - from, -PI, PI) * k


func _pose(dt: float) -> void:
	var speed := Vector2(_vel_s.x, _vel_s.z).length()
	var walk_target := 0.0 if _dashing or _dead else clampf(speed / WALK_SPEED, 0.0, 1.0)
	_walk = lerpf(_walk, walk_target, _rate(10.0, dt))
	# Head: toward the aim, quick; a swing winds back then whips through toward the swing.
	var twist_target := 0.0
	if _swing > 0.0:
		twist_target = _swing_dir * lerpf(-0.75, 0.5, smoothstep(0.0, 0.55, _swing))
	_twist = lerpf(_twist, twist_target, _rate(30.0, dt))
	if not _dead:
		_body_yaw = _turn_toward(_body_yaw, _aim_yaw, _rate(16.0, dt))
	# Legs and cloak: toward the movement; walking backwards keeps them facing the aim and backpedals.
	var back := 1.0
	var leg_target := _body_yaw
	if speed > 0.4 and not _dead:
		var move_yaw := atan2(-_vel_s.z, _vel_s.x)
		leg_target = move_yaw
		if absf(wrapf(move_yaw - _body_yaw, -PI, PI)) > deg_to_rad(110.0):
			leg_target = move_yaw + PI
			back = -1.0
	_leg_yaw = _turn_toward(_leg_yaw, leg_target, _rate(10.0, dt))
	_phase += back * speed * dt * TAU / STRIDE * (1.0 - _dash)
	# Pelvis: bob, breath, crouch, slump.
	var s := sin(_phase)
	var bob := (1.0 - absf(s)) * 0.035 * _walk
	var breath := sin(_t * 2.1) * 0.009 * (1.0 - _walk) * (1.0 - _slump)
	var hip := HIP_Y + bob + breath - _crouch * 0.07 - _slump * 0.22
	_pelvis.position = Vector3(0, hip, 0)
	# Lean: into the movement (hard on a dash), forward when guarding or collapsing, a slow idle sway.
	var face_dir := Vector3(cos(_body_yaw), 0, -sin(_body_yaw))
	var move_dir := Vector3.ZERO if speed < 0.01 else Vector3(_vel_s.x, 0, _vel_s.z) / speed
	var side := Vector3(face_dir.z, 0, -face_dir.x)
	var lean_target := (
		move_dir * (0.16 * clampf(speed / WALK_SPEED, 0.0, 1.0) * (1.0 - _dash) + 0.32 * _dash)
		+ face_dir * (_crouch * 0.12 + _slump * 0.22)
		+ side * sin(_t * 1.1) * 0.02 * (1.0 - _walk)
	)
	_lean = _lean.lerp(lean_target, _rate(9.0, dt))
	var b := Basis.IDENTITY
	if _lean.length() > 0.0001:
		b = Basis(Vector3.UP.cross(_lean.normalized()), _lean.length())
	_pelvis.basis = b
	_head_yaw.rotation = Vector3(0, _body_yaw + _twist, 0)
	# Dead: the hood droops forward and rolls to one side on top of the pooled cloak.
	hood.rotation = Vector3(_slump * 0.15, 0, -HOOD_TILT - _slump * 0.2 - _crouch * 0.08)
	_visor_mat.emission_energy_multiplier = lerpf(2.4, 0.35, _slump)
	# Legs: alternate stride, tucked on a dash, stretched forward when sitting dead, splayed when the hips drop
	# below what the swung leg can reach.
	_leg_root.position.y = hip
	_leg_root.rotation = Vector3(0, _leg_yaw, 0)
	var amp := 0.6 * _walk
	for k in legs.size():
		var sgn := -1.0 if k == 0 else 1.0
		var swing := s * amp * sgn + _dash * (0.35 if k == 0 else -0.75) + _slump * 1.25
		var reach := LEG_LEN * cos(swing)
		var splay := acos(clampf(hip / maxf(reach, 0.01), -1.0, 1.0)) if hip < reach else 0.0
		legs[k].rotation = Vector3(sgn * splay, 0, swing)


func _build_cloak_rest() -> void:
	# Ring order: front, front-right, right, back-right, back, back-left, left, front-left (+Z is the right).
	# Neck ring (fixed to the body): the V-neck notch under the chin, then up the shoulders under the hood's rim.
	var neck := [
		Vector3(0.19, 0.57, 0.0),
		Vector3(0.12, 0.7, 0.14),
		Vector3(0.0, 0.82, 0.2),
		Vector3(-0.12, 0.83, 0.15),
		Vector3(-0.18, 0.83, 0.0),
	]
	# Hem ring (springs): the four diamond corners, each pair joined through a fold point a little inside the
	# straight edge, so every side reads as two big flat facets.
	var corners := [
		Vector3(HEM_FRONT.x, HEM_FRONT.y, 0.0),
		Vector3(0.0, HEM_SIDE.y, HEM_SIDE.x),
		Vector3(-HEM_BACK.x, HEM_BACK.y, 0.0),
	]
	var hem: Array[Vector3] = [corners[0], Vector3.ZERO, corners[1], Vector3.ZERO, corners[2]]
	for k in [1, 3]:
		var mid: Vector3 = (hem[k - 1] + hem[k + 1]) * 0.5
		hem[k] = Vector3(mid.x * 0.9, mid.y + 0.02, mid.z * 0.9)
	for j in CLOAK_SIDES:
		# Mirror the right half (0..4) onto the left (5..7).
		var m := j if j <= 4 else CLOAK_SIDES - j
		var flip := 1.0 if j <= 4 else -1.0
		var n: Vector3 = neck[m]
		var h: Vector3 = hem[m]
		_top_rest.append(Vector3(n.x, n.y - HIP_Y, n.z * flip))
		_spring_rest.append(Vector3(h.x, h.y - HIP_Y, h.z * flip))
		_spring_pos.append(Vector3.ZERO)
		_spring_vel.append(Vector3.ZERO)
		_spring_target.append(Vector3.ZERO)


func _cloak_frame() -> Transform3D:
	# The front corner and the V-neck point where the wanderer faces, under the hood; a swing twists them a little.
	var yaw := Basis(Vector3.UP, _body_yaw + _twist * 0.35)
	return Transform3D(_pelvis.basis * yaw, _pelvis.position)


func _update_targets() -> void:
	var xf := _cloak_frame()
	var speed := Vector2(_vel_s.x, _vel_s.z).length()
	var flare := (
		1.0
		+ 0.06 * clampf(speed / WALK_SPEED, 0.0, 1.0)
		+ 0.3 * _dash
		+ 0.08 * _crouch
		+ 0.3 * _slump
	)
	var m := flare * (1.0 + sin(_t * 2.1) * 0.012 * (1.0 - _slump))
	for k in _spring_rest.size():
		var r := _spring_rest[k]
		_spring_target[k] = xf * Vector3(r.x * m, r.y - 0.1 * _slump, r.z * m)


func _reset_springs() -> void:
	_update_targets()
	for k in _spring_pos.size():
		_spring_pos[k] = _spring_target[k]
		_spring_vel[k] = Vector3.ZERO


func _step_springs(dt: float, accel: Vector3) -> void:
	_update_targets()
	var n := ceili(dt / SUB_STEP)
	var h := dt / n
	# In this (non-rotating) frame the body's acceleration acts on the cloak as an opposite force, and the air
	# the wanderer moves through drags the cloak back.
	var push := -accel * INERTIA - _vel_s * AIR_DRAG * (1.0 + _dash)
	for _i in n:
		for k in _spring_pos.size():
			var a := (
				(_spring_target[k] - _spring_pos[k]) * SPRING_K - _spring_vel[k] * SPRING_C + push
			)
			_spring_vel[k] += a * h
			_spring_pos[k] += _spring_vel[k] * h
			var off := _spring_pos[k] - _spring_target[k]
			if off.length() > MAX_OFFSET:
				_spring_pos[k] = _spring_target[k] + off.limit_length(MAX_OFFSET)
				_spring_vel[k] *= 0.5


func _rebuild_cloak() -> void:
	var xf := _cloak_frame()
	var top: Array[Vector3] = []
	for r in _top_rest:
		# Dead, the shoulders sink into the pooled cloak.
		top.append(xf * Vector3(r.x, r.y * (1.0 - 0.35 * _slump), r.z))
	var ring: Array[Vector3] = []
	for k in _spring_pos.size():
		var p := _spring_pos[k]
		var off := p - _spring_target[k]
		# A hanging cloth swung sideways rises: lift by the horizontal offset (a pendulum, roughly).
		p.y += Vector2(off.x, off.z).length_squared() * 1.6
		p.y = maxf(p.y, 0.03)
		ring.append(p)
	var centre := xf * Vector3(0, 0.62 - HIP_Y, 0)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in CLOAK_SIDES:
		var j2 := (j + 1) % CLOAK_SIDES
		_tri2(verts, normals, colors, [top[j], top[j2], ring[j]], 2, centre)
		_tri2(verts, normals, colors, [top[j2], ring[j2], ring[j]], 1, centre)
	# A dark collar across the neck ring, both ways round: looking into the V-neck from a 3/4 view shows shadow,
	# not the poncho's lit inside.
	var mid := Vector3.ZERO
	for p in top:
		mid += p
	mid /= top.size()
	var up := xf.basis.y.normalized()
	for j in CLOAK_SIDES:
		var j2 := (j + 1) % CLOAK_SIDES
		verts.append_array([mid, top[j], top[j2], mid, top[j2], top[j]])
		normals.append_array([up, up, up, -up, -up, -up])
		for _k in 6:
			colors.append(NECK_SHADE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	_cloak_mesh.clear_surfaces()
	_cloak_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## One poncho facet, both sides: the outside in cream, the underside (wound the other way) in the shaded cream,
## darkening to near-black at the neck (the first `tops` points of t), so the inside never shows as a light sliver
## between the hood and the shoulders.
static func _tri2(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	t: Array,
	tops: int,
	centre: Vector3
) -> void:
	var n0 := verts.size()
	_tri(verts, normals, t[0], t[1], t[2], centre)
	var a := verts[n0]
	var b := verts[n0 + 1]
	var c := verts[n0 + 2]
	var n := normals[n0]
	# A centimetre inside, so the two sides never share a depth (no shadow acne between them).
	var d := -n * 0.01
	verts.append_array([a + d, c + d, b + d])
	normals.append_array([-n, -n, -n])
	colors.append_array([CLOAK_COLOR, CLOAK_COLOR, CLOAK_COLOR])
	for v in [a, c, b]:
		var at_neck := false
		for k in tops:
			at_neck = at_neck or v.is_equal_approx(t[k])
		colors.append(NECK_SHADE if at_neck else UNDER_COLOR)


## Appends one flat-shaded triangle facing away from `centre` (Godot's front faces wind clockwise).
static func _tri(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	centre: Vector3
) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	verts.append_array([a, c, b])
	normals.append_array([n, n, n])


static func _mesh_from(tris: Array, centre: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		_tri(verts, normals, t[0], t[1], t[2], centre)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## The hood: a six-sided box, narrow at the top, widest at a belt a little below the middle and bevelled in under
## it, that tapers slightly toward the open front; under the face its bottom is cut back. Closed at the back; the
## dark face sits in the front opening. +X is the front; the node tips it forward.
static func _hood_mesh() -> ArrayMesh:
	var back := _hood_ring(-HOOD_HALF_LEN, 1.0)
	var front := _hood_ring(HOOD_HALF_LEN, HOOD_FRONT_SCALE)
	# Under the face the hood's bottom stops short of the front, so the face's point hangs clear of it.
	for k in [3, 4]:
		front[k].x -= 0.12
	var n := back.size()
	var tris := []
	for k in n:
		var k2 := (k + 1) % n
		tris.append([back[k], back[k2], front[k2]])
		tris.append([back[k], front[k2], front[k]])
	for k in range(1, n - 1):
		tris.append([back[0], back[k], back[k + 1]])
	return _mesh_from(tris, Vector3(0, 0.0, 0))


## The hood's cross-section at depth x, scaled about its middle by s. Order: top-left, top-right, belt right, bottom
## right, bottom left, belt left (+Z is the right).
static func _hood_ring(x: float, s: float) -> Array:
	var pts := [
		Vector3(x, 0.16, -0.1),
		Vector3(x, 0.16, 0.1),
		Vector3(x, -0.04, 0.22),
		Vector3(x, -0.13, 0.15),
		Vector3(x, -0.13, -0.15),
		Vector3(x, -0.04, -0.22),
	]
	var out := []
	for p: Vector3 in pts:
		out.append(Vector3(x, HOOD_MID_Y + (p.y - HOOD_MID_Y) * s, p.z * s))
	return out


## The dark face: a shield (flat top, sides down to the hood's belt, then a point at the chin) set back inside the
## hood's front opening. Its point hangs below the hood, so a small dark wedge behind it gives the chin depth.
static func _face_mesh() -> ArrayMesh:
	var ring := _hood_ring(FACE_X, HOOD_FRONT_SCALE * 0.97)
	var tl: Vector3 = ring[0]
	var tr: Vector3 = ring[1]
	var br: Vector3 = ring[2]
	var bl: Vector3 = ring[5]
	var chin := Vector3(FACE_X, CHIN_Y, 0)
	var tris := [[tl, tr, br], [tl, br, bl], [bl, br, chin]]
	var mesh := _mesh_from(tris, Vector3(-1, -0.02, 0))
	var back := Vector3(FACE_X - 0.14, -0.12, 0)
	var wedge := [[br, chin, back], [bl, back, chin]]
	var wm := _mesh_from(wedge, Vector3(FACE_X - 0.05, -0.05, 0))
	var arrays := wm.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The face and visor mark the stencil like the body pieces do, so the hood's X-ray twin behind them stays hidden.
static func _write_stencil(m: StandardMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


func _mesh_piece(
	parent: Node3D, mesh: Mesh, c: Color, outline: Color, team: Color, technique: StringName
) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = OUTLINE_M
	ActorViews.flashable(mat)  # the hit flash changes only parameters, never the shader
	body.material_override = mat
	parent.add_child(body)
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
	return body
