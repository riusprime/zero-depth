class_name ContentValidator
extends RefCounted
## Validates every definition with no early exit, plus duplicate ids per category (adapted from Deathventory's
## content_validator.gd). Issues are sorted by (path, code, message).


static func validate(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var seen := {}
	for d in defs:
		issues.append_array(d.validate())
		var key := "%s/%s" % [d.category(), d.id]
		if seen.has(key):
			issues.append(
				ValidationIssue.new(
					&"duplicate_id", d.resource_path, "duplicate id %s (also %s)" % [key, seen[key]]
				)
			)
		else:
			seen[key] = d.resource_path
	issues.append_array(ComboDefinition.cross_check(defs))  # v0.3.0 G: combo pairs.
	issues.append_array(AbilityDefinition.cross_check(defs))  # v0.4.0 AB: engine items.
	issues.sort_custom(
		func(a: ValidationIssue, b: ValidationIssue) -> bool:
			return [a.path, a.code, a.message] < [b.path, b.code, b.message]
	)
	return issues


static func errors(issues: Array[ValidationIssue]) -> Array[ValidationIssue]:
	return issues.filter(
		func(i: ValidationIssue) -> bool: return i.severity == ValidationIssue.Severity.ERROR
	)
