extends SceneTree
## v0.11.0 O17d: the UV atlas mi_prep.py's bake needs, when the Python xatlas package isn't installed (no wheel for this
## PC's Python 3.14, and no compiler to build one). Godot embeds xatlas for its lightmap UVs (ArrayMesh.lightmap_unwrap,
## editor builds); this script hands it the meshes (one surface each, all packed into ONE atlas, as mi_prep's own
## xatlas call packs every part) and writes each surface's new vertices back. An offline tool: nothing in the game
## calls it. scripts/assets/o17_prep_cinder_priest.py wraps it as an xatlas stand-in (XatlasViaGodot).
##   godot --headless --path . -s scripts/assets/gd_unwrap_xatlas.gd -- <in.bin> <out.bin> <texel size (m)>
## In (little-endian): uint32 mesh count M; per mesh: uint32 V, uint32 T, V x 3 float32 positions, V x 3 float32
## normals, T x 3 uint32 indices.
## Out: uint32 M; per mesh: uint32 V', uint32 N, V' x 3 float32 positions, V' x 2 float32 UVs (0..1 over the atlas),
## N uint32 indices (the faces in the input's order, each corner one of the input face's corners, moved nowhere).
## Prints one line: `gd_unwrap: meshes=<M> in_tris=<n> out_verts=<n> err=<Error>`.


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
	var n_mesh := f.get_32()
	var in_tris := 0
	for _m in n_mesh:
		var nv := f.get_32()
		var nt := f.get_32()
		var verts := PackedVector3Array()
		verts.resize(nv)
		for k in nv:
			verts[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		var normals := PackedVector3Array()
		normals.resize(nv)
		for k in nv:
			normals[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
		var idx := PackedInt32Array()
		idx.resize(nt * 3)
		for k in nt * 3:
			idx[k] = f.get_32()
		in_tris += nt
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	f.close()
	var err := mesh.lightmap_unwrap(Transform3D.IDENTITY, float(args[2]))
	var w := FileAccess.open(args[1], FileAccess.WRITE)
	w.store_32(mesh.get_surface_count())
	var out_verts := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		out_verts += v.size()
		w.store_32(v.size())
		w.store_32(ix.size())
		for p in v:
			w.store_float(p.x)
			w.store_float(p.y)
			w.store_float(p.z)
		for k in v.size():
			var t := uv[k] if k < uv.size() else Vector2.ZERO
			w.store_float(t.x)
			w.store_float(t.y)
		for i in ix:
			w.store_32(i)
	w.close()
	print(
		(
			"gd_unwrap: meshes=%d in_tris=%d out_verts=%d err=%d"
			% [mesh.get_surface_count(), in_tris, out_verts, err]
		)
	)
	quit(0 if err == OK else 1)
