extends SceneTree
## v0.9.0 MI2: mi_prep.py's simplifier when the Python meshoptimizer package isn't installed (owner, 2026-10-22: "Use
## Godot's simplifier"; it has no Windows build). Godot embeds meshoptimizer for its LODs; this script hands one mesh
## to it and writes the simplified indices back. An offline tool: nothing in the game calls it.
##   godot --headless --path . -s scripts/assets/gd_simplify.gd -- <in.bin> <out.bin> <target triangles>
## In (little-endian): uint32 vertex count V, uint32 index count N, V x 3 float32 positions, N uint32 indices.
## Out: uint32 index count M, M uint32 indices into the same vertices, then a float32 -1 (the error: neither route
## reports it to a script).
## Two routes, the first the build has:
## - SurfaceTool.generate_lod(nd_threshold, target_index_count) (deprecated, still in 4.7.2): meshopt_simplify on
##   positions only, aimed at the exact target, with no error limit (as mi_prep's own meshoptimizer call). It always
##   locks the mesh's open borders (measured 2026-10-22 on a 60 x 60 open grid, 6,962 triangles to 500, 1,234 and
##   5,000: exactly the target each time, every border vertex kept): a caller's "don't lock" is not honoured;
## - else ImporterMesh.generate_lods: the LOD chain (about 4, 8, 16 ... triangles, doubling), the level closest to and
##   not above the target (up to half the target; it may weigh normals and lock borders as the importer does).
## Prints one line: `gd_simplify: route=<lod|lods> in=<tris> target=<tris> out=<tris>`.

## The normalised error the exact route may reach (no limit: the triangle count decides, as mi_prep's call).
const NO_ERROR_LIMIT := 1.0e9


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("gd_simplify: usage -- <in.bin> <out.bin> <target triangles>")
		quit(1)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	if f == null:
		push_error("gd_simplify: cannot read " + args[0])
		quit(1)
		return
	var nv := f.get_32()
	var ni := f.get_32()
	var verts := PackedVector3Array()
	verts.resize(nv)
	for k in nv:
		verts[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
	var idx := PackedInt32Array()
	idx.resize(ni)
	for k in ni:
		idx[k] = f.get_32()
	f.close()
	var target := int(args[2])
	var route := "lod"
	var out := PackedInt32Array()
	var err := -1.0
	var st := SurfaceTool.new()
	if st.has_method("generate_lod"):
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in verts:
			st.add_vertex(v)
		for i in idx:
			st.add_index(i)
		out = st.call("generate_lod", NO_ERROR_LIMIT, target * 3)
	else:
		route = "lods"
		out = _from_lod_chain(verts, idx, target)
	var w := FileAccess.open(args[1], FileAccess.WRITE)
	w.store_32(out.size())
	for i in out:
		w.store_32(i)
	w.store_float(err)
	w.close()
	print("gd_simplify: route=%s in=%d target=%d out=%d" % [route, ni / 3, target, out.size() / 3])
	quit(0)


## The LOD route: Godot's own chain, the level with the most triangles not above `target` (the full mesh when it is
## already under it).
func _from_lod_chain(
	verts: PackedVector3Array, idx: PackedInt32Array, target: int
) -> PackedInt32Array:
	if idx.size() / 3 <= target:
		return idx
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var n := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
		for c in 3:
			normals[idx[t + c]] += n
	for k in normals.size():
		normals[k] = normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
	arrays[Mesh.ARRAY_NORMAL] = normals
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(180.0, 180.0, [])
	var best := PackedInt32Array()
	for lod in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, lod)
		if li.size() / 3 <= target and li.size() > best.size():
			best = li
	return best
