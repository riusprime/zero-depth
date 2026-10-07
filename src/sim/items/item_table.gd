class_name ItemTable
extends RefCounted
## One item's compiled numbers in sim units (ticks, 1/4096 turns, metres, per mille). Built from ItemDefinition by
## the content compiler (v0.2.0 E). Only the fields of its kind are used.

## Appended, never renumbered (save files and views refer to them).
enum Kind {
	LONG_EDGE,
	TWIN_ARC,
	EMBER_EDGE,
	SPLINTER_SHOT,
	RAPID_COIL,
	RICOCHET_CORE,
	KINETIC_DASH,
	OVERCHARGE,
}

var id := &""
var kind := Kind.LONG_EDGE
var name_key := &""
var desc_key := &""
## Long Edge.
var reach_bonus_permille := 0
## Twin Arc.
var echo_delay_ticks := 0
var echo_damage_permille := 0
## Ember Edge.
var burn_damage := 0
var burn_period_ticks := 1
var burn_duration_ticks := 0
var burn_max_stacks := 0
## Splinter Shot: the full fan width in 1/4096 turns.
var split_count := 0
var split_spread := 0
var split_damage_permille := 0
## Rapid Coil.
var fire_rate_bonus_permille := 0
## Ricochet Core.
var bounces := 0
## Kinetic Dash.
var dash_hit_damage := 0
## Overcharge.
var overcharge_every := 0
var overcharge_mult_permille := 1000
var shockwave_radius_m := 0.0
var shockwave_damage_permille := 0
