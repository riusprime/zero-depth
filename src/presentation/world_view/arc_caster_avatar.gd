class_name ArcCasterAvatar
extends AvatarBase
## v0.11.0 F6: the Arc Caster's body is the Cinder Priest's model now (CinderPriestAvatar, in its own palette), so this
## class no longer draws anything. It stays as the shared shape kit the other code-made bodies call: the flat-shaded
## frustum and octahedron.


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
	return flat_mesh(tris, c)


## A flat-shaded octahedron of half-size r (the crystal and the shards).
static func _octahedron(r: float) -> ArrayMesh:
	var tris := []
	var pts := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 4]
		tris.append([a, b, Vector3(0, r * 1.4, 0)])
		tris.append([a, b, Vector3(0, -r * 1.4, 0)])
	return flat_mesh(tris, Vector3.ZERO)
