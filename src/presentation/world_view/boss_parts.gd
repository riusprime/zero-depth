class_name BossParts
extends RefCounted
## Shared builders for the boss models (v0.3.0 C; docs/art/first-three-bosses-concept.png): low-poly faceted
## pieces with flat-shaded facets tinted a little lighter or darker each (vertex colours), so the planes read apart
## as on the sheet. Every body piece gets an outlined, flashable material (ActorViews.flashable: emission on at
## energy 0, so a hit flash never swaps a shader) and, with the X-ray technique, a silhouette twin. Glowing parts
## (visors, cracks, eggs, muzzles) are emissive and mark the stencil like the body, so their twins stay hidden.
## Presentation only; the meshes are fixed (an integer hash, no RNG).

const FACET_TINT := 0.14

var body_materials: Array[StandardMaterial3D] = []
var glow_materials: Array[StandardMaterial3D] = []
var _outline := Color.BLACK
var _technique := &"xray"
var _outline_m := 0.03


func _init(outline_color: Color, technique: StringName, outline_m: float = 0.03) -> void:
	_outline = outline_color
	_technique = technique
	_outline_m = outline_m


## One body piece under `parent`: the mesh at `at` (rotation `rot` in radians, `scl`), outlined and flashable.
func piece(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	rot: Vector3 = Vector3.ZERO,
	scl: Vector3 = Vector3.ONE,
	piece_name: String = ""
) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	if not piece_name.is_empty():
		body.name = piece_name
	body.mesh = mesh
	body.position = at
	body.rotation = rot
	body.scale = scl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = _outline
	mat.stencil_outline_thickness = _outline_m
	mat.vertex_color_use_as_albedo = mesh is ArrayMesh
	body.material_override = mat
	parent.add_child(body)
	body_materials.append(ActorViews.flashable(mat))
	if _technique == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(ThemePalette.color(&"enemy_body"), 0.85)
		ghost.material_override = gm
		ghost.position = at
		ghost.rotation = rot
		ghost.scale = scl * 0.96
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
	return body


