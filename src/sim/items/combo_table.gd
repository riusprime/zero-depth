class_name ComboTable
extends RefCounted
## One named combo compiled to sim units (v0.3.0 G): its two items (indices into World.item_tables) and its
## effect's numbers. Built from ComboDefinition by ContentCompiler.compile_combos. v0.4.0 AB: or its two abilities.

## Appended, never renumbered (mirrors ComboDefinition.Effect).
enum Effect {
	PLASMA_ARC,
	SHATTER_DASH,
	RESONANCE,
	SHRAPNEL_STORM,
	BLOOD_HARVEST,
	SPIKED_PHASE,
	SLIPSTREAM,
	FROZEN_BASTION,
	STORM_BOMBS,
	NAPALM_DRONE,
	GLACIER_RING,
	BLINK_CHARGE,
	BLADE_DANCE,
	WINGMAN,
	SUPERCONDUCTOR,
	EMBER_WARD,
}

var id := &""
var effect := 0
var item_a := -1
var item_b := -1
## v0.4.0 AB: an ability combo's two abilities (indices into World.ability_tables, -1 for an item combo) and the
## level both must reach.
var ability_a := -1
var ability_b := -1
var min_level := 3
var name_key := &""
var desc_key := &""
var damage := 0
var radius_m := 0.0
var stacks := 0
var count := 0
## Shrapnel Storm's fan width in 1/4096 turns.
var spread := 0
var share_permille := 0
var heal := 0
var window_ticks := 0
