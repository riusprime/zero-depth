class_name RunDefinition
extends ContentDef
## A run (v0.3.0 PLAN "Run (B)"): how many floors, the biomes they draw from (a random order per run; PD-04: a
## biome never changes difficulty), how enemies scale with the floor number, and how much you heal between floors.
## Starting values the owner tunes.

## Floors in a run; the last floor's portal wins it.
@export var floors := 3
## Biome ids, shuffled per run; floor f uses the f-th (cycling when there are fewer biomes than floors).
@export var biomes: Array[StringName] = []
## Enemy HP × (1 + enemy_hp_per_floor × (f − 1)) and damage × (1 + enemy_damage_per_floor × (f − 1)).
@export var enemy_hp_per_floor := 0.4
@export var enemy_damage_per_floor := 0.2
## Between floors you heal this fraction of your max HP.
@export var heal_between_floors := 0.4


func category() -> StringName:
	return &"run"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "floors", floors)
	if biomes.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "biomes is empty"))
	for b in biomes:
		if String(b).is_empty():
			issues.append(ValidationIssue.new(&"missing", resource_path, "a biome id is empty"))
	if enemy_hp_per_floor < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "enemy_hp_per_floor is negative")
		)
	if enemy_damage_per_floor < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "enemy_damage_per_floor is negative")
		)
	if heal_between_floors < 0.0 or heal_between_floors > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "heal_between_floors must be within 0..1")
		)
	return issues
