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
	HEAT_SINK,
	THERMAL_EDGE,
	MELTDOWN,
	CLUSTER_PAYLOAD,
	OVERCLOCKED_DRONE,
	RAZOR_ORBIT,
	AFTERIMAGE,
}

## ItemDefinition.Rarity (v0.3.0 E).
const COMMON := 0
const RARE := 1

var id := &""
var kind := Kind.LONG_EDGE
var name_key := &""
var desc_key := &""
## COMMON or RARE (chests weight rare items higher).
var rarity := COMMON
## The PlayerTable.Utility the item needs, or -1 for any (rewards never offer it otherwise).
var requires_utility := -1
## The PlayerTable.WEAPON_* bit the item feeds (v0.3.0 L15), or 0 for any: a build without that weapon is never
## offered it.
var requires_weapon := 0
## v0.5.0 CP: the AbilityTable.Kind the item modifies, or -1: rewards offer it only while you own that ability.
var requires_ability := -1
## v0.6.0 MX1: the item's modifiers (compiled ModifierDefinitions), in its order: what it does to the weapon attacks
## and the Skills (Modifiers.compile). Empty for items whose effects are not attack rewrites yet.
var modifiers: Array[ModifierTable] = []
## Ember Edge (the burn engine's numbers).
var burn_damage := 0
var burn_period_ticks := 1
var burn_duration_ticks := 0
var burn_max_stacks := 0
## Kinetic Dash.
var dash_hit_damage := 0
## Vampiric Core: HP healed per kill, and the most it heals in each window.
var heal_per_kill := 0
var heal_cap := 0
var heal_window_ticks := 0
## Momentum: a swing started within this many ticks of a dash's end deals × (1 + bonus / 1000).
var momentum_window_ticks := 0
var momentum_bonus_permille := 0
## Frost Core (the chill's numbers): a slowed enemy moves at slow_permille / 1000 of its speed for slow_ticks.
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
## Overclock heat (v0.3.0 L18; see ItemDefinition): the item only works, and is only offered, when the run has heat.
var requires_heat := false
var vent_damage_bonus_permille := 0
var vent_radius_bonus_permille := 0
var heat_hot_threshold := 0
var meltdown_damage_permille := 0
## Ability mods (v0.5.0 CP; see ItemDefinition and AbilityMods).
var bomblets := 0
var bomblet_damage_permille := 0
var bomblet_radius_permille := 0
var bomblet_delay_ticks := 0
var drone_rate_per_heat_permille := 0
var afterimage_damage := 0
var afterimage_radius_m := 0.0
var afterimage_delay_ticks := 0
