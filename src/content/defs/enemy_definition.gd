class_name EnemyDefinition
extends ContentDef
## An enemy (CONTENT_SCHEMA §3): numbers, a behaviour (src/sim/ai/) with its params, and its attacks.

@export var name_key: StringName
@export var behaviour_id: StringName
@export var behaviour_params := {}
@export var hp := 10
@export var radius_m := 0.4
@export var move_speed_mps := 3.0
@export var attacks: Array[AttackDefinition] = []
@export var stress_tags := PackedStringArray()


func category() -> StringName:
	return &"enemies"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "name_key is required"))
	if hp <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "hp must be > 0"))
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "move_speed_mps", move_speed_mps)
	var schema: Dictionary = BehaviourSchemas.SCHEMAS.get(behaviour_id, {})
	if schema.is_empty():
		issues.append(
			ValidationIssue.new(
				&"unknown_behaviour", resource_path, "unknown behaviour %s" % behaviour_id
			)
		)
		return issues
	_check_keys(issues, "behaviour_params", behaviour_params, schema["params"])
	if attacks.size() != 1:
		issues.append(
			ValidationIssue.new(&"attacks", resource_path, "this behaviour takes exactly 1 attack")
		)
		return issues
	var atk := attacks[0]
	if atk == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "attack is missing"))
		return issues
	if atk.shape != schema["shape"]:
		issues.append(
			ValidationIssue.new(
				&"shape", resource_path, "%s needs a different shape" % behaviour_id
			)
		)
	_check_keys(issues, "shape_params", atk.shape_params, schema["shape_params"])
	if int(round(atk.telegraph_seconds * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				resource_path,
				(
					"%s telegraph %.2f s is under the %d-tick minimum"
					% [atk.id, atk.telegraph_seconds, BehaviourSchemas.MIN_TELEGRAPH_TICKS]
				)
			)
		)
	check_duration(issues, "active_seconds", atk.active_seconds)
	check_duration(issues, "recovery_seconds", atk.recovery_seconds)
	if atk.damage <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "damage must be > 0"))
	return issues


func _check_keys(
	issues: Array[ValidationIssue], field: String, got: Dictionary, need: Array
) -> void:
	for k in need:
		if not got.has(k):
			issues.append(
				ValidationIssue.new(
					&"param_missing", resource_path, "%s.%s is missing" % [field, k]
				)
			)
	for k in got:
		if not need.has(k):
			issues.append(
				ValidationIssue.new(
					&"param_unknown", resource_path, "%s.%s is unknown" % [field, k]
				)
			)
