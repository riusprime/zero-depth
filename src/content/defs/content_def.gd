class_name ContentDef
extends Resource
## Base for every content definition (CONTENT_SCHEMA §0): a stable id, a category, and validate().

@export var id: StringName


## The repository groups definitions by this name.
func category() -> StringName:
	return &""


func validate() -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	if String(id).is_empty():
		issues.append(ValidationIssue.new(&"id_empty", resource_path, "id is empty"))
	elif not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(String(id)):
		issues.append(
			ValidationIssue.new(&"id_format", resource_path, "id must be snake_case: %s" % id)
		)
	return issues


## An ERROR if a non-zero duration rounds to 0 ticks at 60 Hz.
func check_duration(issues: Array[ValidationIssue], field: String, seconds: float) -> void:
	if seconds < 0.0:
		issues.append(
			ValidationIssue.new(&"duration_negative", resource_path, "%s is negative" % field)
		)
	elif seconds > 0.0 and int(round(seconds * 60.0)) == 0:
		issues.append(
			ValidationIssue.new(
				&"duration_zero_ticks", resource_path, "%s rounds to 0 ticks" % field
			)
		)


func check_positive(issues: Array[ValidationIssue], field: String, value: float) -> void:
	if value <= 0.0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "%s must be > 0" % field))
