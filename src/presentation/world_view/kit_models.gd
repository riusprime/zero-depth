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
	&"rock_large": {"yaw": 0.0, "height": 1.2, "role": &"cover", "foot": Vector2(1.5, 1.5)},
	&"dead_tree": {"yaw": 0.0, "height": 2.2, "role": &"cover", "foot": Vector2(1.0, 1.0)},
	&"fire_barrel": {"yaw": 0.0, "height": 0.9, "role": &"light"},
	&"brazier_pole": {"yaw": 0.0, "height": 2.0, "role": &"light"},
	&"chest": {"yaw": PI * 0.5, "height": 0.6, "role": &"reward"},
	&"rubble_small": {"yaw": 0.0, "height": 0.25, "role": &"decor"},
	&"grass_tuft": {"yaw": 0.0, "height": 0.4, "role": &"decor"},
	&"debris_low": {"yaw": PI * 0.5, "height": 0.2, "role": &"decor"},
	# v0.6.0 Step SR: the gamble shrine (GambleShrineView), its front (the slot window) on +Z. 1.7 m tall puts its
	# footprint at 1.58 x 1.12 m, the old obelisk's plinth width over the sim's 1 m square (Gamble.collider).
	&"gamble_shrine": {"yaw": 0.0, "height": 1.7, "role": &"shrine"},
	# v0.8.0 MI: the owner's v0.8.0 pieces (scripts/assets/mi_prep.py: turned long side onto +X, sized, simplified and
	# re-textured offline, so yaw 0). Role &"biome": a biome's own piece, drawn only where its BiomeLook pools name it
	# (owner O78: every piece only in the biome it fits); a missing one drops out of the pools (has_structure ignores
	# it). "foot": its footprint from the request row (W x D, m), for decoration and props placed at natural size.
	# "tint": how much of the biome's cover hue it takes (0: its own colours; the kit's pieces take all of
	# StageKit.TINT_AMOUNT). "min_foot" / "max_foot": the shorter side of a cover footprint it may fill (m; outside
	# that, the pool's other pieces draw). Role &"void": a piece of the void past the floor's edge (BiomeEdge).
	&"building_corner":
	{
		"yaw": 0.0,
		"height": 3.0,
		"role": &"biome",
		"foot": Vector2(2.0, 2.0),
		"tint": 0.0,
		"min_foot": 1.8
	},
	&"ladder_frame":
	{"yaw": 0.0, "height": 2.0, "role": &"biome", "foot": Vector2(1.0, 0.4), "tint": 0.0},
	&"column_broken":
	{
		"yaw": 0.0,
		"height": 1.6,
		"role": &"biome",
		"foot": Vector2(1.0, 1.0),
		"tint": 0.0,
		"max_foot": 1.4
	},
	&"pipe_bundle":
	{"yaw": 0.0, "height": 0.9, "role": &"biome", "foot": Vector2(2.0, 0.8), "tint": 0.0},
	&"barricade":
	{"yaw": 0.0, "height": 1.0, "role": &"biome", "foot": Vector2(2.0, 0.5), "tint": 0.0},
	&"tire_stack":
	{
		"yaw": 0.0,
		"height": 0.9,
		"role": &"biome",
		"foot": Vector2(0.9, 0.9),
		"tint": 0.0,
		"max_foot": 1.4
	},
	&"boulder_small":
	{"yaw": 0.0, "height": 0.35, "role": &"decor", "foot": Vector2(0.5, 0.5), "tint": 0.0},
	&"rock_spire":
	{
		"yaw": 0.0,
		"height": 2.2,
		"role": &"biome",
		"foot": Vector2(1.0, 1.0),
		"tint": 0.0,
		"max_foot": 1.6
	},
	&"stone_arch":
	{
		"yaw": 0.0,
		"height": 2.4,
		"role": &"biome",
		"foot": Vector2(3.0, 1.0),
		"tint": 0.0,
		"min_foot": 0.9
	},
	&"mushroom_cluster":
	{"yaw": 0.0, "height": 0.5, "role": &"decor", "foot": Vector2(0.6, 0.6), "tint": 0.0},
	&"bone_pile":
	{"yaw": 0.0, "height": 0.3, "role": &"decor", "foot": Vector2(0.8, 0.6), "tint": 0.0},
	&"floating_island_moss":
	{"yaw": 0.0, "height": 2.0, "role": &"void", "foot": Vector2(2.0, 2.0), "tint": 0.0},
	&"mesa_chunk":
	{"yaw": 0.0, "height": 1.4, "role": &"biome", "foot": Vector2(1.5, 1.5), "tint": 0.0},
	&"dry_shrub":
	{"yaw": 0.0, "height": 0.4, "role": &"decor", "foot": Vector2(0.5, 0.5), "tint": 0.0},
	&"cactus":
	{
		"yaw": 0.0,
		"height": 1.6,
		"role": &"biome",
		"foot": Vector2(0.6, 0.6),
		"tint": 0.0,
		"max_foot": 1.1
	},
	&"wagon_wreck":
	{"yaw": 0.0, "height": 1.4, "role": &"biome", "foot": Vector2(2.4, 1.4), "tint": 0.0},
	&"cattle_skull_post":
	{
		"yaw": 0.0,
		"height": 1.4,
		"role": &"biome",
		"foot": Vector2(0.4, 0.4),
		"tint": 0.0,
		"max_foot": 0.8
	},
	&"snow_drift":
	{"yaw": 0.0, "height": 0.28, "role": &"decor", "foot": Vector2(0.9, 0.6), "tint": 0.0},
	&"ice_shard":
	{"yaw": 0.0, "height": 0.4, "role": &"decor", "foot": Vector2(0.5, 0.5), "tint": 0.0},
	&"ice_rock":
	{"yaw": 0.0, "height": 1.2, "role": &"biome", "foot": Vector2(1.2, 1.2), "tint": 0.0},
	# The owner's `ice_floe` file holds a frozen boat half sunk in snow (the boat_wreck request): installed as that.
	&"boat_wreck":
	{"yaw": 0.0, "height": 1.2, "role": &"biome", "foot": Vector2(3.0, 1.4), "tint": 0.0},
	&"fish_rack":
	{"yaw": 0.0, "height": 1.6, "role": &"biome", "foot": Vector2(1.4, 0.6), "tint": 0.0},
	&"star_crystal":
	{"yaw": 0.0, "height": 0.4, "role": &"decor", "foot": Vector2(0.5, 0.5), "tint": 0.0},
	&"meteorite":
	{"yaw": 0.0, "height": 0.26, "role": &"decor", "foot": Vector2(0.6, 0.5), "tint": 0.0},
	&"star_monolith":
	{"yaw": 0.0, "height": 1.6, "role": &"biome", "foot": Vector2(1.0, 1.0), "tint": 0.0},
	&"floating_island_starfall":
	{"yaw": 0.0, "height": 2.0, "role": &"void", "foot": Vector2(2.0, 2.0), "tint": 0.0},
	&"void_spike":
	{"yaw": 0.0, "height": 2.5, "role": &"void", "foot": Vector2(1.0, 1.0), "tint": 0.0},
	&"ruined_observatory":
	{
		"yaw": 0.0,
		"height": 2.6,
		"role": &"biome",
		"foot": Vector2(2.5, 2.5),
		"tint": 0.0,
		"min_foot": 1.9
	},
}

