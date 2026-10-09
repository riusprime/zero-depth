class_name AttackFormMeshes
extends RefCounted
## v0.6.0 MX3: the shared meshes and materials the attack forms are drawn with (AttackFormView's MultiMesh pools).
## Built once per run of the game and reused by every pool, so no effect compiles a shader on its first use (the
## v0.2.0 H rule) and nothing toggles a material feature at runtime (the damage-lag rule, PRESENTATION §7).
##
## Materials follow the A3 audit's rule (ART_DIRECTION §4): a flash of light is additive (unshaded, added, its
## colour above 1 feeds the scene's glow, so it sits in the v0.5.9 light like the fire does, not as a flat sheet);
## matter is lit by the scene (the lob's bomb shell). The per-instance colour (MultiMesh colours) multiplies the
## mesh's vertex colour, which carries each mesh's falloff (a disc bright at the centre, a ring bright at its rim).

static var _meshes := {}
static var _glow: StandardMaterial3D
static var _lit: StandardMaterial3D


## The additive light material (unshaded, added, no depth write, both faces, no shadow).
static func glow() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_glow.vertex_color_use_as_albedo = true
		_glow.disable_receive_shadows = true
	return _glow


## The lit material for matter (the bomb's shell): shaded by the scene's light, coloured per instance.
static func lit() -> StandardMaterial3D:
	if _lit == null:
		_lit = StandardMaterial3D.new()
		_lit.vertex_color_use_as_albedo = true
		_lit.roughness = 0.55
		_lit.metallic = 0.35
	return _lit


## A mesh by name: &"quad" (1 × 1 on the floor plane, centred, +X long), &"dart" (an octahedron 1 long on +X),
## &"disc" (radius 1, bright centre), &"patch" (radius 1, bright rim), &"ring" (an annulus 0.86..1, bright outer
## edge), &"band" (a raised ring wall, radius 1, 1 tall), &"shard" (a thin prism), &"bomb" (a faceted ball),
## &"spark" (a small box).
static func mesh(id: StringName) -> Mesh:
	if not _meshes.has(id):
		_meshes[id] = _build(id)
	return _meshes[id]


static func _build(id: StringName) -> Mesh:
	match id:
		&"quad":
			return _quad()
		&"dart":
			return _dart()
		&"disc":
			return _disc(1.0, 0.15)
		&"patch":
			return _disc(0.3, 1.0)
		&"ring":
			return _ring(0.86, 1.0)
		&"band":
			return _band()
		&"shard":
			return _shard()
		&"bomb":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 4
			return s
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


static func _surface(prim: int, verts: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(prim, arrays)
	return m


static func _quad() -> ArrayMesh:
	var v := PackedVector3Array(
		[
			Vector3(-0.5, 0, -0.5),
			Vector3(0.5, 0, -0.5),
			Vector3(0.5, 0, 0.5),
			Vector3(-0.5, 0, -0.5),
			Vector3(0.5, 0, 0.5),
			Vector3(-0.5, 0, 0.5),
		]
	)
	var c := PackedColorArray()
	for k in 6:
		c.append(Color.WHITE)
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)


## A dart: tip at +0.5, tail at −0.5, a diamond section; the tail end fades so it reads as a streak.
static func _dart() -> ArrayMesh:
	var tip := Vector3(0.5, 0, 0)
	var tail := Vector3(-0.5, 0, 0)
	var ring := [
		Vector3(0.1, 0.5, 0), Vector3(0.1, 0, 0.5), Vector3(0.1, -0.5, 0), Vector3(0.1, 0, -0.5)
	]
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for k in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 4]
		v.append_array([tip, a, b, tail, b, a])
		c.append_array(
			[Color.WHITE, Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.15), Color.WHITE, Color.WHITE]
		)
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)


## A disc of radius 1 on the floor plane: alpha `centre` in the middle, `rim` at the edge (a radial falloff).
static func _disc(centre: float, rim: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := 32
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		v.append_array([Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1), 0, sin(a1))])
		c.append_array([Color(1, 1, 1, centre), Color(1, 1, 1, rim), Color(1, 1, 1, rim)])
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)


## An annulus from `inner` to `outer` (radius 1 = outer), bright at the outer edge, clear at the inner one.
static func _ring(inner: float, outer: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := 48
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var i0 := Vector3(cos(a0), 0, sin(a0)) * inner
		var i1 := Vector3(cos(a1), 0, sin(a1)) * inner
		var o0 := Vector3(cos(a0), 0, sin(a0)) * outer
		var o1 := Vector3(cos(a1), 0, sin(a1)) * outer
		var ci := Color(1, 1, 1, 0.0)
		v.append_array([i0, o0, o1, i0, o1, i1])
		c.append_array([ci, Color.WHITE, Color.WHITE, ci, Color.WHITE, ci])
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)


## A ring wall of radius 1 from y = 0 to y = 1: bright at the foot, clear at the top (the light rising off a front).
static func _band() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := 48
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var b0 := Vector3(cos(a0), 0, sin(a0))
		var b1 := Vector3(cos(a1), 0, sin(a1))
		var t0 := b0 + Vector3.UP
		var t1 := b1 + Vector3.UP
		var top := Color(1, 1, 1, 0.0)
		v.append_array([b0, t0, t1, b0, t1, b1])
		c.append_array([Color.WHITE, top, top, Color.WHITE, top, Color.WHITE])
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)


## A thin three-sided prism 1 long on +Y, for frost shards and crackle.
static func _shard() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var base := [Vector3(0.5, -0.5, 0), Vector3(-0.25, -0.5, 0.43), Vector3(-0.25, -0.5, -0.43)]
	var top := Vector3(0, 0.5, 0)
	for k in 3:
		var a: Vector3 = base[k]
		var b: Vector3 = base[(k + 1) % 3]
		v.append_array([a, b, top])
		c.append_array([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.6)])
	return _surface(Mesh.PRIMITIVE_TRIANGLES, v, c)
