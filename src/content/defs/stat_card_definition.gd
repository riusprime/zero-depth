class_name StatCardDefinition
extends ContentDef
## A stat card (v0.4.0 BS, owner F9; CONTENT_SCHEMA §8): one stat in three rarities. Every reward that isn't an
## ability or a mod is one of these. Amounts are percent (or points for crit chance and crit damage, percent of
## max HP per second for regen), compiled to per mille. Cards stack multiplicatively (two +10 % = x1.21); `cap` is
## the most (or for a cut, the least) the stat may reach, as a multiplier or a total in points (0 = none).

## The stats in the sim's order (Stats.Stat mirrors it). Appended, never renumbered.
const STATS: Array[StringName] = [
	&"max_hp",
	&"damage",
	&"crit_chance",
	&"crit_damage",
	&"attack_speed",
	&"area",
	&"cooldowns",
	&"move_speed",
	&"regen",
	&"shard_gain",
	&"pickup_range",
	&"armour",
]
const RARITIES := 3

## One of STATS.
@export var stat: StringName = &"damage"
@export var name_key: StringName
## A sentence with one %s for the amount (e.g. "+%s%% damage").
@export var desc_key: StringName
## Common, rare, epic.
@export var amounts := PackedFloat32Array([8.0, 15.0, 25.0])
@export var cap := 0.0
## Draw weight against the other stat cards.
@export var weight := 10


func category() -> StringName:
	return &"stat_card"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if not STATS.has(stat):
		issues.append(ValidationIssue.new(&"unknown", resource_path, "unknown stat %s" % stat))
	if amounts.size() != RARITIES:
		issues.append(ValidationIssue.new(&"range", resource_path, "amounts needs 3 entries"))
	else:
		for k in RARITIES:
			if amounts[k] <= 0.0 or (k > 0 and amounts[k] < amounts[k - 1]):
				issues.append(
					ValidationIssue.new(
						&"range", resource_path, "amounts are positive and rise with rarity"
					)
				)
				break
	if cap < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "cap is negative"))
	if weight < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "weight is negative"))
	return issues
