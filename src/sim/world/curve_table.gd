class_name CurveTable
extends RefCounted
## A compiled difficulty curve (v0.4.0 TU, owner D1–D3): one floor's time → phase table, built from
## DifficultyCurveDefinition by ContentCompiler.compile_curve and hung on the floor's SpawnTable (SpawnTable.curve).
## Phase p runs from starts[p] ticks of floor time to the next start; the last phase (the peak) holds. Within a
## phase the danger tier (per mille of a tier), the alive cap and the spawn interval (per mille of SC's values at that
## tier) ramp linearly toward the next phase's values, unless the phase holds (the calm minute). Integer math only.

const OVERTIME_BASE_TIER := 3  # v0.9.5 DC: the overtime counts tiers above this one

## Phase starts in floor ticks (the first is 0), and per phase: tier × 1000, cap, interval, enemy HP and damage per
## mille (of SC's values at the tier), the largest
## pack (0 = no limit), whether it holds its values, and its name (a locale key the HUD shows).
var starts := PackedInt32Array([0])
var tier_permille := PackedInt32Array([0])
var cap_permille := PackedInt32Array([1000])
var interval_permille := PackedInt32Array([1000])
var hp_permille := PackedInt32Array([1000])
var damage_permille := PackedInt32Array([1000])
var pack_cap := PackedInt32Array([0])
var holds := PackedByteArray([0])
var name_keys: Array[StringName] = [&""]
## v0.9.5 DC (owner: "aim to a 10 minutes max per floor"): the overtime after the peak phase. `overtime_starts` are the
## floor ticks tiers 4, 5, ... start at (ascending); past the last, +1 tier every `overtime_step` ticks up to
## `overtime_max_tier`. Each tier above OVERTIME_BASE_TIER adds `cap_per_tier_permille` to the cap and takes
## `interval_per_tier_permille` off the interval (never below `interval_min_ticks`); the largest pack grows by one at
## each tier in `pack_cap_bumps`. Empty `overtime_starts` = no overtime.
var overtime_starts := PackedInt32Array()
var overtime_step := 1800
var overtime_max_tier := 20
var cap_per_tier_permille := 0
var interval_per_tier_permille := 0
var interval_min_ticks := 48
var pack_cap_bumps := PackedInt32Array()
## Per row of the SpawnTable's mix: the phase that unlocks it (-1 = never on this floor).
var kind_phase := PackedInt32Array()
## Enemy kinds (ActorStore.Kind) this floor shows for the first time in the run (the HUD names each when it first
## appears; boss summons are not in the mix and never count).
var new_kinds := PackedInt32Array()


func phase_count() -> int:
	return starts.size()


## The phase running at `ticks` of floor time.
func phase_at(ticks: int) -> int:
	var p := 0
	while p + 1 < starts.size() and ticks >= starts[p + 1]:
		p += 1
	return p


## The danger tier × 1000 at `ticks` (interpolated within a ramping phase).
func tier_permille_at(ticks: int) -> int:
	var base := _at(tier_permille, ticks)
	if phase_at(ticks) + 1 < starts.size():
		return base
	return maxi(base, overtime_tier_at(ticks) * 1000)


## v0.9.5 DC: the overtime's scheduled tier at `ticks` of floor time (0 before it starts or without one).
func overtime_tier_at(ticks: int) -> int:
	var n := overtime_starts.size()
	if n == 0 or ticks < overtime_starts[0]:
		return 0
	var i := 0
	while i < n and ticks >= overtime_starts[i]:
		i += 1
	var tier := OVERTIME_BASE_TIER + i
	if i == n:
		tier += (ticks - overtime_starts[n - 1]) / maxi(1, overtime_step)
	return mini(tier, overtime_max_tier)


## v0.9.5 DC: tiers above the base the overtime has reached at `tier`.
func extra_tiers(tier: int) -> int:
	return maxi(0, tier - OVERTIME_BASE_TIER) if not overtime_starts.is_empty() else 0


## v0.9.5 DC: the cap's overtime factor at `tier`, per mille.
func cap_bonus_permille(tier: int) -> int:
	return 1000 + cap_per_tier_permille * extra_tiers(tier)


## v0.9.5 DC: `interval_ticks` (already scaled for the tier) shortened by the overtime, never below interval_min_ticks.
func overtime_interval(interval_ticks: int, tier: int) -> int:
	var e := extra_tiers(tier)
	if e == 0:
		return interval_ticks
	var scaled := interval_ticks * maxi(0, 1000 - interval_per_tier_permille * e) / 1000
	return maxi(interval_min_ticks, scaled)


func cap_permille_at(ticks: int) -> int:
	return _at(cap_permille, ticks)


func interval_permille_at(ticks: int) -> int:
	return _at(interval_permille, ticks)


func hp_permille_at(ticks: int) -> int:
	return _at(hp_permille, ticks)


func damage_permille_at(ticks: int) -> int:
	return _at(damage_permille, ticks)


func pack_cap_at(ticks: int) -> int:
	var p := pack_cap[phase_at(ticks)]
	if p == 0 or overtime_starts.is_empty():
		return p
	var tier := tier_permille_at(ticks) / 1000
	for b in pack_cap_bumps:
		if tier >= b:
			p += 1
	return p


## Ticks from `ticks` to the next phase's start (0 at the peak).
func ticks_to_next(ticks: int) -> int:
	var p := phase_at(ticks)
	return starts[p + 1] - ticks if p + 1 < starts.size() else 0


func _at(values: PackedInt32Array, ticks: int) -> int:
	var p := phase_at(ticks)
	if p + 1 >= starts.size() or holds[p] == 1:
		return values[p]
	var span := maxi(1, starts[p + 1] - starts[p])
	return values[p] + (values[p + 1] - values[p]) * (ticks - starts[p]) / span
