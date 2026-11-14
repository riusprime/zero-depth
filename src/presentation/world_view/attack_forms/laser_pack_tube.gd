class_name LaserPackTube
extends Node3D
## The Laser lance drawn with
## the pack's laser (beam_vfx: laser_vfx_01..06, beam_vfx_07 for venom; PackLooks.laser_id). The pack scene is one
## straight cylinder, so a bent or Homing lance was "7-8 overlapping straight laser segments"; here the
## scene's own materials (BeamCore's beam_core shader, BeamOuter's scrolling beam_outer shader, the BeamStart and
## BeamEnd balls' beam_ball shader), recoloured to the element, are laid on one tube through the sim's points (one
## strip, so a curve has no joints). LaserView draws it out over the lance's 0.15 s and fades it by 0.5 s (its emission
## and its width). Presentation only (EI-07). The owner's sketch (PLAN X2) may still change the look.

## Sides round the tube.
const SIDES := 10
## A lance that has stopped changing but for its radius rebuilds its mesh when the radius has moved this
## much
## (per mille of the radius it was built at): the glow's thinning is many small steps, the steps don't show.
const REBUILD_PERMILLE := 60
## The pack's core and outer shaders mask their cylinder's UV.y past ~0.5 (their "open" sweep): the tube spans this.
const UV_SPAN := 0.45

## The ring's unit circle, once.
static var _ring_x := PackedFloat32Array()
static var _ring_y := PackedFloat32Array()

## The scene the materials came from (tests), and whether they were found.
var scene_path := ""
var ok := false
## How many times lay() rebuilt the meshes (the tests read it).
var rebuilds := 0
var _core := MeshInstance3D.new()
var _outer := MeshInstance3D.new()
var _start := MeshInstance3D.new()
var _end := MeshInstance3D.new()
var _emission := {}  # material -> its scene emission
## What the meshes were last built from (lay()): their points' count and ends, and the radii.
var _built_n := 0
var _built_ends := [Vector3.ZERO, Vector3.ZERO]
var _built_core := 0.0
var _built_outer := 0.0


func _init() -> void:
	name = "LaserPackTube"
	for m: MeshInstance3D in [_core, _outer, _start, _end]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
	_core.mesh = ArrayMesh.new()
	_outer.mesh = ArrayMesh.new()


## Takes the pack scene's materials and ball meshes (an instance made and freed at once), in `colors`.
func setup(path: String, scene: PackedScene, colors: Dictionary) -> void:
	scene_path = path
	ok = false
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	var core := inst.get_node_or_null("BeamPivot/BeamScalor/BeamCore") as MeshInstance3D
	var outer := inst.get_node_or_null("BeamPivot/BeamScalor/BeamOuter") as MeshInstance3D
	var start := inst.get_node_or_null("BeamStart") as MeshInstance3D
	var end := inst.get_node_or_null("BeamEndPivot/BeamEnd") as MeshInstance3D
	if core != null and outer != null and start != null and end != null:
		_core.material_override = _own(core.material_override, colors)
		_outer.material_override = _own(outer.material_override, colors)
		_start.material_override = _own(start.material_override, colors)
		_end.material_override = _own(end.material_override, colors)
		_start.mesh = start.mesh
		_end.mesh = end.mesh
		ok = (
			_core.material_override != null
			and _outer.material_override != null
			and _start.material_override != null
			and _end.material_override != null
		)
	inst.free()


func _own(m: Material, colors: Dictionary) -> ShaderMaterial:
	var s := m as ShaderMaterial
	if s == null:
		return null
	s = s.duplicate() as ShaderMaterial
	for k: StringName in [&"primary", &"secondary", &"tertiary"]:
		if colors.has(k):
			s.set_shader_parameter(StringName("%s_color" % k), colors[k])
	_emission[s] = float(s.get_shader_parameter(&"emission"))
	return s


