class_name ModelLibrary
extends RefCounted
## The shared part of loading the owner's .glb models (ART_DIRECTION §5.2): the first mesh surface of an imported
## scene, with its material. BossModels (bosses) and KitModels (v0.5.9 kit pieces) build on it.


## {"arrays": the surface's arrays, "material": its StandardMaterial3D, "aabb": the mesh's bounds}, or {} when
## the scene is null or has no mesh.
static func first_surface(scene: PackedScene) -> Dictionary:
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
	var out := {
		"arrays": mesh.surface_get_arrays(0),
		"material": src.get_active_material(0) as StandardMaterial3D,
		"aabb": mesh.get_aabb(),
	}
	root.free()
	return out
