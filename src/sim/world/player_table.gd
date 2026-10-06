class_name PlayerTable
extends RefCounted
## The player's compiled numbers, in sim units (metres, ticks). Built from PlayerDefinition by the
## content compiler (v0.0.1 Step 6); starting_values() is the same data for tests and tools.

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
