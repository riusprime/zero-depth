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
	if behaviour_id == &"warden":
		_check_armour(issues)
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


## The Warden's armour (owner, 2026-10-07): arcs within 0..360 that don't overlap, a front multiplier that softens
## without blocking (1..1000 per mille) and a rear one that doesn't soften (1000..3000).
func _check_armour(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	var keys := [
		"front_arc_degrees", "rear_arc_degrees", "front_mult_permille", "rear_mult_permille"
	]
	for k in keys:
		if not bp.has(k):
			return
	var front := float(bp["front_arc_degrees"])
	var rear := float(bp["rear_arc_degrees"])
	for pair in [["front_arc_degrees", front], ["rear_arc_degrees", rear]]:
		if pair[1] < 0.0 or pair[1] > 360.0:
			issues.append(
				ValidationIssue.new(&"armour", resource_path, "%s must be within 0..360" % pair[0])
			)
	if front + rear > 360.0:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "front_arc_degrees + rear_arc_degrees must be <= 360"
			)
		)
	var fm := int(bp["front_mult_permille"])
	if fm < 1 or fm > 1000:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "front_mult_permille must be within 1..1000 (no block)"
			)
		)
	var rm := int(bp["rear_mult_permille"])
	if rm < 1000 or rm > 3000:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "rear_mult_permille must be within 1000..3000"
			)
		)


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
