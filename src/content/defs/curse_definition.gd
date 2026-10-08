class_name CurseDefinition
extends ContentDef
## A curse (v0.5.0 EV, PLAN R4; CONTENT_SCHEMA §9): a lasting drawback that comes with a strong reward (a cursed
## chest card, some event choices). It lasts the run unless cleansed, and each one raises threat T (PD-05) by
## `threat`. `amount` is in percent, or a count for extra_enemy.

## The effects the sim knows (Curses.Effect mirrors the order; appended, never renumbered):
## enemy_speed (+amount % normal enemies' move speed), regen (-amount % regen), heat_decay (Overclock heat decays
## +amount % faster), extra_enemy (+amount enemies in every spawn arrival, under the alive cap), prices (+amount %
## shard prices: chests, the gamble shrine, shops), elite_chance (+amount % chance that a spawned enemy is elite).
const EFFECTS: Array[StringName] = [
	&"enemy_speed", &"regen", &"heat_decay", &"extra_enemy", &"prices", &"elite_chance"
]

@export var name_key: StringName
## A sentence with one %s for the amount.
@export var desc_key: StringName
@export var effect: StringName = &"enemy_speed"
@export var amount := 15.0
@export var threat := 1
## Draw weight when a curse is rolled.
@export var weight := 10


func category() -> StringName:
	return &"curses"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if not EFFECTS.has(effect):
		issues.append(ValidationIssue.new(&"unknown", resource_path, "unknown effect %s" % effect))
	check_positive(issues, "amount", amount)
	if effect == &"regen" and amount > 100.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "regen cut is at most 100 %"))
	if threat < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "a curse raises threat by >= 1"))
	if weight < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "weight is negative"))
	return issues
