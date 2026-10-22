class_name BossDoorModels
extends RefCounted
## v0.8.0 BD (owner O82: "5 doors that match each biome for the boss room … similar but with small different
## details and colors based on the biome"): the owner's boss doors, assets/models/doors/boss_door_<biome>.glb,
## prepared offline by scripts/assets/bd_prep.py from one closed door each: in BossDoorView's local frame (the gap
## along Z, +X into the boss room, the front face toward -X, metres, the floor at y = 0), cut into four parts (one node
## each, its origin at its pivot): `jamb_n` and `jamb_p` (the frame past each side of the opening, pivoted on the
## opening's side), `lintel` (the frame over and in front of the opening) and `slab` (pivoted on the floor, the
## opening's middle). SPECS holds what the prep printed: the opening's width as prepared, the slab's faces (X) and the
## round socket on each face where the game's red seal goes. Read once per biome and cached (ViewWarmup reads the
## floor's on the load's worker, so no frame reads the file); a missing file gives {} and the code-made door stands
## (L15).

const DIR := "res://assets/models/doors/"
## Per biome (scripts/assets/bd_prep.py's output, 2026-10-18): "width" (the opening, m), "slab_h" (m), "faces" (the
## slab's front and back faces, X), "seal_front" / "seal_back" (the socket: x its floor, y its centre's height, r its
## radius, m).
const SPECS := {
	&"ruins":
	{
		"width": 2.672,
		"slab_h": 2.6,
		"faces": Vector2(-0.098, 0.102),
		"seal_front": Vector3(-0.045, 1.564, 0.381),
		"seal_back": Vector3(0.053, 1.585, 0.393),
	},
	&"night_rocks":
	{
		"width": 2.666,
		"slab_h": 2.6,
		"faces": Vector2(-0.208, 0.216),
		"seal_front": Vector3(-0.075, 1.448, 0.266),
		"seal_back": Vector3(0.076, 1.418, 0.283),
	},
	&"red_canyon":
	{
		"width": 2.655,
		"slab_h": 2.6,
		"faces": Vector2(-0.226, 0.124),
		"seal_front": Vector3(-0.14, 1.536, 0.325),
		"seal_back": Vector3(0.037, 1.559, 0.328),
	},
	&"frozen_shore":
	{
		"width": 2.547,
		"slab_h": 2.6,
		"faces": Vector2(-0.152, 0.222),
		"seal_front": Vector3(-0.068, 1.48, 0.319),
		"seal_back": Vector3(0.135, 1.466, 0.326),
	},
	&"starfall":
	{
		"width": 2.594,
		"slab_h": 2.6,
		"faces": Vector2(-0.249, 0.186),
		"seal_front": Vector3(-0.183, 1.483, 0.328),
		"seal_back": Vector3(0.12, 1.493, 0.327),
	},
}
const PARTS: Array[StringName] = [&"jamb_n", &"jamb_p", &"lintel", &"slab"]

## Where models are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## The model file's path for a biome.
static func path_of(biome: StringName) -> String:
	return dir + "boss_door_%s.glb" % biome


## {"parts": {name: {"mesh": Mesh, "material": Material, "pivot": Vector3}}, "spec": SPECS[biome]} or {} when the biome
## has no door or its file is missing.
static func get_model(biome: StringName) -> Dictionary:
	var path := path_of(biome)
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if SPECS.has(biome) and ResourceLoader.exists(path):
		out = _read(load(path) as PackedScene)
		if not out.is_empty():
			out["spec"] = SPECS[biome]
	_cache[path] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _read(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var parts := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if StringName(mi.name) in PARTS and mi.mesh != null:
			parts[StringName(mi.name)] = {
				"mesh": mi.mesh,
				"material": mi.get_active_material(0),
				"pivot": mi.position,
			}
	root.free()
	if parts.size() != PARTS.size():
		return {}
	return {"parts": parts}
