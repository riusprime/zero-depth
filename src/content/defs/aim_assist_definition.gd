class_name AimAssistDefinition
extends ContentDef
## How much the aim bends toward an enemy (AimAssist). Read on the app side only, never by the sim: the frame the
## sim gets already holds the bent aim. Its own file under data/tuning, so the dev panel's Sim group tunes it live.

## How far the aim turns toward the target, in % of the angle between them (100: straight at it).
@export_range(0, 100) var strength_percent := 10
## The half-width of the cone around the raw aim an enemy must be inside, in degrees.
@export var cone_degrees := 12.0
## The farthest an enemy can be and still pull, in metres (the Seekers' homing reach, about the half screen).
@export var range_m := 12.0


func category() -> StringName:
	return &"tuning"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if strength_percent < 0 or strength_percent > 100:
		issues.append(ValidationIssue.new(&"range", resource_path, "strength_percent in 0..100"))
	if cone_degrees < 0.0 or cone_degrees > 90.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cone_degrees in 0..90"))
	check_positive(issues, "range_m", range_m)
	return issues
