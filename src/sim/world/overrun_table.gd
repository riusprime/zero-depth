class_name OverrunTable
extends RefCounted
## The Overrun branch's numbers in sim units (v0.4.0 AB; ContentCompiler.compile_overrun from OverrunDefinition):
## multipliers in per mille. the room is the hardest arena: waves_min..waves_max waves (drawn
## per room) of wave_sizes[floor] enemies spawning inside (replacing v0.4.0's kills_to_clear and spawn multiplier).

var hp_permille := 1500
var damage_permille := 1500
var shard_permille := 2000
var waves_min := 3
var waves_max := 5
var wave_sizes := PackedInt32Array([4, 8, 12])
## The least grid cells the Overrun room has (OverrunRooms.mark; 0: any room), and
## the room's floor area (m2) an enemy needs at once (ClosedFights.cap; 0: no cap).
var min_cells := 2
var area_per_enemy_m2 := 30.0
