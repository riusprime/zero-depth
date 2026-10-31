extends GutTest
## v0.10.0 VX0 (VFX_PACK I1): the owner's purchased Binbun VFX pack is installed whole: every effect scene under
## assets/BinbunVFX/**/effects/** loads and instantiates, and the pack table (data/vfx/pack_fx.tres) names scenes
## that exist, in known families, with unique ids.

const ROOT := "res://assets/BinbunVFX"


func _scenes(dir: String, out: PackedStringArray, in_effects: bool) -> void:
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			var name := entry.trim_suffix("/")
			_scenes(dir.path_join(name), out, in_effects or name == "effects")
		elif in_effects and entry.ends_with(".tscn"):
			out.append(dir.path_join(entry))


func test_every_effect_scene_loads_and_instantiates() -> void:
	var scenes := PackedStringArray()
	_scenes(ROOT, scenes, false)
	scenes.sort()
	assert_gte(scenes.size(), 250, "the ten packs' effect scenes are installed")
	var bad := PackedStringArray()
	for path in scenes:
		var packed := load(path) as PackedScene
		if packed == null:
			bad.append(path)
			continue
		var node := packed.instantiate()
		if node == null:
			bad.append(path)
		else:
			node.free()
	assert_eq(bad.size(), 0, "scenes that did not load: %s" % ", ".join(bad))


func test_the_demo_scenes_are_not_installed() -> void:
	for path in [
		"res://assets/BinbunVFX/beam_vfx/beam_vfx_scene.tscn",
		"res://assets/BinbunVFX/fire_effects/demo.tscn",
	]:
		assert_false(ResourceLoader.exists(path), "%s is a demo" % path)


func test_the_pack_table_is_valid() -> void:
	var def := PackFx.shared_def()
	assert_not_null(def)
	assert_eq(def.validate().size(), 0, "valid")
	assert_gte(def.count(), 4)
	for k in def.count():
		assert_true(def.scenes[k].begins_with(ROOT + "/"), "%s is in the pack" % def.ids[k])
	var repo := ContentRepository.load_all()
	assert_not_null(repo.get_def(&"pack_fx", &"pack_fx"), "found through the repository")


func test_the_table_rejects_bad_rows() -> void:
	var def := PackFxDefinition.new()
	def.id = &"t"
	def.ids = [&"a", &"a"]
	def.scenes = PackedStringArray(["res://no/such.tscn", "res://no/such.tscn"])
	def.families = [&"explosion", &"bogus"]
	def.scales = PackedFloat32Array([1.0, 1.0])
	def.primary = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	def.secondary = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	def.tertiary = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	var codes := []
	for i in def.validate():
		codes.append(i.code)
	assert_has(codes, &"duplicate_id")
	assert_has(codes, &"missing_scene")
	assert_has(codes, &"bad_family")
	def.scales = PackedFloat32Array([1.0])
	codes.clear()
	for i in def.validate():
		codes.append(i.code)
	assert_has(codes, &"size_mismatch")
