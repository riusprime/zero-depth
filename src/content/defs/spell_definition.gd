class_name SpellDefinition
extends ContentDef
## An
## elemental spell, the card family that sits in the 4 spell slots beside the wand and casts by itself on its own
## cooldown (Spells). Holding its element's card (`element_card`, an item id) puts it in the run's offers; the run's
## rune affinity `affinity` (a wardrobe affinity id, or empty) raises its offer weight (SpellRulesDefinition). Taking it
## again levels it (Lv 1-3, Lv 4-5 from loop 2). The id names the spell and its rule (Spells, one per id in SPELLS
## order). Per-level lists hold 5 entries, Lv 1 first. all fifteen rows; what each field means for each
## spell is SIM_CONTRACTS §8p's (`seconds` is how long it lasts, Frost Nova's freeze; `count` its balls, bolts,
## shards, zap targets, heads or marks; `period_s` its pulse; the `bonus_*` fields its Lv 5 extra).

## The spells in the sim's order (Spells' indices; SPELLS.md's rows F1-F3, B1-B3, L1-L3, V1-V3, X1-X3). Appended,
## never renumbered.
const SPELLS: Array[StringName] = [
	&"spell_blizzard",
	&"spell_frost_nova",
	&"spell_ice_lances",
	&"spell_fireball",
	&"spell_burning_ground",
	&"spell_meteor",
	&"spell_sky_strike",
	&"spell_ball_lightning",
	&"spell_static_field",
	&"spell_venom_orb",
	&"spell_toxic_cloud",
	&"spell_spitter_vine",
	&"spell_blood_thorns",
	&"spell_hemorrhage",
	&"spell_leech",
]
## The five elements a spell can belong to (Spells.ELEMENT_* order).
const ELEMENTS: Array[StringName] = [&"frost", &"fire", &"lightning", &"venom", &"bleed"]
const LEVELS := 5
## Per spell, the fields it needs beyond damage and radius_m ("seconds", "count" and "heal_cap" per level, the rest
## single numbers > 0).
const NEEDS := {
	&"spell_blizzard": ["seconds", "period_s", "bonus_seconds"],
	&"spell_frost_nova": ["seconds", "push_m", "bonus_damage"],
	&"spell_ice_lances": ["count", "pierce", "jump_m"],
	&"spell_fireball": ["count", "speed_mps", "bonus_damage", "bonus_seconds", "bonus_radius_m"],
	&"spell_burning_ground": ["seconds", "period_s", "speed_mps"],
	&"spell_meteor":
	["seconds", "delay_s", "bonus_damage", "bonus_seconds", "bonus_radius_m", "period_s"],
	&"spell_sky_strike": ["count", "jump_m", "bonus_seconds"],
	&"spell_ball_lightning":
	["seconds", "count", "period_s", "speed_mps", "bonus_damage", "bonus_radius_m"],
	&"spell_static_field": ["seconds", "period_s", "bonus_damage", "bonus_radius_m"],
	&"spell_venom_orb": ["seconds", "period_s", "bonus_seconds", "bonus_radius_m", "speed_mps"],
	&"spell_toxic_cloud": ["seconds", "period_s", "bonus_seconds", "slow_permille"],
	&"spell_spitter_vine": ["seconds", "count", "period_s", "pierce"],
	&"spell_blood_thorns": ["inner_m", "delay_s", "bonus_damage", "bonus_seconds", "period_s"],
	&"spell_hemorrhage": ["count", "delay_s"],
	&"spell_leech": ["seconds", "period_s", "heal_cap", "heal_per_damage"],
}

