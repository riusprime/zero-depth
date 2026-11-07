class_name LaserPackTube
extends Node3D
## v0.11.0 VX (owner PD-13, 2026-11-07: "VFX have to match the style of the premade assets"): the Laser lance drawn with
## the pack's laser (beam_vfx: laser_vfx_01..06, beam_vfx_07 for venom; PackLooks.laser_id). The pack scene is one
## straight cylinder, so a bent or Homing lance was "7-8 overlapping straight laser segments" (v0.10.0 FX); here the
## scene's own materials (BeamCore's beam_core shader, BeamOuter's scrolling beam_outer shader, the BeamStart and
## BeamEnd balls' beam_ball shader), recoloured to the element, are laid on one tube through the sim's points (one
## strip, so a curve has no joints). LaserView draws it out over the lance's 0.15 s and fades it by 0.5 s (its emission
## and its width). Presentation only (EI-07). The owner's sketch (PLAN X2) may still change the look.

## Sides round the tube.
const SIDES := 10
## The pack's core and outer shaders mask their cylinder's UV.y past ~0.5 (their "open" sweep): the tube spans this.
const UV_SPAN := 0.45

## The scene the materials came from (tests), and whether they were found.
var scene_path := ""
var ok := false
var _core := MeshInstance3D.new()
var _outer := MeshInstance3D.new()
var _start := MeshInstance3D.new()
var _end := MeshInstance3D.new()
var _emission := {}  # material -> its scene emission


func _init() -> void:
	name = "LaserPackTube"
	for m: MeshInstance3D in [_core, _outer, _start, _end]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
	_core.mesh = ImmediateMesh.new()
	_outer.mesh = ImmediateMesh.new()


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
	_tube(_core.mesh as ImmediateMesh, pts, total, core_r)
	_outer.visible = outer_r > core_r
	if _outer.visible:
		_tube(_outer.mesh as ImmediateMesh, pts, total, outer_r)
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


## A closed tube of radius `r` through `pts` (outward faces, clockwise seen from outside: Godot's front).
static func _tube(im: ImmediateMesh, pts: Array[Vector3], total: float, r: float) -> void:
	im.clear_surfaces()
	var rings: Array = []
	var run := 0.0
	for i in pts.size():
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n1 := t.cross(Vector3.UP)
		if n1.length_squared() < 0.01:
			n1 = t.cross(Vector3.RIGHT)
		n1 = n1.normalized()
		var n2 := n1.cross(t).normalized()
		var ring: Array[Vector3] = []
		for j in SIDES + 1:
			var a := TAU * float(j) / SIDES
			ring.append(n1 * cos(a) + n2 * sin(a))
		rings.append([pts[i], ring, run / total * UV_SPAN])
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var p0: Vector3 = rings[i][0]
		var p1: Vector3 = rings[i + 1][0]
		var r0: Array[Vector3] = rings[i][1]
		var r1: Array[Vector3] = rings[i + 1][1]
		var v0: float = rings[i][2]
		var v1: float = rings[i + 1][2]
		for j in SIDES:
			var u0 := float(j) / SIDES
			var u1 := float(j + 1) / SIDES
			# A (i, j), B (i+1, j), C (i, j+1), D (i+1, j+1): triangles A C B and B C D
			_v(im, p0, r0[j], r, u0, v0)
			_v(im, p0, r0[j + 1], r, u1, v0)
			_v(im, p1, r1[j], r, u0, v1)
			_v(im, p1, r1[j], r, u0, v1)
			_v(im, p0, r0[j + 1], r, u1, v0)
			_v(im, p1, r1[j + 1], r, u1, v1)
	im.surface_end()


static func _v(im: ImmediateMesh, p: Vector3, d: Vector3, r: float, u: float, v: float) -> void:
	im.surface_set_normal(d)
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(p + d * r)
