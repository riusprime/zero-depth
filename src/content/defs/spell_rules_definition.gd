class_name SpellRulesDefinition
extends ContentDef
## The
## rules every spell follows (one definition, id spell_rules). Starting values; O12 measures them.

## The spell slots, separate from the wand.
@export var slots := 4
## The chance per mille that a regular altar's offer holds a spell card while the run's pool has one.
@export var offer_permille := 350
## A spell whose `affinity` is the run's rune affinity weighs this much per mille.
@export var affinity_permille := 2000
## The highest spell level in loop 1 (Lv 4-5 from loop 2, Q18).
@export var loop1_max_level := 3
## "The densest pack": the circle (this radius, m) holding the most enemies within a spell's reach.
@export var pack_radius_m := 3.0


func category() -> StringName:
	return &"spell_rules"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if slots < 1 or slots > 8:
		issues.append(ValidationIssue.new(&"range", resource_path, "slots is 1..8"))
	if offer_permille < 0 or offer_permille > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "offer_permille is 0..1000"))
	if affinity_permille < 1000 or affinity_permille > 10000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "affinity_permille is 1000..10000")
		)
	if loop1_max_level < 1 or loop1_max_level > SpellDefinition.LEVELS:
		issues.append(ValidationIssue.new(&"range", resource_path, "loop1_max_level is 1..5"))
	check_positive(issues, "pack_radius_m", pack_radius_m)
	return issues
