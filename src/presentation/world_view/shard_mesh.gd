class_name ShardMesh
extends RefCounted
## The crystal-shard look in the world (v0.6.1 SW, owner R3: "modify some renders in game to match the more shard
## like style like altars or other elements"), built in code from the owner's card and plaque art
## (docs/roadmap/v0.6.0/refs/card_templates_empty.webp, docs/roadmap/v0.6.1/refs/plaque_templates_empty.webp):
## faceted crystal shards with dark outlines, bright and dark facets side by side, a soft inner glow, small floating
## fragments, a stone base.
##
## One shared builder so every shard piece looks alike (altars, heal orbs, shard gems, dropped cores; the shard
## dressing of step SD reuses it):
## - crystal(): a jagged faceted shard mesh, flat-shaded, each facet painted a tone (vertex colour) so the bright and
##   dark planes read apart like the art's cel shading;
## - crystal_material(): lit by the scene (the v0.5.9 lighting moods reach it) with a little emission, a rim and a
##   tight highlight; never a flat unshaded fill (VFX audit, ART_DIRECTION §4);
## - outlined(): the mesh plus a dark inverted-hull shell around it (the art's thick outline);
## - glow(): a soft additive radial sprite for the inner glow (a flash of light is additive, the A3 rule);
## - cluster(), fragment(), rock(): the pieces put together.
## Deterministic: the jitter comes from a hash of the `salt`, so a piece looks the same every time. Glowing
## materials have emission on from creation; callers change energies and colours only (flash-safe).
## Presentation only (EI-07): nothing here reads or changes the sim.

## The outline's colour (the art's near-black violet line).
const OUTLINE := Color("#130F1A")
## How much bigger the outline shell is than its crystal (a fraction of the crystal's size).
const OUTLINE_GROW := 0.14
## Facet tones around a shard, light to dark (the cel bands of the art): applied in turn to the side facets.
const SIDE_TONES := [1.0, 0.66, 0.86, 0.58, 0.94, 0.7, 0.8]
## The tip's facets are the brightest (the highlight at the top of every shard in the art).
const TIP_TONES := [1.0, 0.84]
const STONE := Color("#5B5550")
const STONE_TOP := Color("#736C66")

static var _outline_mat: StandardMaterial3D
static var _glow_tex: GradientTexture2D


