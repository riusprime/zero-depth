class_name EventDefinition
extends ContentDef
## An event room's event (v0.5.0 EV, PLAN R3; CONTENT_SCHEMA §9): a lit pedestal you interact with; its panel offers
## one or two choices (EventChoiceDefinition), each a cost and a reward, and always "Leave". `requires` keeps an
## event off a floor where it could do nothing: &"" (always), &"curse" (you carry a curse: the cleanse),
## &"heat" (the run has Overclock heat), &"stat_card" (you raised a stat), &"ability" (an ability can level up).

const REQUIRES: Array[StringName] = [&"", &"curse", &"heat", &"stat_card", &"ability"]
const MAX_CHOICES := 2

@export var name_key: StringName
@export var desc_key: StringName
## Draw weight against the other events of the floor.
@export var weight := 10
## The first floor it can appear on.
@export var min_floor := 1
@export var requires: StringName = &""
## v0.5.5 DS (S5): only on Deep floors, and a Deep floor's first pedestal holds one (Events.draw_event).
@export var deep_only := false
@export var choices: Array[EventChoiceDefinition] = []


func category() -> StringName:
	return &"events"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if weight < 0 or min_floor < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "weight >= 0, min_floor >= 1"))
	if not REQUIRES.has(requires):
		issues.append(
			ValidationIssue.new(&"unknown", resource_path, "unknown requires %s" % requires)
		)
	if choices.is_empty() or choices.size() > MAX_CHOICES:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "1..%d choices (Leave is added)" % MAX_CHOICES
			)
		)
	for c in choices:
		if c == null:
			issues.append(ValidationIssue.new(&"missing", resource_path, "an empty choice"))
		else:
			c.validate_into(issues, resource_path)
	return issues
