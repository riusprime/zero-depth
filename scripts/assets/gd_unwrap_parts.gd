extends SceneTree
## v0.11.0 O17c: the UV atlas for o17_prep_*.py when the Python xatlas package can't be installed (no wheel for this
## PC's Python 3.14 and no compiler to build one). Godot's editor build embeds xatlas for its lightmap UVs
## (ArrayMesh.lightmap_unwrap); this script hands it the parts of one model, one surface each, so they share one atlas,
## and writes each part's charts back. An offline tool: nothing in the game calls it.
##   godot --headless --path . -s scripts/assets/gd_unwrap_parts.gd -- <in.bin> <out.bin> <texel size (m)>
## In (little-endian): uint32 mesh count M; per mesh: uint32 vertex count V, uint32 index count N, V x 3 float32
## positions, V x 3 float32 normals, N uint32 indices.
## Out: uint32 atlas width, uint32 atlas height; per mesh: uint32 vertex count V', V' x 3 float32 positions, V' x 2
## float32 UVs (0..1 over the atlas's width and height), uint32 index count N', N' uint32 indices.
## Prints one line: `gd_unwrap: meshes=<M> atlas=<w>x<h>`.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("gd_unwrap: usage -- <in.bin> <out.bin> <texel size>")
		quit(1)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	if f == null:
		push_error("gd_unwrap: cannot read " + args[0])
		quit(1)
		return
	var mesh := ArrayMesh.new()
	var count := f.get_32()
	for m in count:
		var nv := f.get_32()
		var ni := f.get_32()
		var verts := PackedVector3Array()
		verts.resize(nv)
		for k in nv:
			verts[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		var normals := PackedVector3Array()
		normals.resize(nv)
		for k in nv:
			normals[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		var idx := PackedInt32Array()
		idx.resize(ni)
		for k in ni:
			idx[k] = f.get_32()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	f.close()
	var err := mesh.lightmap_unwrap(Transform3D.IDENTITY, float(args[2]))
	if err != OK:
		push_error("gd_unwrap: lightmap_unwrap failed (%d)" % err)
		quit(1)
		return
	var size := mesh.lightmap_size_hint
	var w := FileAccess.open(args[1], FileAccess.WRITE)
	w.store_32(size.x)
	w.store_32(size.y)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		w.store_32(verts.size())
		for v in verts:
			w.store_float(v.x)
			w.store_float(v.y)
			w.store_float(v.z)
		for uv in uv2:
			w.store_float(uv.x)
			w.store_float(uv.y)
		w.store_32(idx.size())
		for i in idx:
			w.store_32(i)
	w.close()
	print("gd_unwrap: meshes=%d atlas=%dx%d" % [count, size.x, size.y])
	quit(0)
