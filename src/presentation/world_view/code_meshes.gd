class_name CodeMeshes
extends RefCounted
## The code-built low-poly shapes the code-made bodies and props are put together from (chamfered boxes, joint-pin
## prisms), flat-shaded, each shape built once and shared by every avatar that asks for the same one, so a spawn builds
## and uploads none (building them was most of a code-built enemy's spawn). NeedleAvatar keeps the names the other
## avatars call them by.

## The chamfered boxes and prisms made so far, by their sizes.
static var _chamfered := {}


## A box with bevelled edges and cut corners, centred on the origin, flat-shaded. With `bulge` each of the six faces
## is a shallow pyramid whose centre stands that far out, so its four triangles catch the light differently. Shared:
## nobody changes the mesh it returns.
static func chamfer_box(size: Vector3, bevel: float, bulge: float = 0.0) -> ArrayMesh:
	var key := [size, bevel, bulge]
	if not _chamfered.has(key):
		_chamfered[key] = build_chamfer_box(size, bevel, bulge)
	return _chamfered[key]


static func build_chamfer_box(size: Vector3, bevel: float, bulge: float) -> ArrayMesh:
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
	return mesh_from(tris)


## A flat-shaded prism along Z (a joint pin): `sides` sides of circumradius r, `length` long, centred. Shared like
## chamfer_box's.
static func prism(r: float, length: float, sides: int) -> ArrayMesh:
	var key := [&"prism", r, length, sides]
	if not _chamfered.has(key):
		_chamfered[key] = build_prism(r, length, sides)
	return _chamfered[key]


static func build_prism(r: float, length: float, sides: int) -> ArrayMesh:
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
	return mesh_from(tris)


## Flat-shaded triangles of a convex solid around the origin: each faces away from it (Godot's front faces wind
## clockwise).
static func mesh_from(tris: Array) -> ArrayMesh:
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
