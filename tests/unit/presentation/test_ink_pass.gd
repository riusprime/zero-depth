extends GutTest
## The sketch outline pass (PLAN v0.1.0 Step 7c): the Options value picks the style; OFF hides it.


func test_settings_map_to_styles() -> void:
	assert_eq(InkPass.style_from_setting("off"), InkPass.Style.OFF)
	assert_eq(InkPass.style_from_setting("ink"), InkPass.Style.INK)
	assert_eq(InkPass.style_from_setting("sketch"), InkPass.Style.SKETCH)
	assert_eq(InkPass.style_from_setting("paper"), InkPass.Style.PAPER)
	assert_eq(
		InkPass.style_from_setting("nonsense"), InkPass.Style.SKETCH, "unknown values fall back"
	)


func test_off_hides_the_pass_and_the_shader_compiles() -> void:
	var ink := InkPass.new()
	add_child_autofree(ink)
	ink.set_style(InkPass.Style.OFF)
	assert_false(ink.visible)
	ink.set_style(InkPass.Style.PAPER)
	assert_true(ink.visible)
	var shader: Shader = (ink.material_override as ShaderMaterial).shader
	assert_true(shader.code.contains("hint_depth_texture"))


func test_sketch_is_the_default_setting() -> void:
	assert_eq(GameSettings.DEFAULTS["outline"], "sketch")
