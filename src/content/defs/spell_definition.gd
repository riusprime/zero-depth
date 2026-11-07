class_name SpellDefinition
extends ContentDef
## v0.11.0 O10 (owner Q17-Q20; docs/roadmap/v0.11.0/SPELLS.md, approved row by row; PLAN E1-E5; CONTENT_SCHEMA §8): an
## elemental spell, the card family that sits in the 4 spell slots beside the wand and casts by itself on its own
## cooldown (Spells). Holding its element's card (`element_card`, an item id) puts it in the run's offers; the run's
## rune affinity `affinity` (a wardrobe affinity id, or empty) raises its offer weight (SpellRulesDefinition). Taking it
## again levels it (Lv 1-3, Lv 4-5 from loop 2). The id names the spell and its rule (Spells, one per id in SPELLS
## order). Per-level lists hold 5 entries, Lv 1 first:
## - spell_frost_nova (F2): `damage` and a freeze of `seconds` to every enemy within `radius_m` of you, each pushed
##   `push_m` away;
## - spell_fireball (B1): `count` balls fly at `speed_mps` at the densest pack within `reach_m` and burst `radius_m`,
##   `damage` and the element's status to each enemy caught;
## - spell_sky_strike (L1): `count` bolts strike random enemies within `reach_m`, `damage` and the status each, and each
##   jumps to the nearest other enemy within `jump_m` of the one it struck.
## The other ids (SPELLS.md's other twelve rows) are reserved for O11: their definitions may not ship yet.

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
## The spells with a runner (O10); the rest are rejected until their rule ships.
const RUNNING: Array[StringName] = [&"spell_frost_nova", &"spell_fireball", &"spell_sky_strike"]
## The five elements a spell can belong to (Spells.ELEMENT_* order).
const ELEMENTS: Array[StringName] = [&"frost", &"fire", &"lightning", &"venom", &"bleed"]
const LEVELS := 5

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
## Per level: the burst's or the nova's radius (m).
@export var radius_m := PackedFloat32Array()
## Per level: Frost Nova's freeze (s); empty for the others.
@export var seconds := PackedFloat32Array()
## Per level: Fireball's balls, Sky Strike's bolts; empty for the others.
@export var count := PackedInt32Array()
## Frost Nova's push (m); 0 for the others.
@export var push_m := 0.0
## Sky Strike's jump reach (m); 0 for the others.
@export var jump_m := 0.0
## Fireball's flight speed (m/s); 0 for the others.
@export var speed_mps := 0.0
## The element's status stacks each hit applies (the element card's own per hit: 1).
@export var stacks := 1


func category() -> StringName:
	return &"spells"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not RUNNING.has(id):
		issues.append(
			ValidationIssue.new(&"unknown", resource_path, "unknown or unbuilt spell %s" % id)
		)
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
	_levels(issues, "damage", damage.size(), damage.size() == LEVELS)
	for v in damage:
		if v <= 0:
			issues.append(ValidationIssue.new(&"not_positive", resource_path, "damage must be > 0"))
	_levels(issues, "radius_m", radius_m.size(), radius_m.size() == LEVELS)
	for v in radius_m:
		check_positive(issues, "radius_m", v)
	match id:
		&"spell_frost_nova":
			_levels(issues, "seconds", seconds.size(), seconds.size() == LEVELS)
			for v in seconds:
				check_positive(issues, "seconds", v)
				check_duration(issues, "seconds", v)
			check_positive(issues, "push_m", push_m)
		&"spell_fireball":
			_counts(issues)
			check_positive(issues, "speed_mps", speed_mps)
		&"spell_sky_strike":
			_counts(issues)
			check_positive(issues, "jump_m", jump_m)
	return issues


func _counts(issues: Array[ValidationIssue]) -> void:
	_levels(issues, "count", count.size(), count.size() == LEVELS)
	for v in count:
		if v <= 0:
			issues.append(ValidationIssue.new(&"not_positive", resource_path, "count must be > 0"))


func _levels(issues: Array[ValidationIssue], field: String, n: int, ok: bool) -> void:
	if not ok:
		issues.append(
			ValidationIssue.new(&"size", resource_path, "%s needs 5 entries (has %d)" % [field, n])
		)
