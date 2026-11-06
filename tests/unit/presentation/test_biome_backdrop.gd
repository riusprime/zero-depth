extends GutTest
## v0.9.5 BG (owner line 8: "We are missing something for the background of the different biomes"; Q5: layered
## parallax planes, owner-made images): every biome has a Deep and a Mid plane far under its floor (Frozen Shore: the
## Deep image on the sea and one Mid plane just above it), both shaders ignore the fog, the planes follow the
## camera's focus, reduced motion stops the drift, and a missing image falls back to a code stand-in.

const MANIFEST := "res://assets/models/manifest.json"


func _backdrop(biome: StringName, sea: ShaderMaterial = null) -> BiomeBackdrop:
	var b := BiomeBackdrop.new()
	add_child_autofree(b)
	b.build(biome, Color(0.04, 0.05, 0.09), sea)
	return b


func _sea() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = BiomeEdge.WATER_SHADER
	return m


func _camera(at: Vector3) -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child_autofree(c)
	c.global_position = at
	c.look_at(at + Vector3(-1.0, -1.0, -1.0).normalized() * 10.0, Vector3.UP)
	return c


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func test_every_biome_has_two_layers_with_its_own_images() -> void:
	for biome: StringName in [&"ruins", &"night_rocks", &"red_canyon", &"starfall"]:
		var b := _backdrop(biome)
		assert_eq(b.layers.size(), 2, "%s: two planes" % biome)
		assert_eq(b.deep.position.y, BiomeBackdrop.DEEP_Y, "%s: Deep at -14" % biome)
		assert_lt(b.mid.position.y, -1.0, "%s: Mid far under the floor" % biome)
		assert_gt(b.mid.position.y, b.deep.position.y, "%s: Mid above Deep" % biome)
		assert_eq(b.stand_in, {"deep": false, "mid": false}, "%s: the owner's images load" % biome)
		var d := b.params("deep")
		assert_eq((d["tex"] as Texture2D).resource_path, BiomeBackdrop.texture_path(biome, "deep"))
		assert_eq(d["tile_m"], 42.0)
		assert_eq(d["parallax"], 0.35)
		assert_eq(d["alpha"], 1.0, "Deep is opaque")
		var m := b.params("mid")
		assert_eq((m["tex"] as Texture2D).resource_path, BiomeBackdrop.texture_path(biome, "mid"))
		assert_eq(m["tile_m"], 30.0)
		assert_eq(m["parallax"], 0.6)
		assert_eq(m["alpha"], 0.8)
		assert_eq(
			m["brightness"], BiomeBackdrop.MID_BRIGHTNESS[biome], "%s: Mid brightness" % biome
		)
		assert_eq((b.deep.mesh as QuadMesh).size, Vector2.ONE * 160.0, "160 m planes")


func test_night_rocks_planes_stay_below_its_islands() -> void:
	var b := _backdrop(&"night_rocks")
	assert_lte(b.mid.position.y, StarVoid.ISLAND_Y.x, "under the lowest island")


func test_frozen_shore_paints_the_sea_and_adds_one_mid_plane() -> void:
	var sea := _sea()
	var b := _backdrop(&"frozen_shore", sea)
	assert_eq(b.layers.size(), 1, "no Deep plane")
	assert_null(b.deep)
	assert_almost_eq(b.mid.position.y, -0.40, 0.001, "Mid just above the sea")
	assert_eq(b.params("mid")["alpha"], 0.5)
	assert_eq(b.params("mid")["brightness"], BiomeBackdrop.MID_BRIGHTNESS[&"frozen_shore"])
	var p := b.params("sea")
	assert_eq(
		(p["tex"] as Texture2D).resource_path, BiomeBackdrop.texture_path(&"frozen_shore", "deep")
	)
	assert_eq(p["tile"], 42.0)
	assert_eq(p["parallax"], 0.35)
	assert_gt(p["mix"], 0.0, "the image shows on the sea")
	assert_true(sea.shader.code.contains("SPECULAR"), "the sea keeps its shimmer")
	assert_true(sea.shader.code.contains("bd_tex"))


