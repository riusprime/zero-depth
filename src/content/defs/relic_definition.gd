class_name RelicDefinition
extends ContentDef
## A relic, a run-long passive that no
## altar, chest or shop ever offers: it lies on one pedestal and is taken by hand. The id names the relic and its rule
## (Relics, one per id in RELICS order):
## - city_heart (the hidden room under the Hollow Crown's throne, HeartRoom): `uses` times a run (1), the first killing
##   blow on the hero instead leaves them at `saved_hp` HP (1) and pulses a shock ring of `ring_radius_m` (4 m) that
##   deals `ring_damage` to every enemy in it. OWNER-PENDING PLACEHOLDER: the lead's idea, built so the room has
##   its reward; the owner approves or replaces it (`placeholder` stays true until then).

## The relics in the sim's order (Relics' indices). Appended, never renumbered.
const RELICS: Array[StringName] = [&"city_heart"]

@export var name_key: StringName
@export var desc_key: StringName
## How many times a run the rule fires (a relic is held once; a loop keeps it and what it spent).
@export var uses := 1
## The HP a saved killing blow leaves.
@export var saved_hp := 1
## The shock ring's radius (m) and damage to each enemy inside it.
@export var ring_radius_m := 4.0
@export var ring_damage := 60
## True while the relic is the lead's placeholder awaiting the owner.
@export var placeholder := false


func category() -> StringName:
	return &"relic"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not RELICS.has(id):
		issues.append(ValidationIssue.new(&"unknown", resource_path, "unknown relic %s" % id))
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if uses < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "uses is at least 1"))
	if saved_hp < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "saved_hp is at least 1"))
	check_positive(issues, "ring_radius_m", ring_radius_m)
	if ring_damage < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "ring_damage is negative"))
	return issues
