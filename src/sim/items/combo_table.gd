class_name ComboTable
extends RefCounted
## One named combo compiled to sim units: its two items (indices into World.item_tables) and its
## effect's numbers. Built from ComboDefinition by ContentCompiler.compile_combos.

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
## A deleted combo's stub (CardOrder.RETIRED_COMBOS): no halves, never earned; a save's entry is dropped.
var retired := false
var item_a := -1
var item_b := -1
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
