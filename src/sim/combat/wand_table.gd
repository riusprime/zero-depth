class_name WandTable
extends RefCounted
## v0.6.5 WN1: the wand's numbers in sim units (WandDefinition compiled by WandCompiler.compile). Loadout: compiled at
## setup, never written in play (World.wand_table; null = a lab world: six slots, and a trigger's child spell takes
## these defaults, which mirror data/wand/wand.tres).

var slots_per_floor := PackedInt32Array([4, 6, 8])
var child_size_permille := 600
var child_range_permille := 600
var child_damage_permille := 500


## The slot count on floor `f` (the last entry past the end; at least 1).
func slots_at(f: int) -> int:
	if slots_per_floor.is_empty():
		return 1
	return maxi(1, slots_per_floor[clampi(f - 1, 0, slots_per_floor.size() - 1)])
