class_name HeatTable
extends RefCounted
## Overclock heat's compiled numbers (HeatDefinition, by ContentCompiler.compile_heat). Heat is kept in milli-points
## (1000 = one heat point) so the decay runs every tick in whole numbers; thresholds are in points.

const MILLI := 1000

var max_heat := 100
## Milli-points per landed attack: a combo step, the finisher, one bolt.
var gain_swing := 2500
var gain_finisher := 5000
var gain_bolt := 900
## v0.9.5 HT: ticks a Gun run takes to fill 0 to max while firing; ticks after the last gain before the cooling
## starts; the milli-points it then loses per tick.
var gun_fill_ticks := 840
var cool_delay_ticks := 60
var cool_per_tick := 417
var hot_threshold := 40
var hot_reach_permille := 200
var overclock_threshold := 75
var overclock_damage_permille := 250
var overclock_burn_stacks := 1
var stall_ticks := 72
var stall_move_permille := 600
var vent_radius_m := 2.5
## Blast damage per heat point vented, per mille (500 = half a point of damage per point of heat).
var vent_damage_permille := 500
## v0.9.5 HT: Vent needs this many milli-points, then waits this many ticks.
var vent_min_milli := 40000
var vent_cooldown_ticks := 360


func max_milli() -> int:
	return max_heat * MILLI
