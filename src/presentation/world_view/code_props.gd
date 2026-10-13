class_name CodeProps
extends RefCounted
## v0.7.5 NB1: decoration pieces the owner's kit lacks, built in code in the low-poly faceted shard style (flat
## facets, a few dozen triangles each), in the same form as KitModels.get_piece: a mesh in the unit box (footprint
## x and z in -0.5..0.5, bottom at y = 0, top at y = 1), its material and its natural size. StageKit draws them
## where a kit piece would go; a delivered .glb (docs/art/requests/v0.7.5_frozen_shore.md) replaces one by id
## through KitModels. Presentation only.

## Per piece: natural height (m), footprint (m) and role, like KitModels.SPECS.
const SPECS := {
	&"snow_drift": {"height": 0.28, "foot": Vector2(0.9, 0.6), "role": &"decor"},
	&"ice_shard": {"height": 0.4, "foot": Vector2(0.5, 0.5), "role": &"decor"},
}
const SNOW := Color("#E6EEF8")
const ICE := Color("#BFE3F2")
const ICE_GLOW := Color("#8FCFEA")

static var _cache := {}


## {"mesh", "material", "size"} for a code-made piece, or {} for an unknown id.
static func get_piece(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out := {}
	match id:
		&"snow_drift":
			out = {"mesh": snow_drift_mesh(), "material": snow_material()}
		&"ice_shard":
			out = {"mesh": ice_shard_mesh(), "material": ice_material()}
	if not out.is_empty():
		var spec: Dictionary = SPECS[id]
		var foot: Vector2 = spec["foot"]
		out["size"] = Vector3(foot.x, float(spec["height"]), foot.y)
	_cache[id] = out
	return out


static func has(id: StringName) -> bool:
	return SPECS.has(id)


## A low wind-packed mound: a jittered seven-sided base, a shoulder ring and an off-centre crest, flat-shaded.
static func snow_drift_mesh() -> ArrayMesh:
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var n := 7
	var jitter := [1.0, 0.86, 0.95, 0.8, 0.98, 0.9, 0.84]
	for k in n:
		var a := TAU * k / n
		var r: float = 0.5 * jitter[k]
		base.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		mid.append(
			Vector3(cos(a + 0.3) * r * 0.62 + 0.06, 0.62 + 0.08 * (k % 2), sin(a + 0.3) * r * 0.6)
		)
	var top := Vector3(0.12, 1.0, -0.04)
	var inside := Vector3(0.04, 0.3, 0.0)
	var st := _begin()
	for k in n:
		var k2 := (k + 1) % n
		_tri(st, base[k], mid[k], base[k2], inside)
		_tri(st, base[k2], mid[k], mid[k2], inside)
		_tri(st, mid[k], top, mid[k2], inside)
	return _end(st)


## Three faceted ice spikes leaning out of one root: square-sectioned prisms with a pointed tip.
static func ice_shard_mesh() -> ArrayMesh:
	var st := _begin()
	for spec: Array in [
		[Vector3(0.0, 0.0, 0.0), 1.0, 0.13, Vector3(0.0, 0.0, 0.12)],
		[Vector3(0.18, 0.0, 0.1), 0.62, 0.1, Vector3(0.3, 0.0, -0.25)],
		[Vector3(-0.16, 0.0, -0.12), 0.48, 0.09, Vector3(-0.35, 0.0, 0.2)],
	]:
		_spike(st, spec[0], spec[1], spec[2], spec[3])
	return _end(st)


static func _spike(st: SurfaceTool, at: Vector3, h: float, w: float, lean: Vector3) -> void:
	var b := Basis.from_euler(lean)
	var ring: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var o := Vector3(cos(a) * w, 0.0, sin(a) * w)
		ring.append(at + b * (o + Vector3(0, -0.05, 0)))
		shoulder.append(at + b * (o * 0.8 + Vector3(0, h * 0.7, 0)))
	var tip := at + b * Vector3(0, h, 0)
	var inside := at + b * Vector3(0, h * 0.45, 0)
	for k in 4:
		var k2 := (k + 1) % 4
		_tri(st, ring[k], shoulder[k], ring[k2], inside)
		_tri(st, ring[k2], shoulder[k], shoulder[k2], inside)
		_tri(st, shoulder[k], tip, shoulder[k2], inside)


static func snow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SNOW
	m.roughness = 0.85
	return m


static func ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ICE
	m.roughness = 0.12
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.4
	m.emission_enabled = true
	m.emission = ICE_GLOW
	m.emission_energy_multiplier = 0.18
	return m


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## One flat facet, its normal pointing away from `inside` and wound clockwise seen from outside (Godot's front face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_normal((-n).normalized())
	st.add_vertex(a)
	st.set_normal((-n).normalized())
	st.add_vertex(b)
	st.set_normal((-n).normalized())
	st.add_vertex(c)


## The mesh fitted to the unit box (footprint -0.5..0.5, bottom 0, top 1); normals follow the stretch.
static func _end(st: SurfaceTool) -> ArrayMesh:
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := (hi - lo).max(Vector3(0.0001, 0.0001, 0.0001))
	var centre := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	for k in verts.size():
		verts[k] = (verts[k] - centre) / ext
		normals[k] = (normals[k] * ext).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
