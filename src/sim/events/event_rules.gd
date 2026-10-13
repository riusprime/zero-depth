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
## v0.7.5 MG (owner N10, "the curse appear too often we're gonna have one every two floors"): chests roll the curse
## only on curse floors (FloorCadence: cursed_chest_first_floor, then every cursed_chest_every_floors floors; 1, 3,
## 5 ... as shipped), and at most cursed_chests_per_floor of a floor's chest offers are cursed.
var cursed_chest_first_floor := 1
var cursed_chest_every_floors := 2
var cursed_chests_per_floor := 1
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


## Whether floor `floor_index` (the run's floor number, counted on past the run's last floor) may hold cursed chests.
func curse_floor(floor_index: int) -> bool:
	return FloorCadence.on(floor_index, cursed_chest_first_floor, cursed_chest_every_floors)
