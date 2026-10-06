# Ported from riusprime/deathventory@1d697803:src/domain/model/validation_issue.gd. Changes: header only.
class_name ValidationIssue extends RefCounted

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


func to_dict() -> Dictionary:
	return {"code": String(code), "path": path, "message": message, "severity": int(severity)}
