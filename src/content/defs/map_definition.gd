class_name MapDefinition
extends ContentDef
## The floor generator's room numbers (v0.7.5 MG, owner N9: "make maps bigger … even bigger rooms … up to 20
## rooms"; CONTENT_SCHEMA). RunContentCompiler.compile_map writes them over FloorParams' defaults, which equal this
## file's starting values (a test keeps them equal), so a floor built without content is the same floor. Every
## number is a starting value the owner tunes (F10 dev panel, Difficulty).

## The most rooms before the boss room (owner N9: up to 20 rooms with it).
const MAX_ROOMS := 19

## Rooms on the floor, the start hall included and the boss room not (the boss room makes one more), inclusive.
@export var rooms_min := 15
@export var rooms_max := 19
## Room footprints after the start hall, in grid cells: footprint k is footprint_x[k] x footprint_y[k], drawn with
## weight footprint_weights[k]. 4 x 4 is the extra-large room.
@export var footprint_x := PackedInt32Array([1, 2, 1, 3, 1, 2, 3, 2, 3, 4, 3, 4])
@export var footprint_y := PackedInt32Array([1, 1, 2, 1, 3, 2, 2, 3, 3, 3, 4, 4])
@export var footprint_weights := PackedInt32Array([22, 14, 14, 8, 8, 12, 7, 7, 5, 2, 2, 2])
## The whole floor fits in this many grid cells either way (the boss room may stick out past it).
@export var max_span := 11
## Random placements tried for each room after the hall before the floor settles for fewer rooms (never below
## rooms_min).
@export var place_attempts := 600
## v0.9.0 TD (owner W §2, Q20 "Allow local timers"): the share of floors (per mille) with a timed door to a secret room
## (starting value 35 %), and the door's timer in ticks from the second switch (15 s at 60 Hz; owner W17 "12–18 s").
@export var timed_door_permille := 350
@export var timed_door_ticks := 900


func category() -> StringName:
	return &"map"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if rooms_min < 2 or rooms_max < rooms_min:
		issues.append(ValidationIssue.new(&"range", resource_path, "2 <= rooms_min <= rooms_max"))
	if rooms_max > MAX_ROOMS:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "rooms_max is at most 19 (20 rooms with the boss room)"
			)
		)
	var n := footprint_weights.size()
	if n == 0 or footprint_x.size() != n or footprint_y.size() != n:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "footprint_x, footprint_y and footprint_weights pair up"
			)
		)
		return issues
	var total := 0
	for k in n:
		if mini(footprint_x[k], footprint_y[k]) < 1 or maxi(footprint_x[k], footprint_y[k]) > 4:
			issues.append(ValidationIssue.new(&"range", resource_path, "a footprint is 1..4 cells"))
		if footprint_weights[k] < 0:
			issues.append(ValidationIssue.new(&"negative", resource_path, "a weight is negative"))
		total += footprint_weights[k]
	check_positive(issues, "the footprint weights' sum", total)
	if max_span < 5 or max_span > 16:
		issues.append(ValidationIssue.new(&"range", resource_path, "max_span is 5..16 cells"))
	check_positive(issues, "place_attempts", place_attempts)
	if timed_door_permille < 0 or timed_door_permille > 1000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "timed_door_permille is 0..1000")
		)
	if timed_door_ticks < 12 * 60 or timed_door_ticks > 18 * 60:
		issues.append(ValidationIssue.new(&"range", resource_path, "timed_door_ticks is 12..18 s"))
	return issues
