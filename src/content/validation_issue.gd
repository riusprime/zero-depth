# Ported from riusprime/deathventory@1d697803:src/domain/model/validation_issue.gd. Changes: header; to_dict() removed
# (no caller).
class_name ValidationIssue extends RefCounted

## CONTENT_SCHEMA §0 names both severities, but nothing creates a WARNING yet: every issue is an ERROR, so
## ContentValidator.errors() returns them all.
enum Severity { ERROR = 0, WARNING = 1 }

var code: StringName = &""
var path: String = ""
var message: String = ""
var severity: Severity = Severity.ERROR


func _init(
	p_code: StringName = &"",
	p_path: String = "",
	p_message: String = "",
	p_severity: Severity = Severity.ERROR
) -> void:
	code = p_code
	path = p_path
	message = p_message
	severity = p_severity
