extends SceneTree
## v0.8.0 MI: renders the owner's v0.8.0 models (raw or prepared) as a contact sheet, read at run time with
## GLTFDocument (so the raw files under unprocessed_images/, which Godot does not import, render too). Needs a
## renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1500x300 -s scripts/shots/mi_models.gd -- \
##     src=unprocessed_images/models_v080 [ids=a,b] [parts=1] [tag=_after]
## Each model is scaled to 1 unit tall and drawn five times: turned 0/90/180/270 degrees about Y under a camera on +Z
## looking down -Z, then from above (+X right, -Z up). The red stick is the file's +X, the blue its +Z. With parts=1
## every mesh node gets its own flat colour (the enemy part splits). Writes build/shots/<version>/mi_models/.

const CELL := Vector2i(300, 300)
const PART_COLORS := [
	Color("#E05050"),
	Color("#50C050"),
	Color("#5070E0"),
	Color("#E0C040"),
	Color("#C050C0"),
	Color("#40C0C0"),
	Color("#E08030"),
	Color("#909090"),
]

var _src := "unprocessed_images/models_v080"
var _ids: Array[String] = []
var _parts := false
var _tag := ""
var _dir := ""
var _frame := 0
var _k := 0
var _vp: SubViewport


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_src = String(args.get("src", _src))
	_parts = String(args.get("parts", "0")) == "1"
	_tag = String(args.get("tag", ""))
	if args.has("ids"):
		for id: String in String(args["ids"]).split(","):
			_ids.append(id)
	else:
		for f in DirAccess.get_files_at(ProjectSettings.globalize_path("res://" + _src)):
			if f.ends_with(".glb"):
				_ids.append(f.get_basename())
		_ids.sort()
	_dir = "res://build/shots/%s/mi_models/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("mi_models: renderer=%s" % RenderingServer.get_current_rendering_method())
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(CELL.x * 5, CELL.y)
	root.add_child(_vp)
	_build(0)


func _load(id: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var path := ProjectSettings.globalize_path("res://" + _src.path_join(id + ".glb"))
	if doc.append_from_file(path, state) != OK:
		push_error("mi_models: cannot read " + path)
		return Node3D.new()
	return doc.generate_scene(state) as Node3D


func _build(k: int) -> void:
	for c in _vp.get_children():
		c.queue_free()
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#30343C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9CEDA")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	scene.add_child(light)
	var probe := _load(_ids[k])
	var box := AABB()
	var first := true
	var tris := 0
	for mi: MeshInstance3D in probe.find_children("*", "MeshInstance3D", true, false):
		var b := (
			mi.global_transform * mi.mesh.get_aabb() if mi.is_inside_tree() else mi.mesh.get_aabb()
		)
		box = b if first else box.merge(b)
		first = false
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	probe.free()
	var unit := 1.0 / maxf(box.size.y, 0.0001)
	print("mi_models: %s bounds %s triangles %d" % [_ids[k], box, tris])
	for v in 5:
		var holder := Node3D.new()
		holder.position = Vector3((v - 2) * 1.0, 0, 0)
		scene.add_child(holder)
		var inner := _load(_ids[k])
		inner.scale = Vector3.ONE * unit
		inner.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * unit
		holder.add_child(inner)
		if _parts:
			# Each part (mesh node) its own colour; its glow surface yellow-white, its role surface lighter.
			var n := 0
			for mi: MeshInstance3D in inner.find_children("*", "MeshInstance3D", true, false):
				for s in mi.mesh.get_surface_count():
					var src := mi.mesh.surface_get_material(s)
					var nm := src.resource_name if src != null else ""
					var m := StandardMaterial3D.new()
					var c: Color = PART_COLORS[n % PART_COLORS.size()]
					m.albedo_color = (
						Color("#FFF6A0")
						if nm == "glow"
						else (c.lightened(0.45) if nm == "role" else c)
					)
					mi.set_surface_override_material(s, m)
				n += 1
		if v < 4:
			holder.rotation = Vector3(0, v * PI * 0.5, 0)
		else:
			holder.rotation = Vector3(PI * 0.5, 0, 0)
			holder.position.y = 0.5
		for ax: Array in [[Vector3(0.35, 0, 0), Color.RED], [Vector3(0, 0, 0.35), Color.BLUE]]:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.02, 0.02, 0.02) + (ax[0] as Vector3).abs()
			m.mesh = b
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ax[1]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material_override = mat
			m.position = (ax[0] as Vector3) * 0.5
			holder.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.15
	cam.position = Vector3(0, 0.5, 5)
	scene.add_child(cam)
	cam.current = true
	_frame = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 20:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := _dir + "%s%s%s.png" % [_ids[_k], _tag, "_parts" if _parts else ""]
	img.save_png(path)
	print("mi_models: ", path)
	_k += 1
	if _k >= _ids.size():
		return true
	_build(_k)
	return false
