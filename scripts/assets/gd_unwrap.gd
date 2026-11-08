extends SceneTree
## v0.11.0 O17b: the UV atlas step of the model prep scripts when the Python xatlas package isn't installed (it has no
## wheel for this PC's Python 3.14 and no compiler to build one). Godot's editor build embeds xatlas for its lightmap
## UVs: this script hands it the mesh's surfaces as one ArrayMesh (ArrayMesh.lightmap_unwrap packs them all into one
## atlas) and writes each surface back with its new UV2. An offline tool: nothing in the game calls it.
##   godot --headless --path . -s scripts/assets/gd_unwrap.gd -- <in.bin> <out.bin> <texel size (model units)>
## In (little-endian): uint32 surface count S; per surface: uint32 vertex count V, uint32 index count N, V x 3 float32
## positions, V x 3 float32 normals, N uint32 indices.
## Out: uint32 S; per surface: uint32 V', uint32 N', V' x 3 float32 positions, V' x 2 float32 UVs (0..1 over the
## atlas), N' uint32 indices (the surface's faces, in order: xatlas keeps them).
## Prints one line: `gd_unwrap: surfaces=<S> verts_in=<n> verts_out=<n>`.


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
	var am := ArrayMesh.new()
	var n_in := 0
	var count := f.get_32()
	for s in count:
		var nv := f.get_32()
		var ni := f.get_32()
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		verts.resize(nv)
		norms.resize(nv)
		for k in nv:
			verts[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		for k in nv:
			norms[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		var idx := PackedInt32Array()
		idx.resize(ni)
		for k in ni:
			idx[k] = f.get_32()
		n_in += nv
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_INDEX] = idx
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	f.close()
	var err := am.lightmap_unwrap(Transform3D.IDENTITY, float(args[2]))
	if err != OK:
		push_error("gd_unwrap: lightmap_unwrap failed (%d)" % err)
		quit(1)
		return
	var w := FileAccess.open(args[1], FileAccess.WRITE)
	w.store_32(am.get_surface_count())
	var n_out := 0
	for s in am.get_surface_count():
		var a := am.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		w.store_32(v.size())
		w.store_32(ix.size())
		for p in v:
			w.store_float(p.x)
			w.store_float(p.y)
			w.store_float(p.z)
		for t in uv:
			w.store_float(t.x)
			w.store_float(t.y)
		for i in ix:
			w.store_32(i)
		n_out += v.size()
	w.close()
	print("gd_unwrap: surfaces=%d verts_in=%d verts_out=%d" % [count, n_in, n_out])
	quit(0)
