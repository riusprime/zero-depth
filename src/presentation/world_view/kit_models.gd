class_name KitModels
extends RefCounted
## The owner's kit pieces (v0.5.9 Step 3; docs/art/KIT_REQUESTS.md): assets/models/kit/<id>.glb, made with an AI
## generator, so unscaled and arbitrarily turned. Each is read once and normalised to a unit box: its long side on
## +X, its footprint x and z in -0.5..0.5, its bottom at y = 0 and its top at y = 1. The dresser then scales a
## piece straight to a sim footprint (walls, cover) or to its natural size (props). The mesh and material are
## cached. A missing file gives {} and the caller draws its primitive (L15: missing art never blocks a step).

const DIR := "res://assets/models/kit/"
## Per piece: the yaw (radians about Y) that turns its long side onto +X (read from renders of the raw models),
## its natural height in metres (KIT_REQUESTS), and its role for the dresser.
const SPECS := {
	&"wall_1m": {"yaw": 0.0, "height": 1.0, "role": &"wall"},
	&"wall_2m": {"yaw": PI * 0.5, "height": 1.0, "role": &"wall"},
	&"wall_broken": {"yaw": 0.0, "height": 0.7, "role": &"wall"},
	&"wall_pillar": {"yaw": 0.0, "height": 1.3, "role": &"wall"},
	&"slab_concrete": {"yaw": 0.0, "height": 1.8, "role": &"cover"},
	&"slab_wide": {"yaw": 0.0, "height": 1.8, "role": &"cover"},
	&"crate_stack": {"yaw": PI * 0.5, "height": 1.2, "role": &"cover"},
	&"car_wreck": {"yaw": 0.0, "height": 1.4, "role": &"cover"},
	&"rock_large": {"yaw": 0.0, "height": 1.2, "role": &"cover"},
	&"dead_tree": {"yaw": 0.0, "height": 2.2, "role": &"cover"},
	&"fire_barrel": {"yaw": 0.0, "height": 0.9, "role": &"light"},
	&"brazier_pole": {"yaw": 0.0, "height": 2.0, "role": &"light"},
	&"chest": {"yaw": PI * 0.5, "height": 0.6, "role": &"reward"},
	&"rubble_small": {"yaw": 0.0, "height": 0.25, "role": &"decor"},
	&"grass_tuft": {"yaw": 0.0, "height": 0.4, "role": &"decor"},
	&"debris_low": {"yaw": PI * 0.5, "height": 0.2, "role": &"decor"},
}

## Where pieces are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## {"mesh": ArrayMesh in the unit box, "material": the piece's StandardMaterial3D, "size": its natural size in
## metres (Vector3: long side x, height y, depth z)}, or {} if the file is missing.
static func get_piece(id: StringName) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if SPECS.has(id) and ResourceLoader.exists(path):
		out = _normalise(ModelLibrary.first_surface(load(path) as PackedScene), SPECS[id])
	_cache[path] = out
	return out


## True when every wall and cover piece loads (the dresser needs all of them to build a floor).
static func has_structure() -> bool:
	for id: StringName in SPECS:
		if SPECS[id]["role"] in [&"wall", &"cover"] and get_piece(id).is_empty():
			return false
	return true


static func ids_with_role(role: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in SPECS:
		if SPECS[id]["role"] == role:
			out.append(id)
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _normalise(surface: Dictionary, spec: Dictionary) -> Dictionary:
	if surface.is_empty():
		return {}
	var arrays: Array = surface["arrays"]
	var turn := Basis(Vector3.UP, spec["yaw"])
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for k in verts.size():
		verts[k] = turn * verts[k]
		lo = lo.min(verts[k])
		hi = hi.max(verts[k])
	var ext := (hi - lo).max(Vector3(0.0001, 0.0001, 0.0001))
	var inv := Vector3(1.0 / ext.x, 1.0 / ext.y, 1.0 / ext.z)
	var centre := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	for k in verts.size():
		verts[k] = (verts[k] - centre) * inv
	arrays[Mesh.ARRAY_VERTEX] = verts
	# A non-uniform scale bends normals by the inverse scale (the inverse transpose of a diagonal matrix).
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in ns.size():
			ns[k] = ((turn * ns[k]) * ext).normalized()
		arrays[Mesh.ARRAY_NORMAL] = ns
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for k in range(0, ts.size(), 4):
			var t := ((turn * Vector3(ts[k], ts[k + 1], ts[k + 2])) * inv).normalized()
			ts[k] = t.x
			ts[k + 1] = t.y
			ts[k + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = ts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var height: float = spec["height"]
	var size := Vector3(ext.x, ext.y, ext.z) * (height / ext.y)
	return {"mesh": mesh, "material": surface["material"], "size": size}
