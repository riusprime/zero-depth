class_name ArcCasterAvatar
extends Node3D
## The Arc Caster (v0.3.5 AI, owner F5): a low-poly spellcaster in the enemy sheet's red and grey. A tall faceted red
## robe (an octagonal frustum) under grey pauldrons, a dark hood with a glowing red slit visor, a grey staff held out
## in front with a hostile-yellow arc crystal at its tip, and three red rune shards that orbit the hood. The staff
## rises through a windup and the crystal and shards brighten with it; a cast kicks the staff forward.
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time, and nothing here feeds back into the sim. ActorViews puts it under the actor's facing node: +X is the front.

## The robe: hem radius, shoulder radius, height; the hood's centre height; the model's height (for the health bar).
const HEM_R := 0.36
const SHOULDER_R := 0.2
const ROBE_H := 0.92
const HOOD_Y := 1.06
const HEIGHT := 1.24
## The staff: its grip's offset from the centre, its length, and the crystal's size.
const STAFF_AT := Vector3(0.22, 0.62, 0.2)
const STAFF_LEN := 0.9
const CRYSTAL := 0.11
## The windup the glow is paced for (data/enemies/arc_caster.tres: the bolt's 0.5 s). Cosmetic only.
const WINDUP_TICKS := 30
const OUTLINE_M := 0.02

const RED := Color("#D8433A")
const RED_DARK := Color("#A9302B")
const GREY := Color("#5F5551")
const DARK := Color("#24272D")
const EYE := Color("#FF2A22")

## Parts, read by tests and by ActorViews (flash materials; the visor, crystal and shards glow on their own).
var body: Node3D
var staff: Node3D
var crystal: MeshInstance3D
var shards: Array[Node3D] = []
var body_materials: Array[StandardMaterial3D] = []

var _eye_mat := StandardMaterial3D.new()
var _glow_mat := StandardMaterial3D.new()
var _orbit := Node3D.new()
var _fresh := true
var _last_tick := -1
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _t := 0.0
var _rise := 0.0
var _charge := 0.0
var _kick := 0.0


func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var team := ThemePalette.color(&"enemy_body")
	body = Node3D.new()
	add_child(body)
	_piece(
		body,
		_frustum(HEM_R, SHOULDER_R, ROBE_H, 8),
		Vector3.ZERO,
		RED,
		outline_color,
		team,
		technique
	)
	# A darker hem band and the grey pauldrons.
	_piece(
		body,
		_frustum(HEM_R + 0.02, HEM_R - 0.03, 0.12, 8),
		Vector3.ZERO,
		RED_DARK,
		outline_color,
		team,
		&"outline"
	)
	var pauldron := NeedleAvatar._chamfer_box(Vector3(0.16, 0.1, 0.16), 0.03, 0.01)
	for side in [-1.0, 1.0]:
		_piece(
			body,
			pauldron,
			Vector3(0.0, ROBE_H - 0.02, side * 0.2),
			GREY,
			outline_color,
			team,
			technique
		)
	# The hood: a dark faceted box tipped forward, a red cowl over it, the slit visor in front.
	var hood := Node3D.new()
	hood.position = Vector3(0.0, HOOD_Y, 0.0)
	hood.rotation = Vector3(0, 0, -0.18)
	body.add_child(hood)
	_piece(
		hood,
		NeedleAvatar._chamfer_box(Vector3(0.22, 0.24, 0.22), 0.04, 0.012),
		Vector3.ZERO,
		DARK,
		outline_color,
		team,
		technique
	)
	_piece(
		hood,
		_frustum(0.17, 0.02, 0.24, 6),
		Vector3(-0.03, 0.04, 0.0),
		RED,
		outline_color,
		team,
		&"outline"
	)
	_eye_mat.albedo_color = EYE
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE
	_eye_mat.emission_energy_multiplier = 2.0
	NeedleAvatar._write_stencil(_eye_mat)
	var slit := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.01, 0.035, 0.15)
	slit.mesh = sb
	slit.material_override = _eye_mat
	slit.position = Vector3(0.115, -0.01, 0.0)
	slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hood.add_child(slit)
	# The staff, its grip at the right hand, the crystal at its tip.
	staff = Node3D.new()
	staff.position = STAFF_AT
	body.add_child(staff)
	_piece(
		staff,
		NeedleAvatar._chamfer_box(Vector3(0.05, STAFF_LEN, 0.05), 0.01),
		Vector3(0, STAFF_LEN * 0.3, 0),
		GREY,
		outline_color,
		team,
		&"outline"
	)
	var hot := ThemePalette.color(&"proj_hostile")
	_glow_mat.albedo_color = hot
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.emission_enabled = true
	_glow_mat.emission = hot
	_glow_mat.emission_energy_multiplier = 1.0
	crystal = MeshInstance3D.new()
	crystal.mesh = _octahedron(CRYSTAL)
	crystal.material_override = _glow_mat
	crystal.position = Vector3(0, STAFF_LEN * 0.8 + CRYSTAL, 0)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staff.add_child(crystal)
	# The orbiting rune shards.
	_orbit.position = Vector3(0, HOOD_Y, 0)
	body.add_child(_orbit)
	for k in 3:
		var holder := Node3D.new()
		holder.rotation = Vector3(0, TAU * k / 3.0, 0)
		_orbit.add_child(holder)
		var shard := MeshInstance3D.new()
		shard.mesh = _octahedron(0.06)
		shard.material_override = _eye_mat
		shard.position = Vector3(0.34, 0, 0)
		shard.scale = Vector3(0.6, 1.4, 0.6)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(shard)
		shards.append(shard)
	_pose(0.0)


