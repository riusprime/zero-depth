extends SceneTree
## v0.8.0 N10 (option B, owner O67): decimated copies of the owner's four kit wall pieces, so a wall laid edge to edge
## from them costs a fraction of today's triangles. Per piece: its raw surface (ModelLibrary.first_surface, as
## KitModels reads it), its vertices welded by position (the AI generator splits every UV seam, which stops Godot's
## simplifier at 2.3-5.9k triangles), simplified with ImporterMesh.generate_lods (meshoptimizer), the level nearest
## TARGET_TRIS at or below TARGET_MAX taken, and each kept triangle given back its own UV chart (of the original
## vertices at each welded corner, the three whose UVs lie closest together), so the texture stays where it was.
## Saved as assets/models/kit_lod/<id>_lod.res (an ArrayMesh in the raw model's space with the piece's own material:
## KitModels.get_lod_piece normalises it as the original). Prints each piece's triangles before and after and the
## file's sha256 (for assets/models/manifest.json).
##   godot --headless --path . -s scripts/assets/kit_lod.gd

const PIECES: Array[StringName] = [&"wall_1m", &"wall_2m", &"wall_broken", &"wall_pillar"]
const OUT_DIR := "res://assets/models/kit_lod/"
const TARGET_TRIS := 2200
const TARGET_MAX := 3000
const CANDIDATES := 6


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := false
	for id in PIECES:
		var path := KitModels.DIR + String(id) + ".glb"
		var surface := ModelLibrary.first_surface(load(path) as PackedScene)
		if surface.is_empty():
			push_error("kit_lod: no surface in " + path)
			failed = true
			continue
		var arrays: Array = surface["arrays"]
		var before := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var lod := decimate(arrays)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lod)
		mesh.surface_set_material(0, surface["material"])
		var out := OUT_DIR + String(id) + "_lod.res"
		if ResourceSaver.save(mesh, out) != OK:
			push_error("kit_lod: could not save " + out)
			failed = true
			continue
		var after := (lod[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		print(
			(
				"%s: %d -> %d triangles  %s  %s"
				% [id, before, after, FileAccess.get_sha256(out), out.trim_prefix("res://")]
			)
		)
	quit(1 if failed else 0)


## The decimated surface (indexed; vertices, normals, UVs and tangents from the original).
static func decimate(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Weld by position.
	var key_of := {}
	var rep := PackedInt32Array()
	rep.resize(verts.size())
	var dups: Array = []
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wuv := PackedVector2Array()
	for k in verts.size():
		var v := verts[k]
		var key := Vector3i(roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0))
		if not key_of.has(key):
			key_of[key] = wv.size()
			wv.append(v)
			wn.append(normals[k])
			wuv.append(uvs[k])
			dups.append([])
		rep[k] = key_of[key]
		(dups[rep[k]] as Array).append(k)
	var widx := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var a := rep[idx[t]]
		var b := rep[idx[t + 1]]
		var c := rep[idx[t + 2]]
		if a == b or b == c or a == c:
			continue
		widx.append_array([a, b, c])
	var warr := []
	warr.resize(Mesh.ARRAY_MAX)
	warr[Mesh.ARRAY_VERTEX] = wv
	warr[Mesh.ARRAY_NORMAL] = wn
	warr[Mesh.ARRAY_TEX_UV] = wuv
	warr[Mesh.ARRAY_INDEX] = widx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, warr)
	im.generate_lods(KitModels.LOD_NORMAL_MERGE_DEG, KitModels.LOD_NORMAL_SPLIT_DEG, [])
	var pick := widx
	var best := INF
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		var n := li.size() / 3
		if n <= TARGET_MAX and absf(n - TARGET_TRIS) < best:
			best = absf(n - TARGET_TRIS)
			pick = li
	# Back to the original vertices: per triangle, the duplicates whose UVs sit closest together.
	var remap := {}
	var out_idx := PackedInt32Array()
	var order := PackedInt32Array()
	for t in range(0, pick.size(), 3):
		var ca := _few(dups[pick[t]])
		var cb := _few(dups[pick[t + 1]])
		var cc := _few(dups[pick[t + 2]])
		var choice := [ca[0], cb[0], cc[0]]
		var spread := INF
		for a in ca:
			for b in cb:
				for c in cc:
					var s := (
						uvs[a].distance_to(uvs[b])
						+ uvs[b].distance_to(uvs[c])
						+ uvs[c].distance_to(uvs[a])
					)
					if s < spread:
						spread = s
						choice = [a, b, c]
		for v: int in choice:
			if not remap.has(v):
				remap[v] = order.size()
				order.append(v)
			out_idx.append(remap[v])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		var src = arrays[slot]
		var dst = src.duplicate()
		dst.resize(order.size())
		for k in order.size():
			dst[k] = src[order[k]]
		out[slot] = dst
	out[Mesh.ARRAY_INDEX] = out_idx
	return out


## At most CANDIDATES of a welded vertex's originals, one per distinct UV (a point where many triangles meet can
## have dozens of copies with the same UV).
static func _few(all: Array) -> Array:
	return all if all.size() <= CANDIDATES else all.slice(0, CANDIDATES)
