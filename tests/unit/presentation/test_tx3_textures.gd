extends GutTest
## v0.8.0 TX3: the owner's menu and ambient textures replace the code-made looks, with the code looks kept as the
## fallback: the slabs' grain is the owner's carved stone (grey, low in contrast so text reads on it), the main menu's
## backdrop draws the owner's wall and ember sprites in its one pass, and the starry void's stars are the owner's motes
## on camera-facing quads, still one MultiMesh.


func test_the_slabs_wear_the_owners_stone_grain() -> void:
	assert_true(EmberStone.owner_grain(), "tex_menu_stone installed and used")
	var img := EmberStone.grain().get_image()
	assert_eq(img.get_size(), Vector2i(EmberStone.GRAIN_PX, EmberStone.GRAIN_PX))
	var lo := 1.0
	var hi := 0.0
	var sum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			assert_almost_eq(c.r, c.b, 0.02, "grey: it only shades the slab's colour")
			lo = minf(lo, c.r)
			hi = maxf(hi, c.r)
			sum += c.r
			n += 1
	assert_between(sum / n, 0.74, 0.9, "about the code grain's level (0.6 .. 1)")
	assert_lte(hi, 1.0)
	assert_gte(lo, 0.3, "no black holes under the text")
	assert_not_null(EmberStone.code_grain(), "the code grain is still there as the fallback")


func test_the_main_menus_backdrop_draws_the_owners_wall_and_sparks() -> void:
	var b := MenuBackdrop.new()
	add_child_autofree(b)
	assert_eq(b.owner_textures(), [true, true])
	assert_not_null(EmberStone.wall())
	assert_eq(EmberStone.wall().get_size(), Vector2(1024, 1024), "downscaled to 1024")
	assert_not_null(MenuBackdrop.sparks_texture())
	assert_true(b.material is ShaderMaterial, "still one shader on one rect")


func test_the_starry_void_draws_the_owners_motes_in_one_multimesh() -> void:
	var m := StarVoid.star_material()
	assert_eq((m.shader as Shader).code, StarVoid.SPRITE_SHADER)
	assert_not_null(m.get_shader_parameter("motes"))
	var mesh := StarVoid.star_mesh()
	assert_eq(mesh.get_surface_count(), 1)
	assert_eq(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 6, "a quad: two triangles")
