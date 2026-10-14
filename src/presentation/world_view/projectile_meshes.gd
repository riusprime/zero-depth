class_name ProjectileMeshes
extends RefCounted
## v0.8.0 AV (owner O8: "actual 3D objects in the game that look and feel like the game's art"): the code-made
## meshes of the hostile fireballs (FireballViews) and their noise. One unit across, the flight along +x; built once
## and shared. Faceted where the look is stone or crystal (flat normals, the kit's low-poly style), smooth where it is
## liquid or plasma. Textures are procedural (owner Q5 allows CC0 downloads; the session's network blocked the CC0
## sites, so nothing is downloaded): one seamless noise the shaders swirl.
## Presentation only (EI-07).

static var _cache := {}
static var _noise: NoiseTexture2D


## The mesh of shape `id`: &"rock", &"gem", &"spear", &"orb", &"glob", &"drop", &"crescent" (v0.8.0 FB3: a flying
## slash, bowed forward across its flight), or &"ribbon" (the trail strip).
static func get_mesh(id: StringName) -> Mesh:
	if not _cache.has(id):
		_cache[id] = _build(id)
	return _cache[id]


## A seamless 128 px simplex noise (grey), shared by the fireball, trail and spike shaders.
static func noise() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.fractal_octaves = 3
		n.seed = 7
		var t := NoiseTexture2D.new()
		t.width = 128
		t.height = 128
		t.seamless = true
		t.generate_mipmaps = true
		t.noise = n
		_noise = t
	return _noise


static func _build(id: StringName) -> Mesh:
	match id:
		&"rock":
			return _rock()
		&"gem":
			return _bipyramid(6, 0.62, 1.0, 1.0, 0.0)
		&"spear":
			return _bipyramid(4, 0.5, 1.7, 0.75, PI * 0.25)
		&"drop":
			return _drop()
		&"glob":
			return _sphere(14, 7)
		&"ribbon":
			return _ribbon()
		&"crescent":
			return _crescent()
	return _sphere(16, 8)


## v0.8.0 FB3: a flying slash: a thin curved blade bowed forward (+x) across its flight, its horns trailing back.
static func _crescent() -> ArrayMesh:
	var n := 10
	var top := []
	var bot := []
	for k in n + 1:
		var a := lerpf(-1.2, 1.2, float(k) / n)
		var thick := 0.32 * (1.0 - absf(a) / 1.35)
		var outer := Vector3(cos(a) * 0.8 - 0.3, 0.0, sin(a) * 1.0)
		var inner := Vector3(cos(a) * (0.8 - thick) - 0.3, 0.0, sin(a) * (1.0 - thick * 0.6))
		top.append([outer + Vector3(0, 0.06, 0), inner + Vector3(0, 0.06, 0)])
		bot.append([outer - Vector3(0, 0.06, 0), inner - Vector3(0, 0.06, 0)])
	var tris := []
	for k in n:
		var t0: Array = top[k]
		var t1: Array = top[k + 1]
		var b0: Array = bot[k]
		var b1: Array = bot[k + 1]
		tris.append([t0[0], t1[0], t1[1]])
		tris.append([t0[0], t1[1], t0[1]])
		tris.append([b0[0], b1[1], b1[0]])
		tris.append([b0[0], b0[1], b1[1]])
		tris.append([t0[0], b0[0], b1[0]])
		tris.append([t0[0], b1[0], t1[0]])
		tris.append([t0[1], t1[1], b1[1]])
		tris.append([t0[1], b1[1], b0[1]])
	return AvatarBase.flat_mesh(tris, Vector3.ZERO)


## A faceted chunk of stone: an icosahedron with its corners pushed in and out (fixed, so every stone is the same
## shape; the shader turns each one differently).
static func _rock() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var v := [
		Vector3(-1, t, 0),
		Vector3(1, t, 0),
		Vector3(-1, -t, 0),
		Vector3(1, -t, 0),
		Vector3(0, -1, t),
		Vector3(0, 1, t),
		Vector3(0, -1, -t),
		Vector3(0, 1, -t),
		Vector3(t, 0, -1),
		Vector3(t, 0, 1),
		Vector3(-t, 0, -1),
		Vector3(-t, 0, 1),
	]
	for k in v.size():
		v[k] = (v[k] as Vector3).normalized() * (0.78 + 0.3 * VfxCore.h(k, 41))
	var faces := [
		[0, 11, 5],
		[0, 5, 1],
		[0, 1, 7],
		[0, 7, 10],
		[0, 10, 11],
		[1, 5, 9],
		[5, 11, 4],
		[11, 10, 2],
		[10, 7, 6],
		[7, 1, 8],
		[3, 9, 4],
		[3, 4, 2],
		[3, 2, 6],
		[3, 6, 8],
		[3, 8, 9],
		[4, 9, 5],
		[2, 4, 11],
		[6, 2, 10],
		[8, 6, 7],
		[9, 8, 1],
	]
	var tris := []
	for f: Array in faces:
		tris.append([v[f[0]], v[f[1]], v[f[2]]])
	return AvatarBase.flat_mesh(tris, Vector3.ZERO)


## A `sides`-sided double pyramid along x: the front point `front` ahead, the back point `back` behind, the waist
## `r` round, turned `turn` about x (a gem; a spear head when long in front).
static func _bipyramid(sides: int, r: float, front: float, back: float, turn: float) -> ArrayMesh:
	var ring := []
	for k in sides:
		var a := turn + TAU * k / sides
		ring.append(Vector3(0, cos(a) * r, sin(a) * r))
	var tris := []
	for k in sides:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % sides]
		tris.append([a, b, Vector3(front, 0, 0)])
		tris.append([a, b, Vector3(-back, 0, 0)])
	return AvatarBase.flat_mesh(tris, Vector3.ZERO)


static func _sphere(radial: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = radial
	s.rings = rings
	return s


## A drop of molten metal: a sphere whose back is drawn out to a point (it flies head first, +x).
static func _drop() -> ArrayMesh:
	var arrays := _sphere(14, 7).get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for k in verts.size():
		var p := verts[k]
		if p.x < 0.0:
			var u := -p.x  # 0 at the waist .. 1 at the back
			p = Vector3(-u * 1.9, p.y * (1.0 - 0.75 * u * u), p.z * (1.0 - 0.75 * u * u))
			normals[k] = (normals[k] + Vector3(-0.3 * u, 0, 0)).normalized()
		verts[k] = p
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## The trail strip: x -0.5 (tail) .. 0.5 (head), y across; UV.x 0 at the tail, 1 at the head. The trail shader turns
## it to face the camera about its own length and tapers it.
static func _ribbon() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var segs := 4
	for k in segs:
		var x0 := -0.5 + float(k) / segs
		var x1 := -0.5 + float(k + 1) / segs
		for p: Vector2 in [
			Vector2(x0, -0.5),
			Vector2(x1, -0.5),
			Vector2(x1, 0.5),
			Vector2(x0, -0.5),
			Vector2(x1, 0.5),
			Vector2(x0, 0.5)
		]:
			verts.append(Vector3(p.x, p.y, 0))
			uvs.append(Vector2(p.x + 0.5, p.y + 0.5))
			normals.append(Vector3(0, 0, 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.custom_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.2, 1.2))
	return m