func test_the_frozen_sea_of_a_real_edge_takes_the_image() -> void:
	var edge := BiomeEdge.new()
	add_child_autofree(edge)
	var ground := [Rect2(-10, -10, 20, 20)]
	edge.build(&"water", ground, Rect2(-10, -10, 20, 20), Color("#436C8E"), 3)
	var b := _backdrop(&"frozen_shore", edge.water.material_override as ShaderMaterial)
	assert_not_null(b.sea)
	assert_eq(b.layers.size(), 1)


func test_no_shader_takes_the_fog() -> void:
	for biome: StringName in [&"ruins", &"starfall"]:
		var b := _backdrop(biome)
		for mi in b.layers:
			var code := (mi.material_override as ShaderMaterial).shader.code
			assert_true(code.contains("fog_disabled"), "%s %s: fog_disabled" % [biome, mi.name])
			assert_true(code.contains("unshaded"))
	var r := _backdrop(&"ruins")
	var c := (r.mid.material_override as ShaderMaterial).shader.code
	assert_true(c.contains("depth_draw_never") and c.contains("blend_mix"), "Mid blends, no depth")
	var d := (r.deep.material_override as ShaderMaterial).shader.code
	assert_false(d.contains("blend_mix"), "Deep is opaque")


func test_the_planes_follow_the_camera_focus() -> void:
	var b := _backdrop(&"ruins")
	var cam := _camera(Vector3(40.0, 50.0, 40.0))
	b.follow(cam)
	var d := -cam.global_transform.basis.z
	for mi in b.layers:
		var hit := cam.global_position + d * ((mi.position.y - 50.0) / d.y)
		assert_almost_eq(mi.position.x, hit.x, 0.01, "%s x" % mi.name)
		assert_almost_eq(mi.position.z, hit.z, 0.01, "%s z" % mi.name)
		var f: Vector2 = (mi.material_override as ShaderMaterial).get_shader_parameter("focus")
		assert_almost_eq(f.x, hit.x, 0.01)
	var before := b.deep.position
	cam.global_position += Vector3(10.0, 0.0, 0.0)
	b.follow(cam)
	assert_almost_eq(b.deep.position.x - before.x, 10.0, 0.01, "it moves with the camera")
	assert_eq(b.deep.position.y, BiomeBackdrop.DEEP_Y, "the heights never change")


func test_reduced_motion_stops_the_drift() -> void:
	var moving := _backdrop(&"starfall")
	assert_almost_eq((moving.params("deep")["drift"] as Vector2).length(), 0.010, 0.0001)
	assert_almost_eq((moving.params("mid")["drift"] as Vector2).length(), 0.020, 0.0001)
	ViewPrefs.reduced_motion = true
	var still := _backdrop(&"starfall")
	assert_eq(still.params("deep")["drift"], Vector2.ZERO)
	assert_eq(still.params("mid")["drift"], Vector2.ZERO)
	var f := _backdrop(&"frozen_shore", _sea())
	assert_eq(f.params("sea")["drift"], Vector2.ZERO)


func test_a_missing_image_falls_back_to_a_dark_gradient() -> void:
	var t := BiomeBackdrop.load_texture(
		"res://assets/textures/backgrounds/none.png", Color(0.1, 0.0, 0.2)
	)
	assert_true(t["stand_in"])
	assert_true(t["texture"] is GradientTexture2D)
	var real := BiomeBackdrop.load_texture(
		BiomeBackdrop.texture_path(&"ruins", "deep"), Color.BLACK
	)
	assert_false(real["stand_in"], "the installed image loads")
	assert_true(real["texture"] is CompressedTexture2D)
	assert_eq(BiomeBackdrop.key_for(&"hub"), &"ruins", "anything else takes Ruins'")


func test_every_image_is_installed_and_listed() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ids := []
	for t: Dictionary in data.get("textures", []):
		ids.append(t["id"])
	for biome in BiomeBackdrop.BIOMES:
		for layer in ["deep", "mid"]:
			assert_true(ResourceLoader.exists(BiomeBackdrop.texture_path(biome, layer)))
			assert_has(ids, "bg_%s_%s" % [biome, layer])
