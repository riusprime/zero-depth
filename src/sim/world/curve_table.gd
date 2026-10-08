class_name CurveTable
extends RefCounted
## A compiled difficulty curve (v0.4.0 TU, owner D1–D3): one floor's time → phase table, built from
## DifficultyCurveDefinition by ContentCompiler.compile_curve and hung on the floor's SpawnTable (SpawnTable.curve).
## Phase p runs from starts[p] ticks of floor time to the next start; the last phase (the peak) holds. Within a
## phase the danger tier (per mille of a tier), the alive cap and the spawn interval (per mille of SC's values at that
## tier) ramp linearly toward the next phase's values, unless the phase holds (the calm minute). Integer math only.

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
	return _at(tier_permille, ticks)


func cap_permille_at(ticks: int) -> int:
	return _at(cap_permille, ticks)


func interval_permille_at(ticks: int) -> int:
	return _at(interval_permille, ticks)


func hp_permille_at(ticks: int) -> int:
	return _at(hp_permille, ticks)


func damage_permille_at(ticks: int) -> int:
	return _at(damage_permille, ticks)


func pack_cap_at(ticks: int) -> int:
	return pack_cap[phase_at(ticks)]


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
