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
## v0.5.5 EC (owner Q-S4, "Keep half"): the share of unspent shards a portal carries to the next floor (rounded
## down); the rest is left behind.
@export var shard_carry := 0.5
## v0.5.0 RT (R5): a Deep floor (the Deep portal after a floor before the last) scales enemies' and bosses' HP and
## damage by this on top of the floor's own scaling, and adds this many chests (and one curse-free epic altar).
@export var deep_scale := 1.25
@export var deep_extra_chests := 1
## v0.4.0 TU (owner D9, "Ease floor 1 only"): a floor's boss HP and attack damage × this per mille, entry f − 1 (past
## the end, the last entry), on top of the per-floor scaling; and the share of max HP (per mille) restored when the
## boss room seals.
@export var boss_ease_floor_permille := PackedInt32Array([800, 1000, 1000])
@export var boss_room_heal_floor_permille := PackedInt32Array([1000, 0, 0])
## v0.7.5 AP (owner N4, the Ascension loop): after the last floor's boss the Ascension portal ends the run or starts a
## new loop of `floors` floors with the build carried. Each loop past the first makes the run harder (starting values
## the owner tunes; integers, so the scaling stays deterministic, EI-02):
## - normal enemies' HP and damage, and bosses' HP and attack damage, × these per mille once per loop past the first,
##   compounding (loop 3 = the factor twice), never past loop_scale_cap_permille; on top of the floor's own scaling;
## - threat T + loop_threat per loop past the first (Curses.threat: the curses' and Deep's threat, shown as T);
## - the hidden catch-up's caps (enemies' and the boss's) + loop_catch_up_cap_permille per loop past the first.
@export var loop_enemy_hp_permille := 4000
@export var loop_enemy_damage_permille := 2000
@export var loop_boss_hp_permille := 2000
@export var loop_boss_damage_permille := 1500
@export var loop_scale_cap_permille := 100000
@export var loop_threat := 2
@export var loop_catch_up_cap_permille := 500


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
	if shard_carry < 0.0 or shard_carry > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "shard_carry must be within 0..1")
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
	for v in boss_ease_floor_permille:
		if v < 1 or v > 1000:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "boss_ease_floor_permille: 1..1000")
			)
	for v in boss_room_heal_floor_permille:
		if v < 0 or v > 1000:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "boss_room_heal_floor_permille: 0..1000"
				)
			)
	for pair: Array in [  # v0.7.5 AP: a loop never makes anything weaker
		["loop_enemy_hp_permille", loop_enemy_hp_permille],
		["loop_enemy_damage_permille", loop_enemy_damage_permille],
		["loop_boss_hp_permille", loop_boss_hp_permille],
		["loop_boss_damage_permille", loop_boss_damage_permille],
	]:
		if int(pair[1]) < 1000 or int(pair[1]) > loop_scale_cap_permille:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s: 1000..loop_scale_cap_permille" % pair[0]
				)
			)
	if loop_threat < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "loop_threat is negative"))
	if loop_catch_up_cap_permille < 0:
		issues.append(
			ValidationIssue.new(
				&"negative", resource_path, "loop_catch_up_cap_permille is negative"
			)
		)
	return issues
