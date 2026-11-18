class_name JudgeGearMesh
extends RefCounted
## The Clockwork Judge's stopped gear, the wall its Time Wave leaves standing: the gear at its own waist (dark iron, a
## gold hub round a hexagonal axle) grown to a wall's size, since the model's own gear is a small toothless ring that
## would read as a blob that big. Chamfered iron teeth on a gold rim, a raised gold band on each face, six spokes and a
## gold hexagonal hub; flat-shaded faces in the Judge's colours (vertex colours, one opaque surface lit by the room's
## light like its model and the walls, so the ink pass outlines it). Radius 1 at the teeth's tips in the XY plane, 1
## thick along Z (nothing stands past that, so it is never wider than the wall it draws).

## The Judge's own colours, read off its model's texture at the gear (dark iron, and the gold of its hub and trim),
## a step lighter so the stage's sun still shows the faces on a dark floor.
const IRON := JudgeViews.IRON
const IRON_LIGHT := Color("#7A6656")
const GOLD := JudgeViews.BRASS
const TEETH := 12
const RIM_IN := 0.64
const RIM_OUT := 0.84
const SPOKES := 6

static var _mesh: ArrayMesh = null
static var _mat: StandardMaterial3D = null


## The gear (built once).
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var b := _Builder.new()
	var step := TAU / float(TEETH)
	b.annulus(RIM_IN, RIM_OUT, 0.44, TEETH * 3, IRON, GOLD)
	b.annulus(0.66, 0.8, 0.5, TEETH * 3, GOLD)
	for k in TEETH:
		var a := step * float(k)
		var tooth := PackedVector2Array(
			[
				_polar(a - step * 0.24, 0.82),
				_polar(a - step * 0.13, 1.0),
				_polar(a + step * 0.13, 1.0),
				_polar(a + step * 0.24, 0.82),
			]
		)
		b.prism(tooth, 0.5, 0.13, 0.78, IRON_LIGHT if k % 2 == 0 else IRON)
	for k in SPOKES:
		var a := TAU * (float(k) + 0.5) / float(SPOKES)
		var d := Vector2(cos(a), sin(a))
		var side := Vector2(-d.y, d.x) * 0.07
		var spoke := PackedVector2Array(
			[d * 0.22 - side, d * 0.68 - side, d * 0.68 + side, d * 0.22 + side]
		)
		b.prism(spoke, 0.32, 0.06, 0.8, IRON)
	b.prism(_hexagon(0.28), 0.46, 0.09, 0.78, GOLD)
	b.prism(_hexagon(0.1), 0.5, 0.02, 0.9, IRON)
	_mesh = b.commit()
	return _mesh


## The gear's material: its vertex colours, lit like the game's own models and walls (lit()).
static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	_mat = lit(Color.WHITE)
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	return _mat


## A matte material lit by the room's light the way the game's models, walls and kit props are (EnemyLooks.body():
## roughness 1, metallic 0, specular 0.5, Burley diffuse), with no light of its own; the ink pass outlines it.
static func lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.5
	return m


static func _polar(a: float, r: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


static func _hexagon(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 6:
		out.append(_polar(TAU * float(k) / 6.0, r))
	return out


## Flat-shaded triangles with colours, each wound to face its given outward direction (Godot's front faces wind
## clockwise).
class _Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, col: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		if n.dot(outward) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
		colors.append_array([col, col, col])

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, col: Color) -> void:
		tri(a, b, c, outward, col)
		tri(a, c, d, outward, col)

	## A flat ring from radius r0 to r1, `h` either side of z = 0, in `segs` flat sides; its outer face in `rim`
	## (alpha 0: `col` too).
	func annulus(
		r0: float, r1: float, h: float, segs: int, col: Color, rim := Color(0, 0, 0, 0)
	) -> void:
		var outer := rim if rim.a > 0.0 else col
		for k in segs:
			var a0 := TAU * float(k) / float(segs)
			var a1 := TAU * float(k + 1) / float(segs)
			var d0 := Vector3(cos(a0), sin(a0), 0.0)
			var d1 := Vector3(cos(a1), sin(a1), 0.0)
			var mid := (d0 + d1).normalized()
			var zh := Vector3(0, 0, h)
			quad(d0 * r1 - zh, d1 * r1 - zh, d1 * r1 + zh, d0 * r1 + zh, mid, outer)
			quad(d0 * r0 - zh, d1 * r0 - zh, d1 * r0 + zh, d0 * r0 + zh, -mid, col)
			for z: float in [h, -h]:
				var o := Vector3(0, 0, z)
				quad(
					d0 * r0 + o, d1 * r0 + o, d1 * r1 + o, d0 * r1 + o, Vector3(0, 0, signf(z)), col
				)

	## A convex outline extruded `h` either side of z = 0, its edges chamfered `bevel` deep: the caps are the outline
	## drawn in toward its middle to `inset` of its size.
	func prism(
		outline: PackedVector2Array, h: float, bevel: float, inset: float, col: Color
	) -> void:
		var c := Vector2.ZERO
		for p in outline:
			c += p
		c /= float(outline.size())
		var rings: Array[PackedVector3Array] = []
		for level: Array in [[-h, inset], [-h + bevel, 1.0], [h - bevel, 1.0], [h, inset]]:
			var ring := PackedVector3Array()
			for p in outline:
				var q := c + (p - c) * float(level[1])
				ring.append(Vector3(q.x, q.y, float(level[0])))
			rings.append(ring)
		var centre := Vector3(c.x, c.y, 0.0)
		var n := outline.size()
		for r in 3:
			for k in n:
				var a := rings[r][k]
				var b := rings[r][(k + 1) % n]
				var d := rings[r + 1][(k + 1) % n]
				var e := rings[r + 1][k]
				quad(a, b, d, e, (a + b + d + e) * 0.25 - centre, col)
		for r: int in [0, 3]:
			var mid := Vector3(c.x, c.y, rings[r][0].z)
			for k in n:
				tri(mid, rings[r][k], rings[r][(k + 1) % n], Vector3(0, 0, signf(mid.z)), col)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