## The tube along `pts` (this node's space), its core `core_r` and its scrolling outer `outer_r` thick, at `glow` (0..1)
## of the scene's emission; the start ball at the first point (`start_s` its scale, 0 hides it), the end ball at the
## last (`end_s`, 0 hides it).
func lay(
	pts: Array[Vector3], core_r: float, outer_r: float, glow: float, start_s: float, end_s: float
) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var show := ok and pts.size() >= 2 and total >= 0.01 and glow > 0.0
	visible = show
	for m: MeshInstance3D in [_core, _outer, _start, _end]:
		m.visible = show
	if not show:
		return
	_outer.visible = outer_r > core_r
	if _stale(pts, core_r, outer_r):
		rebuilds += 1
		_built_n = pts.size()
		_built_ends = [pts[0], pts[pts.size() - 1]]
		_built_core = core_r
		_built_outer = outer_r
		_tube(_core.mesh as ArrayMesh, pts, total, core_r)
		if _outer.visible:
			_tube(_outer.mesh as ArrayMesh, pts, total, outer_r)
	if _outer.visible:
		(_outer.material_override as ShaderMaterial).set_shader_parameter(&"beam_length", total)
	for m: MeshInstance3D in [_core, _outer, _start, _end]:
		var mat := m.material_override as ShaderMaterial
		mat.set_shader_parameter(&"emission", float(_emission.get(mat, 4.0)) * glow)
	_start.visible = start_s > 0.0
	_start.position = pts[0]
	_start.scale = Vector3.ONE * maxf(start_s, 0.001)
	_end.visible = end_s > 0.0
	_end.position = pts[pts.size() - 1]
	_end.scale = Vector3.ONE * maxf(end_s, 0.001)


## Hides the tube.
func off() -> void:
	visible = false


## The meshes no longer match: other points (while the lance draws out, or a new shot) or a radius that has
## moved REBUILD_PERMILLE (the lance only thins after it is drawn).
func _stale(pts: Array[Vector3], core_r: float, outer_r: float) -> bool:
	if pts.size() != _built_n or pts[0] != _built_ends[0] or pts[pts.size() - 1] != _built_ends[1]:
		return true
	var step := REBUILD_PERMILLE / 1000.0
	return (
		absf(core_r - _built_core) > step * _built_core
		or absf(outer_r - _built_outer) > step * _built_outer
	)


## A closed tube of radius `r` through `pts` (outward faces, clockwise seen from outside: Godot's front), as one indexed
## surface. the owner's "every time it shoots the game lags a bit": it was an ImmediateMesh of three
## calls a
## vertex and six vertices a quad; the rings now share their vertices, and the arrays are filled in one pass.
static func _tube(mesh: ArrayMesh, pts: Array[Vector3], total: float, r: float) -> void:
	if _ring_x.is_empty():
		for j in SIDES + 1:
			var a := TAU * float(j) / SIDES
			_ring_x.append(cos(a))
			_ring_y.append(sin(a))
	var n := pts.size()
	var stride := SIDES + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * stride)
	norms.resize(n * stride)
	uvs.resize(n * stride)
	var run := 0.0
	var v := 0
	for i in n:
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n1 := t.cross(Vector3.UP)
		if n1.length_squared() < 0.01:
			n1 = t.cross(Vector3.RIGHT)
		n1 = n1.normalized()
		var n2 := n1.cross(t).normalized()
		var along := run / total * UV_SPAN
		for j in stride:
			var d := n1 * _ring_x[j] + n2 * _ring_y[j]
			verts[v] = pts[i] + d * r
			norms[v] = d
			uvs[v] = Vector2(float(j) / SIDES, along)
			v += 1
	var idx := PackedInt32Array()
	idx.resize((n - 1) * SIDES * 6)
	var at := 0
	for i in n - 1:
		for j in SIDES:
			# A (i, j), B (i+1, j), C (i, j+1), D (i+1, j+1): triangles A C B and B C D
			var a := i * stride + j
			var b := a + stride
			idx[at] = a
			idx[at + 1] = a + 1
			idx[at + 2] = b
			idx[at + 3] = b
			idx[at + 4] = a + 1
			idx[at + 5] = b + 1
			at += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
