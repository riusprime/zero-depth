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
	issues.append_array(ComboDefinition.cross_check(defs))  # Combo pairs.
	issues.append_array(AbilityDefinition.cross_check(defs))  # Engine items.
	issues.append_array(ModifierDefinition.cross_check(defs))  # Item modifiers.
	issues.append_array(WandMigrationDefinition.cross_check(defs))  # The old cards' map.
	issues.append_array(AttackSlotsDefinition.cross_check(defs))  # Slot categories, the table.
	issues.append_array(SpecialRoomDefinition.cross_check(defs))  # The numbers it repeats
	issues.append_array(EnemyDefinition.cross_check(defs))  # The matchup ids
	issues.append_array(BiomeDefinition.cross_check(defs))  # Each biome's horde critter
	issues.sort_custom(
		func(a: ValidationIssue, b: ValidationIssue) -> bool:
			return [a.path, a.code, a.message] < [b.path, b.code, b.message]
	)
	return issues


static func errors(issues: Array[ValidationIssue]) -> Array[ValidationIssue]:
	return issues.filter(
		func(i: ValidationIssue) -> bool: return i.severity == ValidationIssue.Severity.ERROR
	)
