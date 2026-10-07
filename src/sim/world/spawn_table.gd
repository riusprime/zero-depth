class_name SpawnTable
extends RefCounted
## A compiled spawn director (PLAN v0.2.0 C): ticks, per-mille ints and actor kinds. Built from
## SpawnDirectorDefinition by ContentCompiler.compile_spawning.

var tier_ticks := 1800
var cap_base := 3
var cap_per_tier := 2
var cap_max := 14
var interval_start_ticks := 180
var interval_step_ticks := 15
var interval_min_ticks := 48
## Enemy HP gains this many per mille of its base per tier.
var hp_per_tier_permille := 80
var min_distance_m := 8.0
## The mix, parallel arrays: actor kind (ActorStore.Kind), weight, the tier it unlocks at, and its pack size.
var kinds := PackedInt32Array()
var weights := PackedInt32Array()
var unlock_tiers := PackedInt32Array()
## v0.4.0 EN: how many of the kind arrive together (1 for most; a Swarmer pack).
var packs := PackedInt32Array()


func tier_at(run_ticks: int) -> int:
	return run_ticks / maxi(1, tier_ticks)


## How far `run_ticks` is through its tier, 0 .. <1 (v0.3.0 UI: the HUD's danger meter, L23).
func tier_progress(run_ticks: int) -> float:
	return float(run_ticks % maxi(1, tier_ticks)) / maxi(1, tier_ticks)


func cap(tier: int) -> int:
	return mini(cap_base + cap_per_tier * tier, cap_max)


func interval(tier: int) -> int:
	return maxi(interval_min_ticks, interval_start_ticks - interval_step_ticks * tier)


## A kind's max HP at this tier: base × (1000 + per-mille × tier) / 1000, integer math.
func scaled_hp(base_hp: int, tier: int) -> int:
	return maxi(1, base_hp * (1000 + hp_per_tier_permille * tier) / 1000)