## A faceted shard: `sides` around, base radius `r` * 0.7 at y = 0 widening to `r` at the shoulder, then a pointed
## tip up to `h`; `tip` is the tip's share of the height. The radii and the apex are jittered from `salt`.
static func crystal(sides: int, r: float, h: float, tip: float = 0.32, salt: int = 1) -> ArrayMesh:
	var tris := []
	var tones := []
	var shoulder := h * (1.0 - tip)
	var twist := (_hash(salt, 99) - 0.5) * 0.5
	var apex := Vector3((_hash(salt, 97) - 0.5) * r * 0.3, h, (_hash(salt, 98) - 0.5) * r * 0.3)
	var bottom := Vector3(0, 0, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var j0 := 0.85 + 0.3 * _hash(salt, k)
		var j1 := 0.85 + 0.3 * _hash(salt, (k + 1) % sides)
		var b0 := Vector3(cos(a0) * r * 0.7 * j0, 0, sin(a0) * r * 0.7 * j0)
		var b1 := Vector3(cos(a1) * r * 0.7 * j1, 0, sin(a1) * r * 0.7 * j1)
		var s0 := Vector3(cos(a0 + twist) * r * j0, shoulder, sin(a0 + twist) * r * j0)
		var s1 := Vector3(cos(a1 + twist) * r * j1, shoulder, sin(a1 + twist) * r * j1)
		var side: float = SIDE_TONES[(k + salt) % SIDE_TONES.size()]
		tris.append([b0, b1, s1])
		tones.append(side)
		tris.append([b0, s1, s0])
		tones.append(side)
		tris.append([apex, s0, s1])
		tones.append(TIP_TONES[k % 2])
		tris.append([bottom, b1, b0])
		tones.append(0.5)
	return _flat(tris, tones, Vector3(0, h * 0.45, 0))


## A small double-pointed fragment (the floating chips of the art): `sides` around, radius r, tips up and down.
static func shard(sides: int, r: float, up: float, down: float, salt: int = 1) -> ArrayMesh:
	var tris := []
	var tones := []
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var j := 0.85 + 0.3 * _hash(salt, k)
		var p0 := Vector3(cos(a0) * r * j, 0, sin(a0) * r * j)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		tris.append([Vector3(0, up, 0), p0, p1])
		tones.append(TIP_TONES[k % 2])
		tris.append([Vector3(0, -down, 0), p1, p0])
		tones.append(SIDE_TONES[(k * 3 + salt) % SIDE_TONES.size()] * 0.8)
	return _flat(tris, tones, Vector3.ZERO)


## A rough faceted stone block (a shard's base): `sides` around, radius r0 at the floor and r1 on top, height h,
## the rim jittered from `salt`. Drawn with stone_material().
static func rock(sides: int, r0: float, r1: float, h: float, salt: int = 1) -> ArrayMesh:
	var tris := []
	var tones := []
	var top := Vector3(0, h, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var j0 := 0.9 + 0.2 * _hash(salt, k)
		var j1 := 0.9 + 0.2 * _hash(salt, (k + 1) % sides)
		var y0 := h * (0.85 + 0.3 * _hash(salt + 7, k))
		var y1 := h * (0.85 + 0.3 * _hash(salt + 7, (k + 1) % sides))
		var b0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1 * j0, y0, sin(a0) * r1 * j0)
		var t1 := Vector3(cos(a1) * r1 * j1, y1, sin(a1) * r1 * j1)
		var tone := 0.8 + 0.2 * _hash(salt + 3, k)
		tris.append([b0, b1, t1])
		tones.append(tone)
		tris.append([b0, t1, t0])
		tones.append(tone)
		tris.append([top, t0, t1])
		tones.append(1.0)
	return _flat(tris, tones, Vector3(0, h * 0.5, 0))


## The shard material: `c` lit by the scene, its facets toned by the mesh's vertex colours, a tight highlight and a
## rim so the edges catch the light, and emission `energy` (on from creation) for the crystal's own glow.
static func crystal_material(c: Color, energy: float = 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.24
	m.metallic_specular = 0.85
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.35
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## A stone base's material (lit, rough, facet tones from the mesh).
static func stone_material(c: Color = STONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	return m


## The outline shell's material (shared): the dark line colour, unshaded (a line, not a lit surface), drawn on the
## back faces of the slightly larger shell so only its rim shows round the crystal.
static func outline_material() -> StandardMaterial3D:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.albedo_color = OUTLINE
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	return _outline_mat


## `mesh` drawn with `mat` plus its dark outline shell; `centre` is the point the shell grows from (the mesh's
## middle). The node's meta "crystal" is the coloured MeshInstance3D, "outline" the shell.
static func outlined(
	mesh: Mesh, mat: Material, centre: Vector3, grow: float = OUTLINE_GROW
) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Crystal"
	body.mesh = mesh
	body.material_override = mat
	root.add_child(body)
	var shell := MeshInstance3D.new()
	shell.name = "Outline"
	shell.mesh = mesh
	shell.material_override = outline_material()
	shell.scale = Vector3.ONE * (1.0 + grow)
	shell.position = centre * -grow
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	root.set_meta(&"crystal", body)
	root.set_meta(&"outline", shell)
	return root


## A soft additive glow sprite (always facing the camera) of colour `c`, `size` metres across, at strength `alpha`.
## The sprite's material is its own, so a caller can change its colour's alpha (the glow's strength) at runtime.
static func glow(c: Color, size: float, alpha: float = 0.35) -> MeshInstance3D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_tex
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var n := MeshInstance3D.new()
	n.name = "Glow"
	n.mesh = q
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## A cluster of `count` outlined shards in `mat` on the floor at the node's origin: a tall one in the middle
## (`height` m) and the rest smaller round it, leaning out, within `spread` m of the centre (tips included).
## Deterministic from `salt`. Meta "shards" is the number of shards.
static func cluster(
	mat: Material, count: int, height: float, spread: float, salt: int = 1
) -> Node3D:
	var root := Node3D.new()
	root.name = "ShardCluster"
	var r := clampf(height * 0.17, 0.04, spread * 0.4)
	root.add_child(outlined(crystal(6, r, height, 0.3, salt), mat, Vector3(0, height * 0.45, 0)))
	for k in range(1, count):
		var a := TAU * (k - 1) / maxf(1.0, count - 1) + _hash(salt, k + 20) * 0.6
		var small := k > 5
		var h := (
			height
			* (0.22 + 0.12 * _hash(salt, k + 40) if small else 0.45 + 0.25 * _hash(salt, k + 40))
		)
		var lean := deg_to_rad(16.0 + 18.0 * _hash(salt, k + 60))
		var d := spread * (0.62 if small else 0.32)
		# The leaning tip stays inside `spread`: the foot moves in as the shard grows taller.
		d = minf(d, spread - sin(lean) * h - r * 0.6)
		var piece := outlined(
			crystal(5, r * (0.55 if small else 0.75), h, 0.34, salt * 7 + k),
			mat,
			Vector3(0, h * 0.45, 0)
		)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a) * maxf(0.0, d), 0, sin(a) * maxf(0.0, d))
		pivot.rotation = Vector3(0, -a, 0)
		piece.rotation.z = -lean  # lean outward (local +x is away from the centre)
		pivot.add_child(piece)
		root.add_child(pivot)
	root.set_meta(&"shards", count)
	return root


## A small outlined floating fragment in `mat`, radius r.
static func fragment(mat: Material, r: float, salt: int = 1) -> Node3D:
	return outlined(shard(4, r, r * 1.8, r * 1.4, salt), mat, Vector3.ZERO, 0.22)


## A value in [0, 1) from `salt` and `k` (deterministic; no random stream).
static func _hash(salt: int, k: int) -> float:
	var h := (salt * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0


static func _flat(tris: Array, tones: Array, centre: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in tris.size():
		var a: Vector3 = tris[k][0]
		var b: Vector3 = tris[k][1]
		var c: Vector3 = tris[k][2]
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
		var v: float = tones[k]
		colors.append_array([Color(v, v, v), Color(v, v, v), Color(v, v, v)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
