extends GutTest
## The graphics options: each key's default is what the game drew before it existed, and each saves, loads and applies.

const KEYS: Array[String] = [
	"resolution",
	"upscaler",
	"shadows",
	"ambient_occlusion",
	"glow",
	"anti_aliasing",
	"texture_filtering",
	"render_scale",
]


func after_each() -> void:
	var blank := ProfileStore.new("")
	for k in KEYS:
		GameSettings.apply_one(blank, k)


func test_the_defaults_are_the_look_the_game_had() -> void:
	var p := ProfileStore.new("")
	assert_eq(GameSettings.get_value(p, "resolution"), "native")
	assert_eq(GameSettings.get_value(p, "upscaler"), "bilinear")
	assert_eq(GameSettings.get_value(p, "shadows"), "high")
	assert_eq(GameSettings.get_value(p, "ambient_occlusion"), "on")
	assert_eq(GameSettings.get_value(p, "glow"), "on")
	assert_eq(GameSettings.get_value(p, "anti_aliasing"), "off")
	assert_eq(GameSettings.get_value(p, "texture_filtering"), "4x")
	# What those values draw equals the project's own settings.
	assert_eq(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"), 0, "no MSAA")
	assert_true(RenderSwitches.MSAA_OFF, "the shipped look has no MSAA")
	assert_eq(
		int(
			ProjectSettings.get_setting(
				"rendering/textures/default_filters/anisotropic_filtering_level"
			)
		),
		int(Viewport.ANISOTROPY_4X),
		"the project's texture filtering is 4x"
	)
	assert_eq(
		int(ProjectSettings.get_setting("rendering/scaling_3d/mode", 0)),
		int(Viewport.SCALING_3D_MODE_BILINEAR),
		"the project's upscaler is bilinear"
	)
	assert_true(
		GraphicsSettings.SHADOW_TABLE.get("high") == null, "high keeps the project's atlases"
	)


func test_applying_the_defaults_leaves_the_window_as_the_project_set_it() -> void:
	var p := ProfileStore.new("")
	GameSettings.apply_all(p)
	var root := get_tree().root
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_false(root.use_taa)
	assert_eq(root.anisotropic_filtering_level, Viewport.ANISOTROPY_4X)
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)
	assert_almost_eq(root.scaling_3d_scale, 1.0, 0.0001)
	assert_eq(GraphicsSettings.shadows, "high")
	assert_true(GraphicsSettings.ambient_occlusion and GraphicsSettings.glow)


func test_every_key_saves_and_loads() -> void:
	var path := "user://test_graphics_roundtrip.json"
	var p := ProfileStore.new(path)
	var want := {
		"resolution": "1600x900",
		"upscaler": "fsr2",
		"shadows": "low",
		"ambient_occlusion": "off",
		"glow": "off",
		"anti_aliasing": "msaa4",
		"texture_filtering": "16x",
	}
	for k: String in want:
		GameSettings.set_value(p, k, want[k])
	assert_true(p.save_file())
	var q := ProfileStore.open(path)
	for k: String in want:
		assert_eq(GameSettings.get_value(q, k), want[k], k)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_upscaler_and_the_scale_work_together() -> void:
	var p := ProfileStore.new("")
	GameSettings.set_value(p, "upscaler", "fsr2")
	GameSettings.set_value(p, "render_scale", "67")
	var root := get_tree().root
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
	assert_almost_eq(root.scaling_3d_scale, 0.67, 0.0001)
	GameSettings.set_value(p, "upscaler", "fsr1")
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	assert_almost_eq(
		root.scaling_3d_scale, 0.67, 0.0001, "the scale stays when the upscaler changes"
	)
	GameSettings.set_value(p, "upscaler", "bilinear")
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)


func test_anti_aliasing_modes_set_the_root_window() -> void:
	var p := ProfileStore.new("")
	var root := get_tree().root
	GameSettings.set_value(p, "anti_aliasing", "fxaa")
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED)
	GameSettings.set_value(p, "anti_aliasing", "msaa2")
	assert_eq(root.msaa_3d, Viewport.MSAA_2X)
	assert_eq(root.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "one mode at a time")
	GameSettings.set_value(p, "anti_aliasing", "msaa4")
	assert_eq(root.msaa_3d, Viewport.MSAA_4X)
	GameSettings.set_value(p, "anti_aliasing", "taa")
	assert_true(root.use_taa)
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED)
	GameSettings.set_value(p, "anti_aliasing", "off")
	assert_false(root.use_taa)
	RenderSwitches.apply_viewport(root)
	assert_eq(root.msaa_3d, Viewport.MSAA_DISABLED, "the world view's apply keeps the choice")


