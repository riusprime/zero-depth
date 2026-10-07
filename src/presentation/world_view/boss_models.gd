class_name BossModels
extends RefCounted
## The owner's boss models (PLAN v0.3.0 L13; docs/art/ART_DIRECTION.md §5.2): assets/models/bosses/<id>.glb, one
## textured mesh each, normalised to about one unit. Each is read once per boss type and turned into our facing
## frame (+X the front, Y up, metres, feet on the ground) at the boss's in-game height: the mesh and its material are
## cached, so a spawn only instances them. A missing file gives {} and the boss keeps its code-built body.
## Orientation and size were read from renders of the raw models next to the sheet (evidence/BOSSES.md).

const DIR := "res://assets/models/bosses/"
## Per model: its front's direction turned to +X (a yaw in radians about Y) and its height in metres (the
## code-built bodies' heights, which match the sheet's in-game inset against the hero).
const SPECS := {
	&"stone_sentinel": {"yaw": 0.0, "height": 2.95},
	&"crawler_queen": {"yaw": -PI * 0.5, "height": 2.4},
	&"fortress_turret": {"yaw": 0.0, "height": 2.5},
}

## Where models are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## {"mesh": ArrayMesh in our frame, "material": the model's StandardMaterial3D, "aabb": its bounds} or {} if the
## file is missing.
static func get_model(id: StringName) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if ResourceLoader.exists(path):
		out = _convert(load(path) as PackedScene, SPECS.get(id, {"yaw": 0.0, "height": 2.5}))
	_cache[path] = out
	return out


## Reads every boss model now (the stage build), so no spawn waits on an import.
static func preload_all() -> void:
	for id: StringName in SPECS:
		get_model(id)


## How many models were read from disk (tests check each is read once).
static func loaded_count() -> int:
	var n := 0
	for k in _cache:
		if not (_cache[k] as Dictionary).is_empty():
			n += 1
	return n


static func clear_cache() -> void:
	_cache.clear()


static func _convert(scene: PackedScene, spec: Dictionary) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		found.push_front(root)
	if found.is_empty():
		root.free()
		return {}
	var src := found[0] as MeshInstance3D
	var mesh := src.mesh
	var mat := src.get_active_material(0) as StandardMaterial3D
	var arrays := mesh.surface_get_arrays(0)
	root.free()
	var aabb := mesh.get_aabb()
	var s: float = spec["height"] / maxf(aabb.size.y, 0.0001)
	var turn := Basis(Vector3.UP, spec["yaw"])
	var lift := -aabb.position.y * s
	var centre := aabb.get_center()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		var v := verts[k] - Vector3(centre.x, 0.0, centre.z)
		verts[k] = turn * (v * s) + Vector3(0, lift, 0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in ns.size():
			ns[k] = turn * ns[k]
		arrays[Mesh.ARRAY_NORMAL] = ns
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for k in range(0, ts.size(), 4):
			var t := turn * Vector3(ts[k], ts[k + 1], ts[k + 2])
			ts[k] = t.x
			ts[k + 1] = t.y
			ts[k + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = ts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": out, "material": mat, "aabb": out.get_aabb(), "arrays": arrays}
