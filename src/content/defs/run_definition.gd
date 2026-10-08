class_name RunDefinition
extends ContentDef
## A run (v0.3.0 PLAN "Run (B)"): how many floors, the biomes they draw from (a random order per run; PD-04: a
## biome never changes difficulty), how enemies and bosses scale with the floor number, and how much you heal
## between floors. Starting values the owner tunes.

## Floors in a run; the last floor's portal wins it.
@export var floors := 3
## Biome ids, shuffled per run; floor f uses the f-th (cycling when there are fewer biomes than floors).
@export var biomes: Array[StringName] = []
## v0.4.0 SC (F10): normal enemies' HP and damage per mille on floor f, entry f − 1 (past the end, the last entry):
## 1.9^(f − 1) and 1.4^(f − 1) rounded. Integer tables, not runtime powers (EI-02). The danger tier's scaling comes
## on top (SpawnDirectorDefinition).
@export var enemy_hp_floor_permille := PackedInt32Array([1000, 1900, 3610])
@export var enemy_damage_floor_permille := PackedInt32Array([1000, 1400, 1960])
## Bosses keep their own per-floor scaling (v0.3.0 B): HP × (1 + boss_hp_per_floor × (f − 1)) and every attack's
## damage × (1 + boss_damage_per_floor × (f − 1)).
@export var boss_hp_per_floor := 0.4
@export var boss_damage_per_floor := 0.2
## Between floors you heal this fraction of your max HP.
@export var heal_between_floors := 0.4
## v0.5.0 RT (R5): a Deep floor (the Deep portal after a floor before the last) scales enemies' and bosses' HP and
## damage by this on top of the floor's own scaling, and adds this many chests (and one curse-free epic altar).
@export var deep_scale := 1.25
@export var deep_extra_chests := 1


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
	check_permille_table(issues, "enemy_hp_floor_permille", enemy_hp_floor_permille, true)
	check_permille_table(issues, "enemy_damage_floor_permille", enemy_damage_floor_permille, true)
	if boss_hp_per_floor < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "boss_hp_per_floor is negative")
		)
	if boss_damage_per_floor < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "boss_damage_per_floor is negative")
		)
	if heal_between_floors < 0.0 or heal_between_floors > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "heal_between_floors must be within 0..1")
		)
	if deep_scale < 1.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "deep_scale must be at least 1"))
	if deep_extra_chests < 0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "deep_extra_chests is negative")
		)
	return issues
