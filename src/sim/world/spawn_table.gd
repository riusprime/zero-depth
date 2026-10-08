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
## v0.4.0 TU (owner D1–D3): the floor's difficulty curve (null = SC's plain 30 s tiers, as before). With a curve,
## floor time picks a phase: the danger tier, the cap and the interval follow it, and the mix opens by phase.
var curve: CurveTable


func tier_at(run_ticks: int) -> int:
	return run_ticks / maxi(1, tier_ticks)


## v0.4.0 TU: the danger tier at `run_ticks` of floor time: the curve's (its tier × 1000, rounded down), or the
## plain tier. HP, damage and shards scale by it.
func danger_tier(run_ticks: int) -> int:
	return curve.tier_permille_at(run_ticks) / 1000 if curve != null else tier_at(run_ticks)


## The danger tier × 1000 (the curve's, or the plain tier with its progress), for the HUD's meter.
func danger_permille(run_ticks: int) -> int:
	if curve != null:
		return curve.tier_permille_at(run_ticks)
	return tier_at(run_ticks) * 1000 + run_ticks % maxi(1, tier_ticks) * 1000 / maxi(1, tier_ticks)


## v0.4.0 TU: the alive cap at `run_ticks` of floor time on floor `floor_index`: the curve's share of the tier's cap
## (at least 1), or the tier's cap.
func cap_now(floor_index: int, run_ticks: int) -> int:
	var tier := danger_tier(run_ticks)
	if curve == null:
		return cap(floor_index, tier)
	return maxi(1, scale(cap(floor_index, tier), curve.cap_permille_at(run_ticks)))


## v0.4.0 TU: ticks between packs at `run_ticks` (the curve stretches or keeps the tier's interval).
func interval_now(run_ticks: int) -> int:
	var tier := danger_tier(run_ticks)
	if curve == null:
		return interval(tier)
	return maxi(1, scale(interval(tier), curve.interval_permille_at(run_ticks)))


## v0.4.0 TU: mix row k may spawn at `run_ticks` (its curve phase has begun; without a curve, its unlock tier).
func row_open(k: int, run_ticks: int) -> bool:
	if curve == null:
		return unlock_tiers[k] <= tier_at(run_ticks)
	var p := curve.kind_phase[k] if k < curve.kind_phase.size() else -1
	return p >= 0 and p <= curve.phase_at(run_ticks)


## v0.4.0 TU: a kind's max HP arriving at `run_ticks` (its floor-scaled `base_hp`): the tier's, eased by the curve.
func hp_now(base_hp: int, run_ticks: int) -> int:
	var hp := scaled_hp(base_hp, danger_tier(run_ticks))
	return maxi(1, scale(hp, curve.hp_permille_at(run_ticks))) if curve != null else hp


## v0.4.0 TU: the damage factor (per mille) of an enemy arriving at `run_ticks`: the tier's, eased by the curve.
func power_now(run_ticks: int) -> int:
	var p := damage_permille(danger_tier(run_ticks))
	return maxi(1, scale(p, curve.damage_permille_at(run_ticks))) if curve != null else p


## v0.4.0 TU: the largest pack at `run_ticks` (0 = no limit).
func pack_cap_now(run_ticks: int) -> int:
	return curve.pack_cap_at(run_ticks) if curve != null else 0


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