@export var name_key: StringName
@export var desc_key: StringName
## What each level adds, Lv 1 first (5 keys; the pick card's level line).
@export var level_keys: Array[StringName] = []
@export var element: StringName
## The element card (an item id) whose holding puts this spell in the offers.
@export var element_card: StringName
## The wardrobe rune affinity (its id) that raises this spell's offer weight; empty: none.
@export var affinity: StringName
## Draw weight against the other spells in the run's pool.
@export var weight := 10
@export var cooldown_s := 12.0
## How far from you it looks for its targets (m).
@export var reach_m := 10.0
## Per level: each hit's damage (before the damage stat and crit).
@export var damage := PackedInt32Array()
## Per level: its area's radius (m): the burst, the nova, the storm, the patch, the zap reach, the spread.
@export var radius_m := PackedFloat32Array()
## Per level: how long it lasts (s); Frost Nova's freeze. Empty when it is instant.
@export var seconds := PackedFloat32Array()
## Per level: its balls, bolts, shards, zap targets, heads or marks; empty for the others.
@export var count := PackedInt32Array()
## Frost Nova's push (m); 0 for the others.
@export var push_m := 0.0
## Sky Strike's jump reach, Ice Lances' split reach (m); 0 for the others.
@export var jump_m := 0.0
## Fireball's and Venom Orb's flight, Ball Lightning's roll, Burning Ground's Lv 5 follow (m/s); 0 for the others.
@export var speed_mps := 0.0
## The element's status stacks each hit applies (the element card's own per hit: 1).
@export var stacks := 1
## A lasting spell's pulse (s): it hits what stands in it this often.
@export var period_s := 0.0
## Meteor's mark, Hemorrhage's wait, Blood Thorns' second ring's beat (s).
@export var delay_s := 0.0
## Blood Thorns' ring starts this far from you (m).
@export var inner_m := 0.0
## The extra enemies a shard (Ice Lances) or a Lv 5 spit (Spitter Vine) passes through.
@export var pierce := 0
## The Lv 5 extra's damage a hit or a pulse (shatter, burning ground, burst, discharge, wall).
@export var bonus_damage := 0
## The Lv 5 extra's length (s): a freeze, a stun, a burning ground, a small pool, a wall.
@export var bonus_seconds := 0.0
## The Lv 5 extra's radius (m).
@export var bonus_radius_m := 0.0
## O11 Leech: per level, the most HP one cast heals.
@export var heal_cap := PackedInt32Array()
## O11 Leech: the damage drained for each 1 HP healed.
@export var heal_per_damage := 0
## O11 Toxic Cloud's Lv 5 slow: the speed left (per mille).
@export var slow_permille := 0


func category() -> StringName:
	return &"spells"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not SPELLS.has(id):
		issues.append(ValidationIssue.new(&"unknown", resource_path, "unknown spell %s" % id))
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if level_keys.size() != LEVELS:
		issues.append(ValidationIssue.new(&"size", resource_path, "level_keys needs 5 keys"))
	if not ELEMENTS.has(element):
		issues.append(
			ValidationIssue.new(&"unknown", resource_path, "element is one of %s" % [ELEMENTS])
		)
	if String(element_card).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "element_card is required"))
	if weight <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "weight must be > 0"))
	check_positive(issues, "cooldown_s", cooldown_s)
	check_duration(issues, "cooldown_s", cooldown_s)
	check_positive(issues, "reach_m", reach_m)
	if stacks < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "stacks is negative"))
	_levels(issues, "damage", damage.size())
	for v in damage:
		if v <= 0:
			issues.append(ValidationIssue.new(&"not_positive", resource_path, "damage must be > 0"))
	_levels(issues, "radius_m", radius_m.size())
	for v in radius_m:
		check_positive(issues, "radius_m", v)
	for f: String in NEEDS.get(id, []):
		_need(issues, f)
	return issues


func _need(issues: Array[ValidationIssue], field: String) -> void:
	match field:
		"seconds":
			_levels(issues, field, seconds.size())
			for v in seconds:
				check_positive(issues, field, v)
				check_duration(issues, field, v)
		"count", "heal_cap":
			var list: PackedInt32Array = get(field)
			_levels(issues, field, list.size())
			for v in list:
				if v <= 0:
					issues.append(
						ValidationIssue.new(
							&"not_positive", resource_path, "%s must be > 0" % field
						)
					)
		"period_s", "delay_s", "bonus_seconds":
			var v: float = get(field)
			check_positive(issues, field, v)
			check_duration(issues, field, v)
		_:
			check_positive(issues, field, float(get(field)))


func _levels(issues: Array[ValidationIssue], field: String, n: int) -> void:
	if n != LEVELS:
		issues.append(
			ValidationIssue.new(&"size", resource_path, "%s needs 5 entries (has %d)" % [field, n])
		)
