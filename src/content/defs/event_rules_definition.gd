class_name EventRulesDefinition
extends ContentDef
## The rules around event rooms and curses (v0.5.0 EV, PLAN R3-R4; CONTENT_SCHEMA §9). Every number is a starting
## value the owner tunes after playing.

## Event rooms per floor.
@export var rooms_min := 1
@export var rooms_max := 2
## The pedestal: interact reach, and the clearance it keeps from walls and from the floor's altars and chests.
@export var interact_radius_m := 1.6
@export var clear_radius_m := 1.0
@export var reward_gap_m := 3.0
## The share of chest offers that are cursed (v0.6.0 CU, owner S6: one card becomes a trade-off curse card).
@export var cursed_chest_chance := 25.0
## An elite: +this % HP (Ambush Cache packs, and spawns under an elite curse).
@export var elite_hp_bonus := 100.0
## Ambush Cache: the pack arrives at least this far from you, inside the room.
@export var ambush_min_distance_m := 4.0
## Wandering Drone: stay within this distance of the pedestal.
@export var defend_radius_m := 4.5
## The shop's cleanse: lifting the latest curse costs this many shards x the floor (SH's terminal).
@export var cleanse_price := 60
## v0.6.0 CU core theft (PLAN v0.5.5 X2; SIGNATURE.md): an elite staggers once it took this % of its max HP in
## direct damage since its last stagger, and stands staggered for core_stagger_seconds; a stagger (an elite's, or a
## boss's own) opens a steal window of core_window_seconds. An elite's core is a mod (each weighs core_mod_weight)
## or a rare stat card (its card weight).
@export var core_stagger_share := 30.0
@export var core_stagger_seconds := 0.75
@export var core_window_seconds := 2.0
@export var core_mod_weight := 10
## v0.6.0 CU, Marked (C8): elites within this distance hunt you. A drop (a stolen core, Marked's rare card) lands this
## far from the next drop at the same spot.
@export var hunt_range_m := 16.0
@export var drop_offset_m := 0.9


func category() -> StringName:
	return &"event_rules"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if rooms_min < 0 or rooms_max < rooms_min:
		issues.append(ValidationIssue.new(&"range", resource_path, "0 <= rooms_min <= rooms_max"))
	for f: Array in [
		["interact_radius_m", interact_radius_m],
		["clear_radius_m", clear_radius_m],
		["reward_gap_m", reward_gap_m],
		["ambush_min_distance_m", ambush_min_distance_m],
		["defend_radius_m", defend_radius_m],
		["core_stagger_share", core_stagger_share],
		["core_stagger_seconds", core_stagger_seconds],
		["core_window_seconds", core_window_seconds],
		["hunt_range_m", hunt_range_m],
		["drop_offset_m", drop_offset_m],
	]:
		check_positive(issues, f[0], f[1])
	if cursed_chest_chance < 0.0 or cursed_chest_chance > 100.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cursed_chest_chance 0..100"))
	if cleanse_price <= 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cleanse_price must be > 0"))
	if core_mod_weight < 0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "core_mod_weight is negative")
		)
	if elite_hp_bonus < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "elite_hp_bonus is negative"))
	return issues
