class_name ShopModels
extends RefCounted
## The owner's shop models (v0.8.0 SR, owner O13: "it will be like in a tent shop with some stuff I will give you a
## model for that"; docs/art/requests/v0.8.0_ART_LIST.md §1). A model is used when assets/models/manifest.json lists
## its id (shop_tent, shop_vendor_<biome>, shop_wares) and its file is on disk (assets/models/shop/<id>.glb as the art
## list asks); otherwise get_model gives {} and ShopStallView draws its code-made stand-in (L15: missing art never
## blocks a step). v0.8.0 N11: the floor receiver's model (`floor_receiver`, FloorReceiver) is read the same way;
## v0.8.0 N17: the curse altar's (`curse_altar`, EventPedestalViews).
## Each model is read once (cached), its first mesh turned into our frame and scaled:
## - its front (glTF +Z, the way a generator's "facing forward" model looks) turned to +X, our front (SPECS "yaw");
## - centred on x and z, its lowest point on the floor (y = 0), or `lift` metres up (the Starfall merchant floats);
## - the tent and the wares scaled to fill their box (SPECS "size", x y z after the turn), so the tent covers the
##   stall's sim footprint exactly (looks solid = is solid); a vendor scaled uniformly to its height.
## Presentation only.

const MANIFEST := "res://assets/models/manifest.json"
const DIR := "res://assets/models/shop/"
## A delivered model's front: glTF +Z, turned onto +X.
const FRONT_YAW := PI * 0.5
## Per model: "size" (the box it fills, m, after the turn: the tent x front-to-back, y height, z across) or "height"
## (m, uniform), "yaw"
## (radians about Y onto +X), "lift" (m off the floor). The stand-ins are built to the same numbers.
const SPECS := {
	# v0.8.0 SR: the owner's desert merchant stall (scripts/art/shop_stall.py): its front (the counters, the vendor) is
	# +X as delivered; 2.55 m to the awnings' top makes it 3.3 m front to back and 4.0 m across, inside the stall's sim
	# footprint (ShopRoomDefinition.STALL_SIZE, 4.0 x 3.4 m). Its vendor is fused into the mesh (ShopStallView).
	&"shop_tent": {"height": 2.55, "yaw": 0.0},
	# The goods keep their delivered frame: width along x, front +Z (they lie along the counter, front to you).
	&"shop_wares": {"size": Vector3(1.0, 0.6, 0.6), "yaw": 0.0},
	&"shop_vendor_ruins": {"height": 1.6, "yaw": FRONT_YAW},
	&"shop_vendor_night_rocks": {"height": 1.7, "yaw": FRONT_YAW},
	&"shop_vendor_red_canyon": {"height": 1.7, "yaw": FRONT_YAW},
	&"shop_vendor_frozen_shore": {"height": 1.7, "yaw": FRONT_YAW},
	&"shop_vendor_starfall": {"height": 1.8, "yaw": FRONT_YAW, "lift": 0.35},
	# v0.8.0 N11 (owner O69): the floor's receiver (FloorReceiver; docs/OWNER_TODO.md §3.1 `floor_receiver`), round,
	# so no turn: it fills its 2.2 x 1.2 x 2.2 m box on the hero's start.
	&"floor_receiver": {"size": Vector3(2.2, 1.2, 2.2), "yaw": 0.0},
	# v0.9.0 SA (owner Q16; docs/art/requests/v0.9.0_altars_portals.md `arrival_altar`): floor 1's altar (AltarStage),
	# round, so no turn: its stone fills a 6.6 x 0.45 x 6.6 m box on the hero's start (low: the sim has no height, so
	# the hero walks over its steps). The floating runes and the jewels stay code objects.
	&"arrival_altar": {"size": Vector3(6.6, 0.45, 6.6), "yaw": 0.0},
	# v0.8.0 N17 (owner O75): the curse room's altar (EventPedestalViews; docs/OWNER_TODO.md §3.1 `curse_altar`;
	# delivered 2026-10-18, scripts/assets/curse_altar_prep.gd): scaled uniformly to 0.98 m high, which makes the
	# owner's altar 1.40 m long and 0.98 m deep, inside its 1.4 x 1.4 x 1.0 m box under the crystal the game floats
	# over it (no turn: its long side stays along x).
	&"curse_altar": {"height": 0.98, "yaw": 0.0},
	# v0.9.0 TD (docs/art/requests/v0.9.0_ART_LIST.md §3.2; TimedDoorView): the timed door's slab, 0.8 m thick, 3.0 m
	# high and 3.0 m across (the view stretches it across the doorway's width), and the rune switch, 0.7 x 1.3 x 0.7 m.
	# Listed in assets/models/manifest.json when the owner's files arrive; until then the code stand-ins draw them.
	&"timed_door": {"size": Vector3(0.8, 3.0, 3.0), "yaw": 0.0},
	&"rune_switch": {"size": Vector3(0.7, 1.3, 0.7), "yaw": 0.0},
}

## Where the manifest is read (tests point it at their own).
static var manifest := MANIFEST
static var _cache := {}
static var _listed := {}
static var _listed_read := false


## The vendor's model id for a biome.
static func vendor_id(biome: StringName) -> StringName:
	return StringName("shop_vendor_%s" % biome)


## {"mesh": ArrayMesh in our frame, "material": its material, "aabb": its bounds} or {} when the manifest doesn't list
## `id`, its file is missing or it has no mesh.
static func get_model(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out := {}
	var path := listed_path(id)
	if path != "" and SPECS.has(id) and ResourceLoader.exists(path):
		out = _convert(ModelLibrary.first_surface(load(path) as PackedScene), SPECS[id])
	_cache[id] = out
	return out


## The res:// path the manifest lists for `id` ("" when it isn't listed).
static func listed_path(id: StringName) -> String:
	if not _listed_read:
		_listed_read = true
		_listed = {}
		if FileAccess.file_exists(manifest):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
			if typeof(data) == TYPE_DICTIONARY:
				for m: Dictionary in (data as Dictionary).get("models", []):
					_listed[StringName(String(m.get("id", "")))] = (
						"res://" + String(m.get("path", ""))
					)
	return String(_listed.get(id, ""))


static func clear_cache() -> void:
	_cache.clear()
	_listed.clear()
	_listed_read = false


static func _convert(surface: Dictionary, spec: Dictionary) -> Dictionary:
	if surface.is_empty():
		return {}
	var arrays: Array = surface["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var turn := Basis(Vector3.UP, float(spec.get("yaw", FRONT_YAW)))
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for k in verts.size():
		verts[k] = turn * verts[k]
		lo = lo.min(verts[k])
		hi = hi.max(verts[k])
	var ext := (hi - lo).max(Vector3(0.0001, 0.0001, 0.0001))
	var scale := Vector3.ONE * (float(spec.get("height", 1.0)) / ext.y)
	if spec.has("size"):
		var size: Vector3 = spec["size"]
		scale = Vector3(size.x / ext.x, size.y / ext.y, size.z / ext.z)
	var base := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var lift := float(spec.get("lift", 0.0))
	for k in verts.size():
		verts[k] = (verts[k] - base) * scale + Vector3(0, lift, 0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in ns.size():
			ns[k] = (turn * ns[k] / scale).normalized()
		arrays[Mesh.ARRAY_NORMAL] = ns
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "material": surface["material"], "aabb": mesh.get_aabb()}
