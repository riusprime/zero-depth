class_name ArenaTable
extends RefCounted
## The sealed arenas' numbers in sim units (v0.5.5 AR; ContentCompiler.compile_arena from ArenaDefinition). The
## defaults equal the data's starting values; a world without the table still times the Overrun's waves by them.

## The share of a floor's combat rooms that are arenas, per mille (ArenaRooms.mark).
var share_permille := 330
## Waves per arena, drawn per room in waves_min..waves_max, and each wave's size by floor (1-based; the last
## repeats).
var waves_min := 2
var waves_max := 3
var wave_sizes := PackedInt32Array([3, 5, 7])
## Ticks from the seal to the first wave, and from a wave's last kill to the next wave.
var first_wave_ticks := 45
var wave_gap_ticks := 60
## A wave's members spawn at least this far from the player (m) when the room has such spots.
var min_spawn_distance_m := 3.0


## The wave size on floor `floor_index` from `sizes` (1-based; the last repeats).
static func size_on(sizes: PackedInt32Array, floor_index: int) -> int:
	if sizes.is_empty():
		return 0
	return sizes[clampi(floor_index - 1, 0, sizes.size() - 1)]
