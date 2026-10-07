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
	VAMPIRIC_CORE,
	STATIC_CHAIN,
	MOMENTUM,
	FROST_CORE,
	THORN_MANTLE,
	EXECUTIONER,
	SWIFT_FEET,
	PHASE_STRIKE,
	CINDER_SHOT,
	WILDFIRE,
	CONDUCTOR,
	SERRATED_EDGE,
	BARBED_BOLTS,
	GLACIAL_EDGE,
	COLD_SNAP,
	BULWARK,
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
## Vampiric Core: HP healed per kill, and the most it heals in each window.
var heal_per_kill := 0
var heal_cap := 0
var heal_window_ticks := 0
## Static Chain: every Nth landed bolt jumps to the nearest other enemy within range for this damage.
var chain_every := 0
var chain_range_m := 0.0
var chain_damage := 0
## Momentum: a swing started within this many ticks of a dash's end deals × (1 + bonus / 1000).
var momentum_window_ticks := 0
var momentum_bonus_permille := 0
## Frost Core: a slowed enemy moves at slow_permille / 1000 of its speed for slow_ticks.
var slow_permille := 1000
var slow_ticks := 0
## Thorn Mantle: bolts in the ring released when the player takes damage, and each one's damage.
var thorn_bolts := 0
var thorn_damage := 0
## Executioner: hits on enemies below threshold / 1000 of their max HP deal × (1 + bonus / 1000).
var execute_threshold_permille := 0
var execute_bonus_permille := 0
## Swift Feet: move speed × (1 + bonus / 1000); dash cooldown × (1 − cut / 1000).
var move_speed_bonus_permille := 0
var dash_cooldown_cut_permille := 0
## Phase Strike: the ring's damage and radius, and how often a guard block can set it off.
var phase_damage := 0
var phase_radius_m := 0.0
var phase_guard_window_ticks := 0
## Engines (v0.3.0 G; see ItemDefinition for each field). Tags are for views and docs, never for gameplay.
var tags := PackedStringArray()
var stacks_per_hit := 0
var stack_every := 0
var shock_threshold := 0
var shock_ticks := 0
var shock_damage := 0
var shock_jumps := 0
var shock_range_m := 0.0
var bleed_damage := 0
var bleed_period_ticks := 1
var bleed_ticks := 0
var bleed_max_stacks := 0
var bleed_burst_per_stack := 0
var frost_threshold := 0
var frost_ticks := 0
var freeze_ticks := 0
var spread_radius_m := 0.0
var chill_bonus_permille := 0
var frozen_bonus_permille := 0
var charge_max := 0
var charge_bonus_permille := 0
