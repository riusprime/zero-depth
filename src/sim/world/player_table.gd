class_name PlayerTable
extends RefCounted
## The player's compiled numbers, in sim units (metres, ticks). Built from PlayerDefinition by the
## content compiler (v0.0.1 Step 6); starting_values() is the same data for tests and tools.

## The utility chosen before the run (PD-01).
enum Utility { NONE, GUARD, BLINK }

var hp := 100
var radius_m := 0.35
## Metres per tick.
var move_speed := 0.0
var dash_distance_m := 0.0
var dash_ticks := 1
var dash_cooldown_ticks := 0
## Invulnerable ticks at the start of a dash (the whole dash by default).
var dash_iframe_ticks := 9
## After taking a hit: invulnerable ticks and hit-stop ticks.
var hurt_iframe_ticks := 30
var hurt_freeze_ticks := 4
## Guard: half arc (1/4096 turns) and the per-mille multiplier for hits from inside it.
var guard_half_arc := 683
var guard_mult_permille := 200
var utility := Utility.NONE
var guard_move_permille := 400
## Blink: range in metres, cooldown and invulnerable ticks.
var blink_range_m := 5.0
var blink_cooldown_ticks := 150
var blink_iframe_ticks := 6
## Primary: swing (3-hit combo), charge, bolt. Distances in metres, speeds in metres per tick.
var swing_ticks := 14
var swing_active_tick := 2
var swing_reach_m := 1.6
var swing_half_arc := 683
var swing_damage: Array[int] = [10, 10, 18]
var combo_window_ticks := 12
var swing_hitstop_ticks := 3
var charge_start_ticks := 12
var charge_full_ticks := 48
var charge_move_permille := 500
var bolt_min_damage := 12
var bolt_max_damage := 36
var bolt_speed := 16.0 / 60.0
var bolt_radius_m := 0.15
var bolt_life_ticks := 90
var bolt_full_hitstop_ticks := 5


## The v0.0.1 starting values (docs/design/GAME_BLUEPRINT.md §C): 6 m/s, dash 4 m over 0.15 s, 0.8 s cooldown.
static func starting_values() -> PlayerTable:
	var t := PlayerTable.new()
	t.hp = 100
	t.radius_m = 0.35
	t.move_speed = 6.0 / SimTick.TICKS_PER_SECOND
	t.dash_distance_m = 4.0
	t.dash_ticks = SimTick.seconds_to_ticks(0.15)
	t.dash_cooldown_ticks = SimTick.seconds_to_ticks(0.8)
	t.dash_iframe_ticks = SimTick.seconds_to_ticks(0.15)
	return t
