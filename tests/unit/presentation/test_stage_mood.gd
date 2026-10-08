extends GutTest
## The biome lighting mood (v0.5.9 Step 1): StageView lights a floor from its biome's BiomeMood, and the lighting
## quality turns contact shadow (SSAO) and bounce light (SSIL) on or off. Without a mood the old look stays.


func _stage(mood: BiomeMood, quality := "high") -> StageView:
	var stage := StageView.new()
	stage.palette = ContentRepository.load_all().get_def(&"biomes", &"ruins").palette
	stage.mood = mood
	stage.lighting = quality
	add_child_autofree(stage)
	stage._build_environment()
	stage._build_light()
	return stage


func test_every_shipped_biome_has_a_valid_mood() -> void:
	var biomes := ContentRepository.load_all().all_of(&"biomes")
	assert_eq(biomes.size(), 3)
	for b: BiomeDefinition in biomes:
		assert_not_null(b.mood, "%s has a mood" % b.id)
		assert_eq(b.mood.problems().size(), 0, "%s mood: %s" % [b.id, b.mood.problems()])


func test_a_biome_without_a_mood_or_with_a_bad_one_is_reported() -> void:
	var b: BiomeDefinition = load("res://data/biomes/ruins.tres").duplicate(true)
	b.mood = null
	var codes := b.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
	assert_has(codes, &"mood_missing")
	b.mood = BiomeMood.new()
	b.mood.vignette = 2.0
	b.mood.sun_pitch_deg = 10.0
	var issues := b.validate().filter(
		func(i: ValidationIssue) -> bool: return i.code == &"mood_invalid"
	)
	assert_eq(issues.size(), 2, "vignette out of range and a sun pointing up")


func test_no_mood_keeps_the_old_look() -> void:
	var stage := _stage(null)
	assert_eq(stage.environment.tonemap_mode, Environment.TONE_MAPPER_LINEAR)
	assert_false(stage.environment.ssao_enabled)
	assert_null(stage.vignette)
	assert_almost_eq(stage.sun.light_energy, 1.05, 0.001)


func test_a_mood_lights_the_stage_and_quality_toggles_ssao_and_ssil() -> void:
	var mood: BiomeMood = ContentRepository.load_all().get_def(&"biomes", &"ruins").mood
	var stage := _stage(mood)
	var env := stage.environment
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX)
	assert_eq(env.background_color, mood.void_color)
	assert_almost_eq(env.ambient_light_energy, mood.ambient_energy, 0.001)
	assert_true(env.ssao_enabled, "high: contact shadow")
	assert_true(env.ssil_enabled, "high: bounce light")
	assert_eq(env.fog_enabled, mood.fog_density > 0.0)
	assert_almost_eq(stage.sun.light_energy, mood.sun_energy, 0.001)
	assert_eq(stage.sun.light_color, mood.sun_color)
	assert_not_null(stage.vignette, "a vignette")
	stage.set_lighting("low")
	assert_false(env.ssao_enabled, "low: no SSAO")
	assert_false(env.ssil_enabled, "low: no SSIL")
	stage.set_lighting("nonsense")
	assert_eq(stage.lighting, "high", "an unknown quality falls back to high")
	assert_true(env.ssao_enabled)
