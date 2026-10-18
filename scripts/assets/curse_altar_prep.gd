extends SceneTree
## v0.8.0 N17 (owner O75; delivered 2026-10-18: "here last model for the curse room"): the owner's raw curse altar (a
## Tripo file: one mesh, one material with base colour, metal-roughness and normal maps at the generator's size)
## made ready for the game: read at run time (GLTFDocument; the raw folder is .gdignore'd), its surface decimated the
## way scripts/assets/kit_lod.gd decimates the kit walls (welded, ImporterMesh.generate_lods, the level nearest
## 2,200 triangles at or below 3,000, each triangle's own UV chart kept), its maps downscaled to at most TEXTURE_PX,
## and written back as a .glb. Not scaled or turned: ShopModels (`curse_altar` spec) fits it into its 1.4 x 1.4 x
## 1.0 m box in game. Prints the triangles before and after, the map sizes and the file's sha256 (for
## assets/models/manifest.json). Writes only the output file.
##   godot --headless --path . -s scripts/assets/curse_altar_prep.gd -- <raw.glb> assets/models/shop/curse_altar.glb

const KitLod := preload("res://scripts/assets/kit_lod.gd")
const TEXTURE_PX := 1024


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("curse_altar_prep: usage -- <raw.glb> <out.glb>")
		quit(1)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(args[0], state) != OK:
		push_error("curse_altar_prep: could not read " + args[0])
		quit(1)
		return
	var scene := doc.generate_scene(state)
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		push_error("curse_altar_prep: no mesh")
		quit(1)
		return
	var src := found[0] as MeshInstance3D
	var arrays: Array = src.mesh.surface_get_arrays(0)
	var before := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var lod: Array = KitLod.decimate(arrays)
	var after := (lod[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var mat := src.get_active_material(0) as StandardMaterial3D
	var sizes := []
	for slot in ["albedo_texture", "roughness_texture", "metallic_texture", "normal_texture"]:
		var tex: Texture2D = mat.get(slot)
		if tex == null:
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		if maxi(img.get_width(), img.get_height()) > TEXTURE_PX:
			var k := float(TEXTURE_PX) / maxi(img.get_width(), img.get_height())
			img.resize(
				roundi(img.get_width() * k), roundi(img.get_height() * k), Image.INTERPOLATE_LANCZOS
			)
		mat.set(slot, ImageTexture.create_from_image(img))
		sizes.append("%s %dx%d" % [slot, img.get_width(), img.get_height()])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lod)
	mesh.surface_set_material(0, mat)
	var root := Node3D.new()
	root.name = "curse_altar"
	var mi := MeshInstance3D.new()
	mi.name = "curse_altar_mesh"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var out_doc := GLTFDocument.new()
	out_doc.image_format = "JPEG"
	out_doc.lossy_quality = 0.9
	var out_state := GLTFState.new()
	var out := args[1]
	if (
		out_doc.append_from_scene(root, out_state) != OK
		or out_doc.write_to_filesystem(out_state, out) != OK
	):
		push_error("curse_altar_prep: could not write " + out)
		quit(1)
		return
	var aabb := mesh.get_aabb()
	print(
		(
			"curse_altar: %d -> %d triangles  size %s  maps %s  %s  %s"
			% [before, after, aabb.size, sizes, FileAccess.get_sha256(out), out]
		)
	)
	root.free()
	scene.free()
	quit(0)
