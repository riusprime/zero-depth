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


## v0.9.0 LG: a legendary stat card's own multiplier names one of the tier's stat cards and is at least 1.
func test_a_legendary_stat_override_is_validated() -> void:
	var ld: LegendaryDefinition = load("res://data/legendary/boss.tres").duplicate(true)
	assert_eq(ld.validate(), [], "the shipped tier is valid")
	assert_almost_eq(ld.multiplier_of(&"damage"), 1.3, 0.0001, "Power × 1.3")
	assert_almost_eq(ld.multiplier_of(&"attack_speed"), 1.3, 0.0001, "Haste × 1.3")
	assert_almost_eq(ld.multiplier_of(&"area"), 1.6, 0.0001, "the others × 1.6")
	ld.stat_multiplier_by_card[&"nope"] = 1.2
	ld.stat_multiplier_by_card[&"area"] = 0.5
	var codes := ld.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
	assert_has(codes, &"unknown_item", "an id not in stat_cards")
	assert_has(codes, &"range", "below 1")
