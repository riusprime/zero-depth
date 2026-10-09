class_name EventRules
extends RefCounted
## The compiled event-room and curse rules (v0.5.0 EV; EventCompiler from EventRulesDefinition): per mille and
## metres. Defaults match data/event_rules/floor.tres.

var rooms_min := 1
var rooms_max := 2
var interact_radius_m := 1.6
var clear_radius_m := 1.0
var reward_gap_m := 3.0
var cursed_chest_permille := 250
var elite_hp_bonus_permille := 1000
var ambush_min_distance_m := 4.0
var defend_radius_m := 4.5
var cleanse_price := 60
## v0.6.0 CU core theft: an elite's stagger (per mille of its max HP in direct damage), its length and the steal
## window (ticks), a mod core's draw weight; Marked's hunt range and the spacing of drops at one spot.
var core_stagger_permille := 300
var core_stagger_ticks := 45
var core_window_ticks := 120
var core_mod_weight := 10
var hunt_range_m := 16.0
var drop_offset_m := 0.9
