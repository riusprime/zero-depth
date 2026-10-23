class_name ArenaDefinition
extends ContentDef
## The sealed arenas (v0.5.5 AR; PLAN D2, X1 "open floor, sealed arenas"; CONTENT_SCHEMA): about a third of a floor's
## combat rooms seal when you walk in, fight in waves spawning inside and hold the floor's chests and altars, locked
## until the last wave dies; the rest of the floor goes dark while you're sealed. The Overrun room is the hardest
## arena (OverrunDefinition has its own waves). Every number is a starting value the owner tunes after playing.

## The share of a floor's combat rooms that are arenas (0..1). v0.7.5 MG (owner N11, "reduce the amount of challenge
## rooms … like 20% less"): 0.11 (was 0.33): on the bigger floors (15-19 rooms) a floor's challenge rooms, the
## Overrun room and the arenas, average 2.4 (was 3.2 on 10-12 rooms; docs/roadmap/v0.7.5/evidence/MAPS.md).
@export var share := 0.11
## Waves per arena (drawn per room), and each wave's size on floors 1, 2, 3 (the last repeats on later floors).
@export var waves_min := 2
@export var waves_max := 3
@export var wave_sizes := PackedInt32Array([3, 5, 7])
## Seconds from the seal to the first wave, and from a wave's last kill to the next.
@export var first_wave_seconds := 0.75
@export var wave_gap_seconds := 1.0
## A wave's enemies spawn at least this far from you (m) where the room allows.
@export var min_spawn_distance := 3.0
## v0.9.0 CF (owner: "lets never make it a 1x1 ... the enemies that spawn at the same time should be proportional to
## the room size"): the fight never takes a room of fewer than min_cells grid cells (2: never a 1 x 1), and holds at
## most its floor area / area_per_enemy_m2 enemies at once (an elite counts EliteRulesDefinition.elite_weight); the
## rest come in as earlier ones die (ClosedFights). Starting values.
@export var min_cells := 2
@export var area_per_enemy_m2 := 30.0


func category() -> StringName:
	return &"arena"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if share < 0.0 or share > 1.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "share is in 0..1"))
	check_positive(issues, "waves_min", waves_min)
	if waves_max < waves_min:
		issues.append(ValidationIssue.new(&"range", resource_path, "waves_max >= waves_min"))
	issues.append_array(wave_size_issues(resource_path, wave_sizes))
	if first_wave_seconds < 0.0 or wave_gap_seconds < 0.0 or min_spawn_distance < 0.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "times and distances are >= 0"))
	issues.append_array(closed_fight_issues(resource_path, min_cells, area_per_enemy_m2))
	return issues


## v0.9.0 CF, shared with the Overrun, Lockdown and shrine definitions: a room need >= 1 cell, a budget >= 0 m2
## (0: no cap).
static func closed_fight_issues(path: String, cells: int, per_m2: float) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	if cells < 1 or per_m2 < 0.0:
		out.append(ValidationIssue.new(&"range", path, "min_cells >= 1, area_per_enemy_m2 >= 0"))
	return out


## Shared with OverrunDefinition: at least one size, each positive.
static func wave_size_issues(path: String, sizes: PackedInt32Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	if sizes.is_empty():
		out.append(ValidationIssue.new(&"range", path, "wave_sizes needs a size per floor"))
	for n in sizes:
		if n <= 0:
			out.append(ValidationIssue.new(&"range", path, "wave sizes are positive"))
			break
	return out