## The chest's lid seam, as a fraction of its height (an empty band in its vertex heights at 0.55-0.575; the
## lock is on its -Z face after the yaw, so the hinge is the +Z edge of the seam).
const CHEST_LID_CUT := 0.56
## Level-of-detail generation (ImporterMesh.generate_lods): normals merge below / split above these angles.
const LOD_NORMAL_MERGE_DEG := 25.0
const LOD_NORMAL_SPLIT_DEG := 60.0
## v0.8.0 P3 (owner O29, "the Red, Blue, and Original biomes experience lag"): a scattered decoration piece (grass,
## rubble, debris: 0.2-0.4 m, a few dozen pixels on screen, hundreds per floor) is drawn from its coarsest generated
## level of detail (the kit's are 9.8-12.8k triangles each: ~20 million triangles a floor in the first three biomes,
## against ~0.5 million in Frozen Shore and Starfall, whose decoration is code-made). A piece of DECOR_TRIS triangles
## or fewer is drawn as it is.
const DECOR_TRIS := 1000

## Where pieces are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}
static var _split_cache := {}
static var _decor_cache := {}


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
	_split_cache.clear()
	_decor_cache.clear()


## A piece cut in two at height `cut` (a fraction of its height), at its natural size in metres, centred on x and
## z with its bottom at 0: {"body": ArrayMesh (triangles with any corner below the cut), "lid": ArrayMesh (the
## rest), "material", "size": Vector3}. {} when the piece is missing or has no index buffer.
static func split(id: StringName, cut: float) -> Dictionary:
	var key := "%s/%s" % [id, cut]
	if _split_cache.has(key):
		return _split_cache[key]
	var piece := get_piece(id)
	var out := {}
	if not piece.is_empty():
		var arrays := (piece["mesh"] as ArrayMesh).surface_get_arrays(0)
		var size: Vector3 = piece["size"]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var unit := verts.duplicate()
		for k in verts.size():
			verts[k] = verts[k] * size
		arrays[Mesh.ARRAY_VERTEX] = verts
		var idx: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		if not idx.is_empty():
			var body := PackedInt32Array()
			var lid := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var low := minf(minf(unit[idx[t]].y, unit[idx[t + 1]].y), unit[idx[t + 2]].y)
				var into := lid if low >= cut else body
				into.append(idx[t])
				into.append(idx[t + 1])
				into.append(idx[t + 2])
			out = {"material": piece["material"], "size": size}
			for part: Array in [["body", body], ["lid", lid]]:
				var m := ArrayMesh.new()
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, part[1]))
				out[part[0]] = m
	_split_cache[key] = out
	return out


