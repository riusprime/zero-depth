class_name EnemyModels
extends RefCounted
## v0.8.0 MI: the owner's enemy models (owner 2026-10-18: "enemies are not animated and will need to be animated if
## needed"): assets/models/enemies/<id>.glb, prepared offline by scripts/assets/mi_prep.py: turned to our facing
## frame (+X the front, Y up, metres, feet on the ground), cut into the parts that move (one node each, its origin
## at the part's pivot: the Shield Bearer's shield and legs, the Splitter's halves, arms and legs, the Mender's
## crystals and cross, the Lens Drone's ring of feet) and, in each part, into up to three surfaces by what the
## texture shows there: `base` (the charcoal frame and bone, coloured as delivered), `role` (the plates, greyscale in
## the texture, so the avatar tints them in the kind's role colour, EnemyPalettes) and `glow` (eyes, seam, crystals:
## the avatar's glowing accent). No rig: HordeAvatar and LensDroneAvatar pose the parts in code. Read once per kind
## and cached; a missing file gives {} and the avatar keeps its code-made body (L15).

const DIR := "res://assets/models/enemies/"
## Per kind: the model file's id and the height (m) the avatar scales it to (the code bodies' heights, HordeAvatar
## HEIGHTS; the Mender's without its float, the Lens Drone's pod).
const SPECS := {
	&"mender": {"height": 1.45},
	&"shield_bearer": {"height": 1.25},
	&"splitter": {"height": 0.95},
	&"lens_drone": {"height": 0.5},
}
const SURFACES: Array[StringName] = [&"base", &"role", &"glow"]

## Where models are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## {"parts": {name: {"pivot": Vector3 (metres, model frame), "mesh": ArrayMesh, "surfaces": [&"base" | &"role" |
## &"glow" per surface]}}, "texture": Texture2D (the shared colour map), "scale": metres per model unit to reach
## SPECS' height, "height": the model's own height} or {} when the file is missing.
static func get_model(id: StringName) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if SPECS.has(id) and ResourceLoader.exists(path):
		out = _read(load(path) as PackedScene, float(SPECS[id]["height"]))
	_cache[path] = out
	return out


static func has_model(id: StringName) -> bool:
	return not get_model(id).is_empty()


static func clear_cache() -> void:
	_cache.clear()


static func _read(scene: PackedScene, height: float) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var parts := {}
	var tex: Texture2D = null
	var top := 0.0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var surfaces: Array[StringName] = []
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			var nm := StringName(m.resource_name) if m != null else &"base"
			surfaces.append(nm if nm in SURFACES else &"base")
			if tex == null and m != null and m.albedo_texture != null:
				tex = m.albedo_texture
		var box := mi.mesh.get_aabb()
		top = maxf(top, mi.position.y + box.end.y)
		parts[StringName(mi.name)] = {"pivot": mi.position, "mesh": mi.mesh, "surfaces": surfaces}
	root.free()
	if parts.is_empty():
		return {}
	return {"parts": parts, "texture": tex, "scale": height / maxf(top, 0.0001), "height": top}
