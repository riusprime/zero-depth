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
## The share of chest offers that are cursed (one card becomes a guaranteed epic stat card plus a curse).
@export var cursed_chest_chance := 25.0
## An elite: +this % HP (Ambush Cache packs, and spawns under an elite curse).
@export var elite_hp_bonus := 100.0
## Ambush Cache: the pack arrives at least this far from you, inside the room.
@export var ambush_min_distance_m := 4.0
## Wandering Drone: stay within this distance of the pedestal.
@export var defend_radius_m := 4.5


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
	]:
		check_positive(issues, f[0], f[1])
	if cursed_chest_chance < 0.0 or cursed_chest_chance > 100.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cursed_chest_chance 0..100"))
	if elite_hp_bonus < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "elite_hp_bonus is negative"))
	return issues