## A glowing piece (unshaded, emissive). Its material is kept in glow_materials; animate its energy only.
func glow(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	energy: float,
	rot: Vector3 = Vector3.ZERO,
	scl: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = at
	n.rotation = rot
	n.scale = scl
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	glow_materials.append(m)
	return n


# --- meshes ---------------------------------------------------------------------------------------------------


## A fixed pseudo-random value in [0, 1) from an integer.
static func noise(n: int) -> float:
	var h := (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(h & 0xFFFF) / 65536.0


## A loft: `section` (unit points round the Y axis, (x, z)) placed at each level [y, scale_x, scale_z, shift_x],
## all scaled by `size`; the side bands and both caps are closed. `wobble` nudges each vertex by a fixed amount.
static func loft(
	section: PackedVector2Array, levels: Array, size: Vector3, salt: int, wobble: float = 0.0
) -> ArrayMesh:
	var rings: Array = []
	for k in levels.size():
		var lv: Array = levels[k]
		var shift: float = lv[3] if lv.size() > 3 else 0.0
		var ring: Array[Vector3] = []
		for j in section.size():
			var h := salt * 97 + k * 13 + j * 5
			var w := 1.0 + (noise(h) - 0.5) * wobble
			var p := section[j]
			ring.append(
				Vector3(
					(p.x * lv[1] * w + shift) * size.x,
					(lv[0] + (noise(h + 2) - 0.5) * wobble * 0.3) * size.y,
					p.y * lv[2] * w * size.z
				)
			)
		rings.append(ring)
	var tris := []
	var n := section.size()
	for k in rings.size() - 1:
		var a: Array[Vector3] = rings[k]
		var b: Array[Vector3] = rings[k + 1]
		for j in n:
			var j2 := (j + 1) % n
			tris.append([a[j], a[j2], b[j2]])
			tris.append([a[j], b[j2], b[j]])
	var bottom: Array[Vector3] = rings[0]
	var top: Array[Vector3] = rings[rings.size() - 1]
	var bc := Vector3.ZERO
	var tc := Vector3.ZERO
	for j in n:
		bc += bottom[j] / n
		tc += top[j] / n
	for j in n:
		var j2 := (j + 1) % n
		tris.append([bc, bottom[j], bottom[j2]])
		tris.append([tc, top[j], top[j2]])
	var centre := Vector3(0, (float(levels[0][0]) + float(levels[levels.size() - 1][0])) * 0.5, 0)
	return mesh_from(tris, centre * Vector3(1, size.y, 1), salt)


## A regular polygon section with `sides` points, turned by half a step if `half`.
static func ngon(sides: int, half: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in sides:
		var a := TAU * (float(j) + (0.5 if half else 0.0)) / sides
		out.append(Vector2(cos(a), sin(a)))
	return out


## A chunky faceted boulder: a rounded 7-sided block, its rings turned and nudged so the facets break unevenly.
static func rock(size: Vector3, salt: int) -> ArrayMesh:
	var levels := [
		[-0.5, 0.22, 0.22],
		[-0.4, 0.42, 0.42],
		[-0.18, 0.5, 0.5],
		[0.14, 0.5, 0.5],
		[0.36, 0.42, 0.42],
		[0.5, 0.2, 0.2],
	]
	var sec := PackedVector2Array()
	for j in 7:
		var a := TAU * (float(j) + noise(salt * 7 + j) * 0.5) / 7.0
		sec.append(Vector2(cos(a), sin(a)))
	return loft(sec, levels, size, salt, 0.2)


## A chamfered box (an octagon section with bevelled top and bottom): armour plates, hulls, feet.
static func block(size: Vector3, salt: int, bevel: float = 0.18) -> ArrayMesh:
	var s := PackedVector2Array()
	var e := 0.5 - bevel * 0.5
	for p in [
		Vector2(0.5, e),
		Vector2(e, 0.5),
		Vector2(-e, 0.5),
		Vector2(-0.5, e),
		Vector2(-0.5, -e),
		Vector2(-e, -0.5),
		Vector2(e, -0.5),
		Vector2(0.5, -e)
	]:
		s.append(p)
	var k := 1.0 - bevel
	var levels := [
		[-0.5, k, k], [-0.5 + bevel * 0.5, 1.0, 1.0], [0.5 - bevel * 0.5, 1.0, 1.0], [0.5, k, k]
	]
	return loft(s, levels, size, salt, 0.0)


## A pointed crystal spike, `h` tall and `r` wide at its base (5 sides, its tip a little off-centre).
static func crystal(h: float, r: float, salt: int) -> ArrayMesh:
	var lean := (noise(salt) - 0.5) * 0.3
	var levels := [[0.0, 0.8, 0.8], [0.25, 1.0, 1.0], [1.0, 0.02, 0.02, lean]]
	return loft(ngon(5, salt % 2 == 1), levels, Vector3(r, h, r), salt, 0.18)


## A low-poly ball (`rings` bands of `sides`), an egg or a joint.
static func orb(radius: float, salt: int, sides: int = 7, bands: int = 5) -> ArrayMesh:
	var levels := []
	for k in bands + 1:
		var a := PI * float(k) / bands - PI * 0.5
		var s := maxf(cos(a), 0.02)
		levels.append([sin(a) * 0.5, s * 0.5, s * 0.5])
	return loft(ngon(sides), levels, Vector3.ONE * radius * 2.0, salt, 0.12)


## A faceted tube along +X (an octagon section): a cannon barrel or a mortar tube, length `l`, radius `r`.
static func tube(l: float, r: float, salt: int, sides: int = 8) -> ArrayMesh:
	var m := loft(ngon(sides, true), [[0.0, 1.0, 1.0], [1.0, 1.0, 1.0]], Vector3(r, l, r), salt)
	return _turned(m, Basis(Vector3(0, 0, 1), -PI * 0.5))


static func _turned(m: ArrayMesh, b: Basis) -> ArrayMesh:
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for k in verts.size():
		verts[k] = b * verts[k]
		normals[k] = b * normals[k]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Thin flat strips along polylines in the plane x = 0 (facing +X): glowing cracks. Points are (z, y).
static func strips(lines: Array, width: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for line: Array in lines:
		for j in line.size() - 1:
			var a: Vector2 = line[j]
			var b: Vector2 = line[j + 1]
			var d := (b - a).normalized()
			var nrm := Vector2(-d.y, d.x) * width * 0.5
			var q: Array[Vector3] = []
			for v: Vector2 in [a + nrm, a - nrm, b - nrm, b + nrm]:
				q.append(Vector3(0, v.y, v.x))
			for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				for p: Vector3 in t:
					verts.append(p)
					normals.append(Vector3(1, 0, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Flat-shaded triangles facing away from `centre`, each facet tinted by a fixed amount from `salt` and the
## downward ones shaded.
static func mesh_from(tris: Array, centre: Vector3, salt: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in tris.size():
		var t: Array = tris[k]
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
		var v := 1.0 + (noise(salt * 131 + k * 17) - 0.5) * 2.0 * FACET_TINT
		v *= lerpf(1.0, 0.72, clampf(-n.y, 0.0, 1.0))
		var col := Color(v, v, v)
		colors.append_array([col, col, col])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
