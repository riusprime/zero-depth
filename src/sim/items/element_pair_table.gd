class_name ElementPairTable
extends RefCounted
## The element pairs' numbers in sim units (ElementPairsDefinition compiled by WandCompiler.pairs): seconds
## as ticks, set at setup and never written in play (World.pair_table).

var level_permille := PackedInt32Array([400, 700, 1000])  # Strength at pair Lv 1/2/3
## An element's damage on an enemy carrying k other elements, per mille, k = 0, 1, 2, 3+ (ElementStack;
## empty = no falloff).
var stack_falloff_permille := PackedInt32Array()
## C1 Prism on a Blade run: the falloff steps (k) each Prism held takes off (ElementStack).
var prism_falloff_steps := 1
var storm_mark_ticks := 0  # How long a Lightning hit leaves its enemy charged (0 = none)
var triggers_per_second := 4
var burst_permille := 3000
var burst_radius_m := 1.5
var cloud_radius_m := 2.0
var cloud_ticks := 180
var cloud_stacks := 1
var cloud_gap_ticks := 60
var arc_burn_stacks := 1
var arc_poison_stacks := 1
var arc_bleed_stacks := 1
var boil_permille := 2000
var circuit_permille := 2000
var ice_slow_permille := 200
var brittle_radius_m := 2.0
var sepsis_stacks := 3
var sepsis_permille := 1200
