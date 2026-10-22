class_name LockdownTable
extends RefCounted
## v0.9.0 LK (owner Q21; W20-W26): the Lockdowns' numbers in sim units (RunContentCompiler.compile_lockdown from
## LockdownDefinition, data/lockdowns/lockdown.tres). The defaults equal the data's starting values. Content: read in
## play, never written (WorldSnapshot keeps it as loadout).

## The kinds (LockdownDefinition.kind_weights is indexed by them). ELITE is step EL's hook: weight 0 until the owner's
## ELITES.md G1, and only from elite_floor_min.
enum Kind { NORMAL, HAZARD, ELITE }

## Lockdowns a floor, drawn in rooms_min..rooms_max (fewer when the floor has fewer rooms that fit).
var rooms_min := 1
var rooms_max := 2
## Each kind's weight (per Kind), and the first floor (1-based, within a loop) each may appear on.
var kind_weights := PackedInt32Array([750, 250, 0])
var kind_floor_min := PackedInt32Array([1, 2, 4])
## The encounter: `waves` formations, each wave_sizes[floor] enemies (1-based; the last repeats).
var waves := 3
var wave_sizes := PackedInt32Array([5, 5, 5, 6, 6])
## Ticks from the seal to the first formation, and from a formation's last kill to the next.
var first_wave_ticks := 60
var wave_gap_ticks := 45
## The stuck-enemy safety: an encounter enemy unreachable this long is pulled back into the room; the exits open
## after cap_ticks whatever is left.
var stuck_ticks := 180
var cap_ticks := 5400
## Hazard Lockdowns: a strike every hazard_every_ticks while sealed, its ground warning hazard_warn_ticks before it
## lands (at the hero's spot when it was marked), hurting the hero within hazard_radius_m for hazard_damage.
var hazard_every_ticks := 120
var hazard_warn_ticks := 60
var hazard_radius_m := 1.3
var hazard_damage := 12


## The formation size on floor `floor_index` (1-based; the last repeats).
func size_on(floor_index: int) -> int:
	return SpawnTable.at(wave_sizes, floor_index - 1, 0)
