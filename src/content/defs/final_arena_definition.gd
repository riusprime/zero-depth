class_name FinalArenaDefinition
extends BiomeDefinition
## v0.8.0 FB1 (owner, F1/F2 decisions: "a new, not yet designed biome, exclusive to this fight … rounded big room like
## a gladiator arena, but cosmic like"; FINAL_BOSS.md F2): the final boss's arena, a biome of its own (palette, mood:
## BiomeDefinition) kept in its own category, so it is never a floor's biome, never in the Codex's Biomes page and never
## in the Playground's list. The room is round (FinalArena): radius_m from the centre to the wall ring's inner face,
## `segments` wall segments (a divisor of 2048: 16, 32, 64). data/final_boss/.

const SEGMENT_CHOICES: Array[int] = [16, 32, 64]

@export var radius_m := 15.0
@export var segments := 32


func category() -> StringName:
	return &"final_arena"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if radius_m < 8.0 or radius_m > 30.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "radius_m must be 8..30"))
	if not SEGMENT_CHOICES.has(segments):
		issues.append(ValidationIssue.new(&"range", resource_path, "segments must be 16, 32 or 64"))
	return issues
