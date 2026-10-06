class_name EncounterDefinition
extends ContentDef
## A fight: waves of enemies (CONTENT_SCHEMA §4). Clearing the last wave clears the encounter.

@export var tags := PackedStringArray()
@export var waves: Array[WaveDefinition] = []
@export var min_floor := 1
@export var max_floor := 3
@export var threat_cost := 0
## Enemies never appear closer than this to the player (GAME_BLUEPRINT §G: at least 6 m from the entry).
@export var min_spawn_distance_m := 6.0


func category() -> StringName:
	return &"encounters"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if waves.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "an encounter needs waves"))
	for k in waves.size():
		var wv := waves[k]
		if wv == null or wv.spawns.is_empty():
			issues.append(
				ValidationIssue.new(&"missing", resource_path, "wave %d is empty" % (k + 1))
			)
			continue
		check_duration(issues, "waves[%d].delay_seconds" % k, wv.delay_seconds)
		for s in wv.spawns:
			if s == null or String(s.enemy_id).is_empty() or s.count <= 0:
				issues.append(
					ValidationIssue.new(
						&"spawn", resource_path, "wave %d has a bad spawn" % (k + 1)
					)
				)
	return issues


## Enemy ids that must exist in the repository (checked by the cross-reference test).
func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for wv in waves:
		for s in wv.spawns:
			if not out.has(s.enemy_id):
				out.append(s.enemy_id)
	return out
