class_name PlayerDefinition
extends ContentDef
## The player character (CONTENT_SCHEMA §8). Values: starting values listed in GAME_BLUEPRINT §C.

@export var hp := 100
@export var radius_m := 0.35
@export var move_speed_mps := 6.0
@export var dash: DashDefinition
@export var primary: PrimaryDefinition
## After taking a hit: invulnerability and hit-stop.
@export var hurt_iframes_seconds := 0.5
@export var hurt_hitstop_seconds := 4.0 / 60.0


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
	check_duration(issues, "hurt_iframes_seconds", hurt_iframes_seconds)
	check_duration(issues, "hurt_hitstop_seconds", hurt_hitstop_seconds)
	if primary == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "primary is missing"))
	else:
		_check_primary(issues)
	return issues


func _check_primary(issues: Array[ValidationIssue]) -> void:
	var p := primary
	check_duration(issues, "primary.swing_duration_seconds", p.swing_duration_seconds)
	check_duration(issues, "primary.swing_active_seconds", p.swing_active_seconds)
	check_duration(issues, "primary.shot_period_seconds", p.shot_period_seconds)
	check_positive(issues, "primary.swing_reach_m", p.swing_reach_m)
	check_positive(issues, "primary.bolt_speed_mps", p.bolt_speed_mps)
	if p.swing_damage.is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "primary.swing_damage is empty")
		)
	if p.swing_active_seconds > p.swing_duration_seconds:
		issues.append(
			ValidationIssue.new(&"order", resource_path, "the swing must hit before it ends")
		)
	if p.shot_period_seconds <= 0.0 or p.bolt_damage <= 0:
		issues.append(
			ValidationIssue.new(
				&"not_positive", resource_path, "shooting needs a period and damage"
			)
		)
