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
## v0.8.0 LS (owner Q6, "HP ×6, dmg ×1.2"): enemies and bosses alike, HP ×6 and damage ×1.2 per loop (was enemy
## HP ×4 / damage ×2, boss HP ×2 / damage ×1.5), so HP outgrows the player's build and damage only a little.
@export var loop_enemy_hp_permille := 6000
@export var loop_enemy_damage_permille := 1200
@export var loop_boss_hp_permille := 6000
@export var loop_boss_damage_permille := 1200
@export var loop_scale_cap_permille := 100000
@export var loop_threat := 2
@export var loop_catch_up_cap_permille := 500
## v0.8.0 P3 (owner O35, "Reduce the difficulty of this specific combination (second loop + Purple Portal) by
## approximately 10%"): a Deep floor (the Purple Portal's route) past loop 1 eases its enemies' and bosses' HP and
## damage × this per mille, on top of the floor's, the Deep and the loop factors; a Deep floor on loop 1 and a normal
## floor on loop 2 keep theirs. 1000 = no ease. Starting value 900.
@export var loop_deep_ease_permille := 1000
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F1-F3): the final boss. End the run at the Ascension portal (any loop)
## leads to it: one fight in its own arena (final_arena, a FinalArenaDefinition id), its bodies in order
## (final_bosses: FinalBossDefinition ids, the Colossus, the Prism, the Nemesis), shown as one boss named
## final_name_key; between two bodies the last one shatters for final_shatter_seconds. Empty final_bosses: End the run
## ends the run at once (as before FB1).
@export var final_bosses: Array[StringName] = []
@export var final_name_key: StringName
@export var final_arena: StringName
@export var final_shatter_seconds := 1.5
## v0.9.0 FV (owner Q24, "first floors are smaller and later floors are longer for example 10, 13, 15, 17 , 19"): the
## rooms of floor f (the start hall included, the boss room not), an inclusive range, entry f − 1 (past the end, the
## last entry; f is the floor within the loop, so every loop has the same sizes). Empty: data/map's range on every
## floor (the v0.8.0 run shape, three_floors).
@export var rooms_min_by_floor := PackedInt32Array()
@export var rooms_max_by_floor := PackedInt32Array()
## v0.9.0 FV: the wand's slots on each floor, over data/wand's slots_per_floor (empty: the wand's). The v0.8.0 run
## shape keeps its 4 → 6 → 8, so a 3-floor run resumed from a v0.8.0 save grows as it did.
@export var wand_slots_per_floor := PackedInt32Array()
## v0.9.0 SV (owner: "Hero grows each floor"): each floor cleared raises the hero's max HP by this much, before the
## max HP stat (so the stat cards, Fortune and the curses stack with it), and heals by as much on arrival. Counted on
## the run's floor across loops (a loop keeps growing it); at most max_hp_floor_cap in all (0: no cap). 0: no growth
## (the v0.8.0 run shape, three_floors).
@export var max_hp_per_floor := 0
@export var max_hp_floor_cap := 0


func category() -> StringName:
	return &"run"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "floors", floors)
	if not final_bosses.is_empty():  # v0.8.0 FB1: a final boss has its name, its arena and a real shatter
		if String(final_name_key).is_empty() or String(final_arena).is_empty():
			issues.append(
				ValidationIssue.new(
					&"missing", resource_path, "final_bosses need final_name_key and final_arena"
				)
			)
		if int(round(final_shatter_seconds * 60.0)) < 1:
			issues.append(
				ValidationIssue.new(&"duration", resource_path, "final_shatter_seconds < a tick")
			)
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
	if loop_deep_ease_permille < 1 or loop_deep_ease_permille > 1000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "loop_deep_ease_permille: 1..1000")
		)
	_check_shape(issues)
	if loop_threat < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "loop_threat is negative"))
	if loop_catch_up_cap_permille < 0:
		issues.append(
			ValidationIssue.new(
				&"negative", resource_path, "loop_catch_up_cap_permille is negative"
			)
		)
	return issues


## v0.9.0 FV: the per-floor room ranges pair up and fit the generator (2..MapDefinition.MAX_ROOMS); the wand's slots
## stay within the wand's and never shrink.
func _check_shape(issues: Array[ValidationIssue]) -> void:
	if rooms_min_by_floor.size() != rooms_max_by_floor.size():
		issues.append(
			ValidationIssue.new(&"range", resource_path, "rooms_min/max_by_floor pair up")
		)
	else:
		for k in rooms_min_by_floor.size():
			var lo := rooms_min_by_floor[k]
			var hi := rooms_max_by_floor[k]
			if lo < 2 or hi < lo or hi > MapDefinition.MAX_ROOMS:
				issues.append(
					ValidationIssue.new(
						&"range", resource_path, "floor %d: 2 <= rooms <= 19" % (k + 1)
					)
				)
	for k in wand_slots_per_floor.size():
		var n := wand_slots_per_floor[k]
		var lower := k > 0 and n < wand_slots_per_floor[k - 1]
		if n < 1 or n > WandDefinition.MAX_SLOTS or lower:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "wand_slots_per_floor[%d]: 1..8, never lower" % k
				)
			)
