class_name OverrunDefinition
extends ContentDef
## The Overrun threat branch (v0.4.0 AB; ROADMAP "Threat T branches", PLAN "Threat branch"): one optional side room
## per floor behind a red-framed door (OverrunRooms). v0.5.5 AR (owner S8): the hardest sealed arena: walking in
## seals it; waves_min..waves_max waves (drawn per room) of wave_sizes[floor] Overrun enemies (more HP and damage)
## spawn inside, the next when the last one dies; after the last wave the doors open, an altar appears offering
## ability cards (level-ups of what you own first) and the shards those kills paid are paid again (2x). Every number
## is a starting value the owner tunes after playing.

## Overrun enemies' HP and damage, as multipliers.
@export var hp_multiplier := 1.5
@export var damage_multiplier := 1.5
## v0.5.5 AR (S8): waves per Overrun (drawn per room) and each wave's size on floors 1, 2, 3.
@export var waves_min := 3
@export var waves_max := 5
@export var wave_sizes := PackedInt32Array([4, 8, 12])
## What the clear pays on the shards those kills paid (2.0 = they count twice).
@export var shard_multiplier := 2.0


func category() -> StringName:
	return &"overrun"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for pair: Array in [
		["hp_multiplier", hp_multiplier],
		["damage_multiplier", damage_multiplier],
		["shard_multiplier", shard_multiplier],
	]:
		if pair[1] < 1.0:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s is at least 1" % pair[0])
			)
	check_positive(issues, "waves_min", waves_min)
	if waves_max < waves_min:
		issues.append(ValidationIssue.new(&"range", resource_path, "waves_max >= waves_min"))
	issues.append_array(ArenaDefinition.wave_size_issues(resource_path, wave_sizes))
	return issues
