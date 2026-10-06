class_name PlayerDefinition
extends ContentDef
## The player character (CONTENT_SCHEMA §8). Values: starting values listed in GAME_BLUEPRINT §C.

@export var hp := 100
@export var radius_m := 0.35
@export var move_speed_mps := 6.0
@export var dash: DashDefinition


func category() -> StringName:
	return &"player"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if hp <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "hp must be > 0"))
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "move_speed_mps", move_speed_mps)
	if dash == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "dash is missing"))
	else:
		check_positive(issues, "dash.distance_m", dash.distance_m)
		check_duration(issues, "dash.duration_seconds", dash.duration_seconds)
		check_duration(issues, "dash.cooldown_seconds", dash.cooldown_seconds)
		check_duration(issues, "dash.iframes_seconds", dash.iframes_seconds)
		if dash.duration_seconds <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"not_positive", resource_path, "dash.duration_seconds must be > 0"
				)
			)
	return issues
