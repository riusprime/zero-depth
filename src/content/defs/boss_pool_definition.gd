class_name BossPoolDefinition
extends ContentDef
## The bosses a floor tier draws from (PLAN v0.3.0 L5): two each since v0.4.0 BO (RunState.pick_boss draws one).

@export var floor_index := 1
@export var boss_ids := PackedStringArray()


func category() -> StringName:
	return &"boss_pools"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if floor_index < 1:
		issues.append(
			ValidationIssue.new(&"not_positive", resource_path, "floor_index must be >= 1")
		)
	if boss_ids.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a pool needs bosses"))
	return issues
