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
