class_name AvatarBase
extends Node3D
## What the stand-alone creature avatars share (audit P-1): the player's and the Charger, Warden, Needle, Arc Caster,
## Bomb Drone and horde models. The bosses have their own base (BossAvatar) and parts library (BossParts).
## Presentation only (EI-07): each avatar's sync() reads the sim through WorldReader once per tick, advance() animates
## in frame time, and nothing here feeds back into the sim. Each avatar keeps its own advance() and pose.

## Faster than this many ticks between two syncs is a gap, not motion (the velocity is dropped).
const MOTION_GAP_TICKS := 30

## The outlined body materials (ActorViews flashes them on a hit).
var body_materials: Array[StandardMaterial3D] = []
# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
# Frame time since the model was built (seconds).
var _t := 0.0


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time (each avatar its own).
func advance(_delta: float) -> void:
	pass


## The share of the way to a target an exponential ease covers in `dt` at `per_second`.
func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


## The velocity (m/s) from the last sync's position to `pos` at `tick`: zero after a teleport (faster than
## `teleport_speed`), a long gap or a rewind; then remembers this tick and position.
func _track_motion(tick: int, pos: Vector2, teleport_speed: float) -> void:
	if not _fresh and tick > _last_tick:
		var v := (pos - _last_pos) * (60.0 / float(tick - _last_tick))
		_vel = (
			v
			if v.length() <= teleport_speed and tick - _last_tick <= MOTION_GAP_TICKS
			else Vector2.ZERO
		)
	elif tick < _last_tick:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos


## One outlined, flashable body piece under `parent` (its material in body_materials), and with technique "xray"
## its enemy-coloured silhouette twin. Unlike BossParts.piece, the vertex colours are not the albedo unless asked.
func _outlined(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	outline: Color,
	team: Color,
	technique: StringName,
	outline_m: float,
	vertex_colors := false,
	piece_name := ""
) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	if not piece_name.is_empty():
		piece.name = piece_name
	piece.mesh = mesh
	piece.position = at
	var mat := outline_material(c, outline, outline_m)
	if vertex_colors:
		mat.vertex_color_use_as_albedo = true
	piece.material_override = mat
	parent.add_child(piece)
	body_materials.append(ActorViews.flashable(mat))
	if technique == &"xray":
		xray_twin(parent, mesh, c, team, at)
	return piece


## An opaque body material with the stencil outline.
static func outline_material(c: Color, outline: Color, outline_m: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = outline_m
	return mat


## A body piece's X-ray twin: the same mesh a little smaller, drawn in the team colour where walls hide it.
static func xray_twin(
	parent: Node3D, mesh: Mesh, c: Color, team: Color, at: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
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
	return ghost


## A face, visor or glow marks the stencil like the body pieces do, so the X-ray twins behind it stay hidden.
static func write_stencil(m: StandardMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


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


## Flat-shaded triangles of a solid around `centre`, each turned to face away from it (Godot's front faces wind
## clockwise); degenerate ones are dropped.
static func flat_mesh(tris: Array, centre: Vector3) -> ArrayMesh:
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
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
