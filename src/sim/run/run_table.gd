class_name RunTable
extends RefCounted
## A run's compiled numbers (RunDefinition, v0.3.0 B): floors, the biome count (the ids stay in the app) and the
## per-mille scaling. Starting values: 3 floors; normal enemies' HP and damage per floor from per-mille tables
## (v0.4.0 SC: 1.9^(f − 1), 1.4^(f − 1)); bosses' HP +400 and damage +200 per mille per floor after the first; heal
## 400 per mille of max HP between floors; Deep floors ×1.25 and one extra chest (v0.5.0 RT).

## v0.9.0 FV: the RunDefinition id (a save records it, so a run resumes in its own shape; RunSaver).
var id := &""
var floors := 3
## v0.9.0 FV (owner Q24): floor f's rooms (start hall included, boss room not), entry f − 1, the last past the end;
## empty: the map's range (FloorShape.size_floor). And the wand's slots per floor over the wand's (empty: the wand's).
var rooms_min_by_floor := PackedInt32Array()
var rooms_max_by_floor := PackedInt32Array()
var wand_slots_per_floor := PackedInt32Array()
var biome_count := 1
var enemy_hp_floor_permille := PackedInt32Array([1000, 1900, 3610])
var enemy_damage_floor_permille := PackedInt32Array([1000, 1400, 1960])
var boss_hp_per_floor_permille := 400
var boss_damage_per_floor_permille := 200
var heal_permille := 400
## v0.5.5 EC (owner Q-S4, "Keep half"): per mille of the unspent shards a portal carries over (rounded down).
var shard_carry_permille := 500
## v0.5.0 RT: a Deep floor's extra scaling (per mille, on top of the floor's) and extra chests.
var deep_scale_permille := 1250
var deep_extra_chests := 1
## v0.4.0 TU (owner D9): per floor, the boss's HP and damage per mille and the HP restored when its room seals.
var boss_ease_floor_permille := PackedInt32Array([1000])
var boss_room_heal_floor_permille := PackedInt32Array([0])
## v0.7.5 AP: each loop past the first (RunDefinition): enemies' and bosses' HP and damage × these per mille,
## compounding up to scale_cap_permille; threat T and the catch-up caps (per mille) added per loop.
var loop_enemy_hp_permille := 1000
var loop_enemy_damage_permille := 1000
var loop_boss_hp_permille := 1000
var loop_boss_damage_permille := 1000
var loop_scale_cap_permille := 100000
var loop_threat := 0
var loop_catch_up_cap_permille := 0
## v0.8.0 P3 (owner O35): a Deep floor past loop 1: enemies' and bosses' HP and damage × this per mille (1000: none).
var loop_deep_ease_permille := 1000
## v0.8.0 FB1 (RunDefinition): the final boss's bodies (FinalBossDefinition ids, in order; empty = none: End the run
## ends it at once), its name key, its arena (a FinalArenaDefinition id) and the shatter between two bodies (ticks).
var final_bosses: Array[StringName] = []
var final_name_key := &""
var final_arena := &""
var final_shatter_ticks := 90
