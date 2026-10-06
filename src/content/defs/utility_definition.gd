class_name UtilityDefinition
extends ContentDef
## A utility skill, one chosen before the run (PD-01; CONTENT_SCHEMA §8). Kind GUARD uses the guard fields,
## kind BLINK the blink fields. Values are starting values (the v0.1.0 PLAN).

enum Kind { GUARD, BLINK }

@export var kind := Kind.GUARD
@export var name_key: StringName
@export var desc_key: StringName
## Guard: the arc in front of the aim it covers, what a hit from inside it keeps, the speed while guarding.
@export var guard_arc_degrees := 120.0
@export var guard_multiplier := 0.2
@export var guard_move_multiplier := 0.4
## Blink: the longest jump, the cooldown, the invulnerable time.
@export var blink_range_m := 5.0
@export var blink_cooldown_seconds := 2.5
@export var blink_iframes_seconds := 0.1


func category() -> StringName:
	return &"utility"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	match kind:
		Kind.GUARD:
			check_positive(issues, "guard_arc_degrees", guard_arc_degrees)
			check_positive(issues, "guard_move_multiplier", guard_move_multiplier)
			if guard_multiplier < 0.0 or guard_multiplier > 1.0:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "guard_multiplier is 0..1")
				)
		Kind.BLINK:
			check_positive(issues, "blink_range_m", blink_range_m)
			check_duration(issues, "blink_cooldown_seconds", blink_cooldown_seconds)
			check_duration(issues, "blink_iframes_seconds", blink_iframes_seconds)
	return issues
