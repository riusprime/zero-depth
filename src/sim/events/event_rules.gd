class_name EventRules
extends RefCounted
## The compiled event-room and curse rules (v0.5.0 EV; EventCompiler from EventRulesDefinition): per mille and
## metres. Defaults match data/event_rules/floor.tres.

var rooms_min := 1
var rooms_max := 2
## See EventRulesDefinition. events_max_per_run 0 = the old draw (rooms_min..rooms_max every floor).
var event_floor_chance_permille := 1000
var events_max_per_run := 0
var interact_radius_m := 1.6
var clear_radius_m := 1.0
var reward_gap_m := 3.0
var cursed_chest_permille := 250
## Chests roll the curse
## only on curse floors (FloorCadence: cursed_chest_first_floor, then every cursed_chest_every_floors floors; 1, 3,
## 5 ... as shipped), and at most cursed_chests_per_floor of a floor's chest offers are cursed.
var cursed_chest_first_floor := 1
var cursed_chest_every_floors := 2
var cursed_chests_per_floor := 1
var defend_radius_m := 4.5
## v0.6.0 CU core theft: a boss's steal window (ticks), a mod core's draw weight and the spacing of drops at one spot.
## (the elite's stagger, its HP bonus, the ambush's distance and Marked's hunt range are gone.)
var core_window_ticks := 120
var core_mod_weight := 10
## The chance a boss's core is Legendary, in per mille (350 as shipped; else an Epic card).
var boss_core_legendary_permille := 350
var drop_offset_m := 0.9
## The chance a
## floor has a curse room, in per mille (Events.curse_site, on `map:curse_room`).
var curse_room_floor_chance_permille := 400
## The chance on a Deep floor (1000: every Deep floor has one, as Whispering
## Deep lives at its altar).
var curse_room_deep_chance_permille := 1000


## Whether floor `floor_index` (the run's floor number, counted on past the run's last floor) may hold cursed chests.
func curse_floor(floor_index: int) -> bool:
	return FloorCadence.on(floor_index, cursed_chest_first_floor, cursed_chest_every_floors)
