class_name PlayerAvatar
extends Node3D
## The player's hooded wanderer (owner, 2026-10-07; docs/art/main_character_visual_reference.png): a big faceted
## box hood with a low pyramid roof, a recessed dark face and a small off-centre cyan visor; a tent-shaped cloak
## (a square frustum, corners on the diagonals, a soft vertical fold down the middle of each side); two short
## charcoal legs. Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance()
## animates in frame time, and nothing here feeds back into the sim. The cloak's hem points are damped springs in
## this node's frame (which never rotates), so they lag behind acceleration and turns, stream back on a dash and
## settle when the wanderer stops.
## +X is the front in every local frame; the sim (x, y) maps to 3D (x, h, -y) as in SimPlane.

const HIP_Y := 0.4
const LEG_LEN := 0.41
const LEG_GAP := 0.09
const NECK_Y := 0.95
const SHOULDER_Y := 0.76
## Hem points: four corners (on the diagonals) and the four fold points between them.
const CLOAK_SIDES := 8
const HEM_Y := 0.4
const HEM_R := 0.44
## The hood is a little smaller than its mesh, sits a little forward and tips forward, as in the reference.
const HOOD_SCALE := 0.92
const HOOD_TILT := 0.26
## The avatar's rim is thinner than the other actors' (the reference has a light line, not a heavy one).
const OUTLINE_M := 0.018
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

const CLOAK_COLOR := Color("#E9E4DA")
const HOOD_COLOR := Color("#EFEBE3")
const FACE_COLOR := Color("#121217")
const LEG_COLOR := Color("#4A4C56")
const BOOT_COLOR := Color("#34343B")

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
	hood.position = Vector3(0.015, NECK_Y - HIP_Y, 0)
	hood.scale = Vector3.ONE * HOOD_SCALE
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
	vb.size = Vector3(0.012, 0.1, 0.08)
	visor.mesh = vb
	_visor_mat.albedo_color = team
	_visor_mat.emission_enabled = true
	_visor_mat.emission = team
	_visor_mat.emission_energy_multiplier = 2.4
	_write_stencil(_visor_mat)
	visor.material_override = _visor_mat
	visor.position = Vector3(0.178, 0.02, 0.045)
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hood.add_child(visor)
	_build_cloak_rest()
	cloak = _mesh_piece(self, _cloak_mesh, CLOAK_COLOR, outline_color, team, technique)
	(cloak.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_leg_root.position.y = HIP_Y
	add_child(_leg_root)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0, side * LEG_GAP)
		_leg_root.add_child(pivot)
		var leg := BoxMesh.new()
		leg.size = Vector3(0.1, LEG_LEN - 0.05, 0.085)
		var shin := Node3D.new()
		shin.position.y = -(LEG_LEN - 0.05) * 0.5
		pivot.add_child(shin)
		_mesh_piece(shin, leg, LEG_COLOR, outline_color, team, &"outline")
		var boot := BoxMesh.new()
		boot.size = Vector3(0.15, 0.06, 0.095)
		var foot := Node3D.new()
		foot.position = Vector3(0.025, -LEG_LEN + 0.03, 0)
		pivot.add_child(foot)
		_mesh_piece(foot, boot, BOOT_COLOR, outline_color, team, &"outline")
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
	# Corners on the diagonals (a tent seen corner-on from 3/4 views, as in the reference), and between them a
	# point a little proud of the straight edge: a soft vertical fold down the middle of each side. The hem is
	# nearly level, a few centimetres uneven.
	var drop := [0.0, 0.0, 0.02, 0.0, -0.015, 0.0, 0.01, 0.0]
	for j in CLOAK_SIDES:
		var a := TAU * (float(j) + 1.0) / CLOAK_SIDES
		var corner := j % 2 == 0
		var top_r := 0.2 if corner else 0.15
		var hem_r := HEM_R if corner else HEM_R * 0.76
		_top_rest.append(Vector3(cos(a) * top_r, SHOULDER_Y - HIP_Y, -sin(a) * top_r))
		var y: float = HEM_Y + (0.0 if corner else 0.025) + drop[j]
		_spring_rest.append(Vector3(cos(a) * hem_r, y - HIP_Y, -sin(a) * hem_r))
		_spring_pos.append(Vector3.ZERO)
		_spring_vel.append(Vector3.ZERO)
		_spring_target.append(Vector3.ZERO)


func _cloak_frame() -> Transform3D:
	var yaw := Basis(Vector3.UP, _leg_yaw + _twist * 0.35)
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
	var centre := xf * Vector3(0, (SHOULDER_Y + HEM_Y) * 0.5 - HIP_Y, 0)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for j in CLOAK_SIDES:
		var j2 := (j + 1) % CLOAK_SIDES
		_tri(verts, normals, top[j], top[j2], ring[j], centre)
		_tri(verts, normals, top[j2], ring[j2], ring[j], centre)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	_cloak_mesh.clear_surfaces()
	_cloak_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


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


## The hood: a box whose lower sides and back taper in (the rounded look of the reference), under a low
## four-faced roof whose peak sits a little toward the back. The front is open; the dark face sits in it.
static func _hood_mesh() -> ArrayMesh:
	var lo := [
		Vector3(0.2, -0.2, -0.16),
		Vector3(0.2, -0.2, 0.16),
		Vector3(-0.15, -0.2, 0.16),
		Vector3(-0.15, -0.2, -0.16)
	]
	var mid := [
		Vector3(0.2, -0.07, -0.2),
		Vector3(0.2, -0.07, 0.2),
		Vector3(-0.2, -0.07, 0.2),
		Vector3(-0.2, -0.07, -0.2)
	]
	var hi := [
		Vector3(0.2, 0.15, -0.2),
		Vector3(0.2, 0.15, 0.2),
		Vector3(-0.19, 0.14, 0.19),
		Vector3(-0.19, 0.14, -0.19)
	]
	var peak := Vector3(-0.09, 0.21, 0.0)
	var tris := []
	for k in 4:
		var k2 := (k + 1) % 4
		if k != 0:
			for pair in [[lo, mid], [mid, hi]]:
				var a: Array = pair[0]
				var b: Array = pair[1]
				tris.append([a[k], a[k2], b[k2]])
				tris.append([a[k], b[k2], b[k]])
		tris.append([hi[k], hi[k2], peak])
	tris.append([lo[0], lo[1], lo[2]])
	tris.append([lo[0], lo[2], lo[3]])
	return _mesh_from(tris, Vector3(0, 0, 0))


## The dark face: a plate set 3 cm back inside the hood's open front, filling the opening.
static func _face_mesh() -> ArrayMesh:
	var x := 0.17
	var pts := [
		Vector3(x, -0.2, -0.16),
		Vector3(x, -0.2, 0.16),
		Vector3(x, -0.07, 0.195),
		Vector3(x, 0.145, 0.195),
		Vector3(x, 0.145, -0.195),
		Vector3(x, -0.07, -0.195)
	]
	var tris := []
	for k in range(1, pts.size() - 1):
		tris.append([pts[0], pts[k], pts[k + 1]])
	return _mesh_from(tris, Vector3(0, -0.03, 0))


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
