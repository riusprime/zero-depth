extends GutTest

const FIXTURES := {
	"res://tests/content/fixtures/player_no_id.tres": &"id_empty",
	"res://tests/content/fixtures/player_zero_tick_dash.tres": &"duration_zero_ticks",
	"res://tests/content/fixtures/biome_missing_key.tres": &"palette_missing",
	"res://tests/content/fixtures/biome_unknown_key.tres": &"palette_unknown",
	"res://tests/content/fixtures/biome_low_outline.tres": &"outline_contrast",
}


func test_each_fixture_produces_its_error() -> void:
	for path: String in FIXTURES:
		var def: ContentDef = load(path)
		var codes := def.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
		assert_has(codes, FIXTURES[path], path)


func test_duplicate_ids_are_reported() -> void:
	var a: ContentDef = load("res://data/biomes/ruins.tres")
	var b: ContentDef = a.duplicate(true)
	var issues := ContentValidator.validate([a, b] as Array[ContentDef])
	assert_has(issues.map(func(i: ValidationIssue) -> StringName: return i.code), &"duplicate_id")


func test_contrast_formula() -> void:
	assert_almost_eq(BiomeDefinition.contrast(Color.WHITE, Color.BLACK), 21.0, 0.01)
	assert_almost_eq(BiomeDefinition.contrast(Color("#CBAD91"), Color("#1A1A22")), 8.17, 0.02)