## The surface as a mesh with generated levels of detail (the owner's pieces are 7-14k triangles each; a level
## at about half and one at about a quarter, picked by on-screen size). Where the engine build can't simplify,
## the mesh simply has no LODs.
static func _with_lods(arrays: Array) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(LOD_NORMAL_MERGE_DEG, LOD_NORMAL_SPLIT_DEG, [])
	return im.get_mesh()


## v0.8.0 P3: `mesh` as a scattered decoration piece draws it: its coarsest generated level of detail (the same
## vertices, normals, UVs and material; the generator keeps UV seams, so the kit's pieces stop at 3.2-4.7k triangles)
## when it has more than DECOR_TRIS triangles and one surface; otherwise `mesh` itself. Cached per mesh.
static func decor_mesh(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	var key := mesh.get_instance_id()
	if _decor_cache.has(key):
		return _decor_cache[key]
	var out := mesh
	if mesh.get_surface_count() == 1 and mesh is ArrayMesh:
		var arrays := mesh.surface_get_arrays(0)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() / 3 > DECOR_TRIS:
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
			im.generate_lods(LOD_NORMAL_MERGE_DEG, LOD_NORMAL_SPLIT_DEG, [])
			var n := im.get_surface_lod_count(0)
			if n > 0:
				arrays[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(0, n - 1)
				var low := ArrayMesh.new()
				low.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				out = low
	_decor_cache[key] = out
	return out


## Surface arrays keeping only the vertices `idx` uses (so each part's bounds are its own), re-indexed.
static func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	for v in idx:
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		new_idx.append(remap[v])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for slot in [
		Mesh.ARRAY_VERTEX,
		Mesh.ARRAY_NORMAL,
		Mesh.ARRAY_TEX_UV,
		Mesh.ARRAY_TEX_UV2,
		Mesh.ARRAY_COLOR
	]:
		if arrays[slot] == null:
			continue
		var src = arrays[slot]
		var dst = src.duplicate()
		dst.resize(order.size())
		for k in order.size():
			dst[k] = src[order[k]]
		out[slot] = dst
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var t2 := PackedFloat32Array()
		t2.resize(order.size() * 4)
		for k in order.size():
			for c in 4:
				t2[k * 4 + c] = ts[order[k] * 4 + c]
		out[Mesh.ARRAY_TANGENT] = t2
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


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
	var mesh := _with_lods(arrays)
	var height: float = spec["height"]
	var size := Vector3(ext.x, ext.y, ext.z) * (height / ext.y)
	return {"mesh": mesh, "material": surface["material"], "size": size}
