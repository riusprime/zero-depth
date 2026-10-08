class_name OverrunDefinition
extends ContentDef
## The Overrun threat branch (v0.4.0 AB; ROADMAP "Threat T branches", PLAN "Threat branch"): one optional side room
## per floor behind a red-framed door (OverrunRooms). While you are inside it, enemies that arrive are Overrun
## enemies (more HP and damage) and they arrive more often and in larger numbers; killing kills_to_clear of them
## clears it: an altar appears offering ability cards (level-ups of what you own first) and the shards those kills
## paid are paid again (2x). Every number is a starting value the owner tunes after playing.

## Overrun enemies' HP and damage, and the spawn rate and alive cap while you are inside, as multipliers.
@export var hp_multiplier := 1.5
@export var damage_multiplier := 1.5
@export var spawn_multiplier := 1.5
## Overrun enemies to kill to clear the room.
@export var kills_to_clear := 12
## What the clear pays on the shards those kills paid (2.0 = they count twice).
@export var shard_multiplier := 2.0


func category() -> StringName:
	return &"overrun"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for pair: Array in [
		["hp_multiplier", hp_multiplier],
		["damage_multiplier", damage_multiplier],
		["spawn_multiplier", spawn_multiplier],
		["shard_multiplier", shard_multiplier],
	]:
		if pair[1] < 1.0:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s is at least 1" % pair[0])
			)
	check_positive(issues, "kills_to_clear", kills_to_clear)
	return issues
