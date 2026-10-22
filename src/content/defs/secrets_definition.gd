class_name SecretsDefinition
extends ContentDef
## v0.9.0 RA (owner W §4 A, Q22; CONTENT_SCHEMA): the floor's secrets' numbers, read by FloorPlan when it builds a floor
## (data/secrets/secrets.tres, category `secrets`, id `secrets`). Every number is a starting value the owner tunes.

## The share of floors (per mille) with a rune puzzle: three pillars before a sealed dead end (starting value 30 %).
@export var rune_permille := 300


func category() -> StringName:
	return &"secrets"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	_check_permille(issues, "rune_permille", rune_permille)
	return issues


func _check_permille(issues: Array[ValidationIssue], field: String, value: int) -> void:
	if value < 0 or value > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s is 0..1000" % field))