func test_texture_filtering_sets_the_anisotropy() -> void:
	var p := ProfileStore.new("")
	var root := get_tree().root
	var want := {
		"off": Viewport.ANISOTROPY_DISABLED,
		"2x": Viewport.ANISOTROPY_2X,
		"4x": Viewport.ANISOTROPY_4X,
		"8x": Viewport.ANISOTROPY_8X,
		"16x": Viewport.ANISOTROPY_16X,
	}
	for k: String in want:
		GameSettings.set_value(p, "texture_filtering", k)
		assert_eq(root.anisotropic_filtering_level, want[k], k)


func test_shadow_levels_set_the_atlases_and_the_flag() -> void:
	var p := ProfileStore.new("")
	var root := get_tree().root
	GameSettings.set_value(p, "shadows", "low")
	assert_eq(GraphicsSettings.shadows, "low")
	assert_eq(root.positional_shadow_atlas_size, 1024)
	GameSettings.set_value(p, "shadows", "medium")
	assert_eq(root.positional_shadow_atlas_size, 2048)
	GameSettings.set_value(p, "shadows", "off")
	assert_eq(GraphicsSettings.shadows, "off")
	GameSettings.set_value(p, "shadows", "high")
	assert_eq(
		root.positional_shadow_atlas_size,
		int(
			ProjectSettings.get_setting(
				"rendering/lights_and_shadows/positional_shadow/atlas_size", 4096
			)
		)
	)


func test_ambient_occlusion_and_glow_flags() -> void:
	var p := ProfileStore.new("")
	GameSettings.set_value(p, "ambient_occlusion", "off")
	GameSettings.set_value(p, "glow", "off")
	assert_false(GraphicsSettings.ambient_occlusion)
	assert_false(GraphicsSettings.glow)
	var stage := StageView.new()
	stage.mood = BiomeMood.new()
	stage.lighting = "high"
	stage.environment = Environment.new()
	stage.set_lighting("high")
	assert_false(stage.environment.glow_enabled, "the stage follows the glow switch")
	assert_false(stage.environment.ssao_enabled)
	GameSettings.set_value(p, "glow", "on")
	GameSettings.set_value(p, "ambient_occlusion", "on")
	stage.set_lighting("high")
	assert_true(stage.environment.glow_enabled)
	assert_true(stage.environment.ssao_enabled)
	stage.free()


func test_resolution_choices_fit_the_monitor() -> void:
	var small := GraphicsSettings.resolution_choices(Vector2i(1920, 1080))
	assert_eq(small[0], "native")
	assert_true(small.has("1280x720") and small.has("1366x768") and small.has("1920x1080"))
	assert_false(small.has("2560x1440"), "nothing above the monitor")
	assert_false(small.has("1920x1200"), "nor a 16:10 taller than it")
	var big := GraphicsSettings.resolution_choices(Vector2i(3840, 2160))
	assert_true(big.has("3840x2160") and big.has("2560x1440"))
	assert_true(
		GraphicsSettings.resolution_choices(Vector2i(1280, 720), "2560x1440").has("2560x1440")
	)
	assert_eq(GraphicsSettings.parse_resolution("1600x900"), Vector2i(1600, 900))
	assert_eq(GraphicsSettings.parse_resolution("native"), Vector2i.ZERO)


func test_fullscreen_resolution_scales_the_3d_view_only() -> void:
	# Headless has no monitor to measure, so the scale stays the render scale; the window is never touched.
	var p := ProfileStore.new("")
	GameSettings.set_value(p, "window_mode", "fullscreen")
	GameSettings.set_value(p, "resolution", "1280x720")
	assert_almost_eq(get_tree().root.scaling_3d_scale, 1.0, 0.0001)
	GameSettings.set_value(p, "window_mode", "windowed")
	GameSettings.set_value(p, "resolution", "native")
