class_name EventRulesDefinition
extends ContentDef
## The rules around event rooms and curses (v0.5.0 EV, PLAN R3-R4; CONTENT_SCHEMA §9). Every number is a starting
## value the owner tunes after playing.

## Event rooms per floor.
@export var rooms_min := 1
@export var rooms_max := 2
## v0.9.5 AQ (owner: event altars "more special like the curse room"): when events_max_per_run > 0, a floor has an event
## room on event_floor_chance_permille of floors (rooms_max of them), at most events_max_per_run a run, never the same
## event twice. 0 keeps the old draw (rooms_min..rooms_max every floor).
@export var event_floor_chance_permille := 1000
@export var events_max_per_run := 0
## The pedestal: interact reach, and the clearance it keeps from walls and from the floor's altars and chests.
@export var interact_radius_m := 1.6
@export var clear_radius_m := 1.0
@export var reward_gap_m := 3.0
## The share of chest offers that are cursed (v0.6.0 CU, owner S6: one card becomes a trade-off curse card).
@export var cursed_chest_chance := 25.0
## v0.7.5 MG (owner N10, "one every two floors"): chests roll that chance only on curse floors: the first, then every
## cursed_chest_every_floors floors (1, 3, 5 ... as shipped; the floor count keeps going past the run's last floor);
## at most cursed_chests_per_floor cursed chest offers on one floor.
@export var cursed_chest_first_floor := 1
@export var cursed_chest_every_floors := 2
@export var cursed_chests_per_floor := 1
## Wandering Drone: stay within this distance of the pedestal.
@export var defend_radius_m := 4.5
## The shop's cleanse: lifting the latest curse costs this many shards x the floor (SH's terminal).
@export var cleanse_price := 60
## v0.6.0 CU core theft (PLAN v0.5.5 X2; SIGNATURE.md): a boss's steal window of core_window_seconds (v0.9.5 BH1, Q3:
## 3 s from the start of each phase change; it was 2 s from a stagger). An elite's core is a mod (each weighs
## core_mod_weight) or a rare stat card (its card weight).
## v0.9.0 EL (owner Q25): an elite no longer staggers (its 30 % drop: data/elites/rules.tres); the elite HP bonus,
## the Ambush Cache's distance and Marked's hunt range went with them.
@export var core_window_seconds := 3.0
@export var core_mod_weight := 10
## A drop (a core's card) lands this far from the next drop at the same spot.
@export var drop_offset_m := 0.9
## v0.8.0 N17 (owner O75: "they need to appear once max per floor and 40% of floors not all the time"): the chance a
## floor has a curse room (one combat room holding the curse altar and the floor's curse event), in per mille (400:
## 40 % of floors).
@export var curse_room_floor_chance_permille := 400
## v0.8.0 N19 (owner O80: "Should Whispering Deep move into the curse room? yes"): the chance on a Deep floor, in
## per mille (1000: every Deep floor has a curse room, so S5's Whispering Deep on every Deep floor holds).
@export var curse_room_deep_chance_permille := 1000


func category() -> StringName:
	return &"event_rules"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if rooms_min < 0 or rooms_max < rooms_min:
		issues.append(ValidationIssue.new(&"range", resource_path, "0 <= rooms_min <= rooms_max"))
	if event_floor_chance_permille < 0 or event_floor_chance_permille > 1000:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "event_floor_chance_permille is outside 0..1000"
			)
		)
	if events_max_per_run < 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "events_max_per_run is below 0"))
	for f: Array in [
		["interact_radius_m", interact_radius_m],
		["clear_radius_m", clear_radius_m],
		["reward_gap_m", reward_gap_m],
		["defend_radius_m", defend_radius_m],
		["core_window_seconds", core_window_seconds],
		["drop_offset_m", drop_offset_m],
	]:
		check_positive(issues, f[0], f[1])
	if cursed_chest_chance < 0.0 or cursed_chest_chance > 100.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cursed_chest_chance 0..100"))
	if cursed_chest_first_floor < 1 or cursed_chest_every_floors < 1 or cursed_chests_per_floor < 0:
		issues.append(
			ValidationIssue.new(
				&"range",
				resource_path,
				"cursed_chest_first_floor and _every_floors >= 1, _per_floor >= 0"
			)
		)
	if curse_room_floor_chance_permille < 0 or curse_room_floor_chance_permille > 1000:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "curse_room_floor_chance_permille is outside 0..1000"
			)
		)
	if curse_room_deep_chance_permille < 0 or curse_room_deep_chance_permille > 1000:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "curse_room_deep_chance_permille is outside 0..1000"
			)
		)
	if cleanse_price <= 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cleanse_price must be > 0"))
	if core_mod_weight < 0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "core_mod_weight is negative")
		)
	return issues
