extends RefCounted
## The hero's poncho as triangles (PlayerAvatar rebuilds its cloak mesh from these every frame): from the neck ring's
## points `top` and the hem's `ring` (PlayerAvatar.CLOAK_SIDES each), per side two facets with both faces, then a dark
## collar across the neck ring. Written in place into arrays of their final size, with no temporary array per point.

const SIDES := PlayerAvatar.CLOAK_SIDES
## Per side two facets of both faces (12 vertices), then the collar's two triangles (6).
const VERTS := SIDES * 18
const NECK_SHADE := PlayerAvatar.NECK_SHADE


## The mesh arrays (Mesh.ARRAY_MAX long: vertices, normals, colours) of the poncho round `centre`, the collar's
## normal `up`, the outside in `cloak`, the underside in `under`.
static func arrays(
	top: Array[Vector3],
	ring: Array[Vector3],
	centre: Vector3,
	up: Vector3,
	cloak: Color,
	under: Color
) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(VERTS)
	normals.resize(VERTS)
	colors.resize(VERTS)
	var i := 0
	var vs := [verts, normals, colors]
	for j in SIDES:
		var j2 := (j + 1) % SIDES
		i = _facet(vs, i, top[j], top[j2], ring[j], 2, centre, cloak, under)
		i = _facet(vs, i, top[j2], ring[j2], ring[j], 1, centre, cloak, under)
	# The collar, both ways round: looking into the V-neck from a 3/4 view shows shadow, not the poncho's lit inside.
	var mid := Vector3.ZERO
	for p in top:
		mid += p
	mid /= top.size()
	var down := -up
	for j in SIDES:
		var j2 := (j + 1) % SIDES
		verts[i] = mid
		verts[i + 1] = top[j]
		verts[i + 2] = top[j2]
		verts[i + 3] = mid
		verts[i + 4] = top[j2]
		verts[i + 5] = top[j]
		for k in 3:
			normals[i + k] = up
			normals[i + 3 + k] = down
		for k in 6:
			colors[i + k] = NECK_SHADE
		i += 6
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	return out


## One facet of the points `t0`, `t1`, `t2` at `i` of the arrays `vs` (vertices, normals, colours; returns the next
## free index), both sides: the outside (in `cloak`) faces away from `centre` (AvatarBase._tri's winding and normal);
## the underside, wound the other way a centimetre inside, in `under`, darkening to near-black at the neck (the first
## `tops` of the points), so the inside never shows as a light sliver between the hood and the shoulders.
static func _facet(
	vs: Array,
	i: int,
	t0: Vector3,
	t1: Vector3,
	t2: Vector3,
	tops: int,
	centre: Vector3,
	cloak: Color,
	under: Color
) -> int:
	var verts: PackedVector3Array = vs[0]
	var normals: PackedVector3Array = vs[1]
	var colors: PackedColorArray = vs[2]
	var a := t0
	var b := t1
	var e := t2
	var n := (b - a).cross(e - a)
	if n.dot((a + b + e) / 3.0 - centre) < 0.0:
		var sw := b
		b = e
		e = sw
		n = -n
	n = n.normalized()
	verts[i] = a
	verts[i + 1] = e
	verts[i + 2] = b
	# (no shared depth between the two sides: no shadow acne between them)
	var d := -n * 0.01
	verts[i + 3] = a + d
	verts[i + 4] = b + d
	verts[i + 5] = e + d
	var back := -n
	for k in 3:
		normals[i + k] = n
		normals[i + 3 + k] = back
		colors[i + k] = cloak
	colors[i + 3] = NECK_SHADE if _at_neck(a, tops, t0, t1) else under
	colors[i + 4] = NECK_SHADE if _at_neck(b, tops, t0, t1) else under
	colors[i + 5] = NECK_SHADE if _at_neck(e, tops, t0, t1) else under
	return i + 6


## Whether `v` is one of a facet's first `tops` (1 or 2) points `t0`, `t1`.
static func _at_neck(v: Vector3, tops: int, t0: Vector3, t1: Vector3) -> bool:
	return v.is_equal_approx(t0) or (tops > 1 and v.is_equal_approx(t1))