func sync(reader: WorldReader, i: int) -> void:
	apply_state({"tick": reader.tick(), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	_last_tick = tick
	if _fresh or state != _state:
		if state == WorldReader.STATE_ACTIVE:
			_kick = 1.0
		_state = state
		_state_tick = tick
	_ticks_in = tick - _state_tick
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.8))
	var target := 0.0
	if _state == WorldReader.STATE_WINDUP:
		target = clampf(float(_ticks_in) / WINDUP_TICKS, 0.0, 1.0)
	_charge = lerpf(_charge, target, 1.0 - exp(-(14.0 if target > _charge else 4.0) * dt))
	_kick = move_toward(_kick, 0.0, dt * 4.0)
	_pose(dt)


## The crystal's current glow (emission energy).
func crystal_energy() -> float:
	return _glow_mat.emission_energy_multiplier


## How far the staff is raised (radians of pitch, 0 at rest).
func staff_raise() -> float:
	return -staff.rotation.z


func _pose(_dt: float) -> void:
	var sway := sin(_t * 1.6) * 0.015
	body.position = Vector3(0, sway - (1.0 - _rise) * 1.1, 0)
	body.rotation = Vector3(sin(_t * 1.1) * 0.02, 0, -_kick * 0.08)
	# The staff tips forward and up as the cast builds, and snaps out on the cast.
	staff.rotation = Vector3(0, 0, -(_charge * 0.9 + _kick * 0.5))
	_glow_mat.emission_energy_multiplier = 1.0 + _charge * 5.0 + _kick * 4.0
	_eye_mat.emission_energy_multiplier = (2.0 + _charge * 3.0) * lerpf(0.2, 1.0, _rise)
	_orbit.rotation = Vector3(0, _t * (1.4 + _charge * 7.0), 0)
	for k in shards.size():
		shards[k].position.y = sin(_t * 2.0 + k * 2.1) * 0.05 + _charge * 0.08


func _piece(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	outline: Color,
	team: Color,
	technique: StringName
) -> void:
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
	body_materials.append(ActorViews.flashable(mat))
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


## A flat-shaded `sides`-sided frustum standing on the origin: radius r0 at the bottom, r1 at height h.
static func _frustum(r0: float, r1: float, h: float, sides: int) -> ArrayMesh:
	var tris := []
	var c := Vector3(0, h * 0.5, 0)
	for k in sides:
		var a0 := TAU * (k + 0.5) / sides
		var a1 := TAU * (k + 1.5) / sides
		var b0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
		tris.append([b0, b1, t1])
		tris.append([b0, t1, t0])
		tris.append([Vector3.ZERO, b1, b0])
		tris.append([Vector3(0, h, 0), t0, t1])
	return _mesh_around(tris, c)


## A flat-shaded octahedron of half-size r (the crystal and the shards).
static func _octahedron(r: float) -> ArrayMesh:
	var tris := []
	var pts := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 4]
		tris.append([a, b, Vector3(0, r * 1.4, 0)])
		tris.append([a, b, Vector3(0, -r * 1.4, 0)])
	return _mesh_around(tris, Vector3.ZERO)


## Flat-shaded triangles of a convex solid around `c`, each turned to face away from it.
static func _mesh_around(tris: Array, c: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d: Vector3 = t[2]
		var n := (b - a).cross(d - a)
		if n.length_squared() < 1e-12:
			continue
		if n.dot((a + b + d) / 3.0 - c) < 0.0:
			var tmp := b
			b = d
			d = tmp
			n = -n
		n = n.normalized()
		verts.append_array([a, d, b])
		normals.append_array([n, n, n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
