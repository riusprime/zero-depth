class_name SpawnTable
extends RefCounted
## A compiled spawn director (PLAN v0.2.0 C; hordes v0.4.0 SC): ticks, per-mille ints and actor kinds. Built from
## SpawnDirectorDefinition by ContentCompiler.compile_spawning. Per-floor arrays are indexed by floor − 1 and
## per-tier tables by tier; past the end, the last entry holds (the tier cap). Integer math only (EI-02).

var tier_ticks := 1800
## Alive cap at tier 0 per floor, its growth per tier, and the hard cap.
var cap_by_floor := PackedInt32Array([14, 30, 50])
var cap_per_tier := 6
var cap_max := 120
## Ticks between packs: max(interval_min_ticks, interval_start_ticks × interval_tier_permille[tier] / 1000).
var interval_start_ticks := 150
var interval_min_ticks := 24
var interval_tier_permille := PackedInt32Array([1000])
## Max HP and damage of an enemy arriving at a tier, per mille of its (floor-scaled) table value.
var hp_tier_permille := PackedInt32Array([1000])
var damage_tier_permille := PackedInt32Array([1000])
## Pack size range per floor (inclusive).
var pack_min_by_floor := PackedInt32Array([1])
var pack_max_by_floor := PackedInt32Array([1])
var min_distance_m := 8.0
var edge_band_m := 3.0
## The mix, parallel arrays: actor kind (ActorStore.Kind), weight, the tier it unlocks at, and its pack size
## (SpawnMixEntry.pack: 0 = the per-floor draw, > 0 = always that many, e.g. a Swarmer pack).
var kinds := PackedInt32Array()
var weights := PackedInt32Array()
var unlock_tiers := PackedInt32Array()
var packs := PackedInt32Array()


func tier_at(run_ticks: int) -> int:
	return run_ticks / maxi(1, tier_ticks)


## How far `run_ticks` is through its tier, 0 .. <1 (v0.3.0 UI: the HUD's danger meter, L23).
func tier_progress(run_ticks: int) -> float:
	return float(run_ticks % maxi(1, tier_ticks)) / maxi(1, tier_ticks)


## The alive cap on floor `floor_index` (1-based) at `tier`.
func cap(floor_index: int, tier: int) -> int:
	return mini(per_floor(cap_by_floor, floor_index) + cap_per_tier * tier, cap_max)


## Ticks between packs at `tier`.
func interval(tier: int) -> int:
	return maxi(
		interval_min_ticks, interval_start_ticks * per_tier(interval_tier_permille, tier) / 1000
	)


## A kind's max HP arriving at `tier`: its floor-scaled HP × hp_tier_permille[tier] / 1000, rounded, at least 1.
func scaled_hp(base_hp: int, tier: int) -> int:
	return maxi(1, scale(base_hp, per_tier(hp_tier_permille, tier)))


## The damage factor (per mille) an enemy arriving at `tier` carries (ActorStore.power).
func damage_permille(tier: int) -> int:
	return per_tier(damage_tier_permille, tier)


func pack_min(floor_index: int) -> int:
	return per_floor(pack_min_by_floor, floor_index)


func pack_max(floor_index: int) -> int:
	return per_floor(pack_max_by_floor, floor_index)


## Entry floor − 1 of a per-floor array (the last past its end; 0 when empty).
static func per_floor(a: PackedInt32Array, floor_index: int) -> int:
	if a.is_empty():
		return 0
	return a[clampi(floor_index - 1, 0, a.size() - 1)]


## Entry `tier` of a per-mille tier table (the last past its end: the tier cap; 1000 when empty).
static func per_tier(a: PackedInt32Array, tier: int) -> int:
	if a.is_empty():
		return 1000
	return a[clampi(tier, 0, a.size() - 1)]


## value × permille / 1000, rounded half up (integer math).
static func scale(value: int, permille: int) -> int:
	return (value * permille + 500) / 1000
