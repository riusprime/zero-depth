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
	# v0.9.0 TD (docs/art/requests/v0.9.0_ART_LIST.md §3.2; TimedDoorView): the timed door's slab, 3.0 m high and 3.0 m
	# across (the view stretches it across the doorway's width), and the rune switch. v0.9.0 MI2 (delivered
	# 2026-10-22; scripts/assets/mi2_prep.py prepared them in this frame, so no turn): the owner's door is a gate of
	# iron bars with no frame; his switch keeps its own proportions, 1.3 m high, its slanted rune top toward +Z (the door).
	# The owner (2026-10-22, PLAN "Owner decisions" FV, MI2: "Use it for Lockdowns"): the gate is `lockdown_seal`, the
	# Lockdowns' doorway bars (LK), 0.4 m thick, 2.6 m high, 3.0 m across (its width on z, as prepared); `timed_door` is
	# unlisted again, so the timed door is the code stone slab until the owner's stone door arrives.
	&"lockdown_seal": {"size": Vector3(0.4, 2.6, 3.0), "yaw": 0.0},
	&"rune_switch": {"height": 1.3, "yaw": 0.0},
	# v0.9.0 RA (the same list; RuneAlignmentView): the turning pillar, 0.9 x 2.2 x 0.9 m, and the carving, 2.4 m
	# across, 1.6 m high, 0.3 m deep (on the sealed doorway's slab). Code stand-ins until the owner's files arrive.
	&"rune_pillar": {"size": Vector3(0.9, 2.2, 0.9), "yaw": 0.0},
	&"rune_mural": {"size": Vector3(2.4, 1.6, 0.3), "yaw": 0.0},
	# v0.9.0 DX (the same list; BreakablesView): the cracked wall whole and broken (stretched across the doorway), the
	# three containers and the explosive barrel. Code stand-ins until the owner's files arrive.
	&"cracked_wall": {"size": Vector3(1.0, 3.0, 3.0), "yaw": 0.0},
	&"cracked_wall_broken": {"size": Vector3(1.4, 3.0, 3.0), "yaw": 0.0},
	&"container_crate": {"size": Vector3(0.7, 0.7, 0.7), "yaw": 0.0},
	&"container_urn": {"size": Vector3(0.5, 0.8, 0.5), "yaw": 0.0},
	&"container_barrel": {"size": Vector3(0.6, 0.9, 0.6), "yaw": 0.0},
	&"explosive_barrel": {"size": Vector3(0.7, 1.0, 0.7), "yaw": 0.0},
	# v0.9.0 DP (owner Q26b; PurpleRuneView): the purple-rune dais, round, so no turn: its stone fills a 1.7 x 0.55 x
	# 1.7 m box in the room's middle (the floating crystal stays a code object). Listed in assets/models/manifest.json
	# when the owner's file is prepared; until then the code stand-in draws it.
	&"purple_rune_dais": {"size": Vector3(1.7, 0.55, 1.7), "yaw": 0.0},
	# v0.9.0 LK (owner Q21; docs/art/requests/v0.9.0_ART_LIST.md; LockdownView): the Hazard Lockdowns' props, one per
	# biome, each filling the box of its code stand-in. Not delivered yet: the stand-ins draw them until they are listed.
	&"hazard_cable": {"size": Vector3(0.6, 1.6, 0.6), "yaw": 0.0},
	&"hazard_rock": {"size": Vector3(1.1, 1.0, 1.1), "yaw": 0.0},
	&"hazard_vent": {"size": Vector3(1.4, 2.2, 1.4), "yaw": 0.0},
	&"hazard_ice": {"size": Vector3(1.6, 0.9, 1.6), "yaw": 0.0},
	&"hazard_star": {"size": Vector3(0.8, 0.8, 0.8), "yaw": 0.0},
	# v0.9.0 SH, HF (owner Q29b; GambleShrineView, ShrinesView): the shrines and the healing fountain, front +Z kept
	# (the views turn them to the camera), scaled uniformly. Prepared by scripts/assets/mi2_prep.py to these heights
	# (measured: Fortune 1.33 x 2.0 x 1.16 m, Blood 2.72 x 2.0 x 2.13, Chaos 1.83 x 2.2 x 1.78, the fountain
	# 1.19 x 1.4 x 1.13), over the shrine's 1 m footprint turned 45 degrees (1.41 m corner to corner). Blood's wide
	# basin is drawn at 1.5 m tall (2.04 x 1.6 m across) and Chaos's at 1.8 m (1.5 x 1.46 m) so they stay near it.
	&"shrine_fortune": {"height": 2.0, "yaw": 0.0},
	&"shrine_blood": {"height": 1.5, "yaw": 0.0},
	&"shrine_chaos": {"height": 1.8, "yaw": 0.0},
	&"healing_fountain": {"height": 1.4, "yaw": 0.0},
	# v0.9.0 HB: the owner's hub pieces (delivered 2026-10-22, scripts/assets/mi2_prep.py: front kept on +Z, the hub's
	# stations face the camera's side). The machine is drawn at 4.6 m tall (the art list's 6.0 m filled the plaza's
	# centre; starting value), the rest at the art list's heights; the pedestals a little lower so six fit a station.
	&"hub_portal_machine": {"height": 4.6, "yaw": 0.0},
	&"hub_archive": {"height": 3.2, "yaw": 0.0},
	&"hub_wardrobe": {"height": 2.4, "yaw": 0.0},
	&"hub_station": {"height": 1.6, "yaw": 0.0},
	&"hub_trophy_pedestal": {"height": 0.9, "yaw": 0.0},
	&"hub_collectible_pedestal": {"height": 1.0, "yaw": 0.0},
	&"hub_collectible_pedestal_b": {"height": 1.0, "yaw": 0.0},
	# v0.9.0 HB3: the owner's eight hub pieces (delivered 2026-10-23, art list §4b; scripts/assets/hb3_prep.py), written
	# at their size in the game: "as_is" keeps the file's frame (no turn, no centring, no scale). The wall segment is
	# in the plaza's frame (re-bent onto its ring, centre at the origin), the gate and its doors in the whole gate's.
	&"hub_wall_segment": {"as_is": true},
	&"hub_pillar_brazier": {"as_is": true},
	&"hub_floor_rune": {"as_is": true},
	&"hub_sealed_gate": {"as_is": true},
	&"hub_sealed_gate_doors": {"as_is": true},
	&"hub_credits_stone": {"as_is": true},
	&"hub_trophy_wall": {"as_is": true},
	&"hub_crates": {"as_is": true},
	&"hub_crystal_planter": {"as_is": true},
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
	var as_is: bool = spec.get("as_is", false)  # v0.9.0 HB3: prepared in the game's frame and size
	var turn := Basis(Vector3.UP, 0.0 if as_is else float(spec.get("yaw", FRONT_YAW)))
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
	if as_is:
		scale = Vector3.ONE
		base = Vector3.ZERO
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
