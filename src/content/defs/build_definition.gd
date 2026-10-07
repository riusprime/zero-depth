class_name BuildDefinition
extends ContentDef
## A starting build (v0.3.0 PLAN L15, L16; CONTENT_SCHEMA §8): the one weapon a run uses, chosen on the start
## screen before the run. The other weapon's input does nothing in that run, and items that only feed the other
## weapon are never offered (ItemDefinition.requires_weapon). `damage_permille` scales that weapon's damage
## (L16: Blade +15 %, Gun -15 %; starting values).

## Appended, never renumbered. The ids an item's requires_weapon may name are WEAPON_IDS (same order).
enum Weapon { BLADE, GUN }

const WEAPON_IDS: Array[StringName] = [&"blade", &"gun"]
const MIN_DAMAGE_PERMILLE := 100
const MAX_DAMAGE_PERMILLE := 5000

@export var weapon := Weapon.BLADE
@export var name_key: StringName
@export var desc_key: StringName
## The enabled weapon's damage x damage_permille / 1000 (the sim carries the remainder, so the average is exact).
@export var damage_permille := 1000
## The build's second ability on the Skill button (v0.3.5 K, owner F18): one per build, of its weapon's kind.
@export var skill: SkillDefinition


func category() -> StringName:
	return &"build"


func weapon_id() -> StringName:
	return WEAPON_IDS[clampi(weapon, 0, WEAPON_IDS.size() - 1)]


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if weapon < Weapon.BLADE or weapon > Weapon.GUN:
		issues.append(ValidationIssue.new(&"range", resource_path, "weapon is blade or gun"))
	if damage_permille < MIN_DAMAGE_PERMILLE or damage_permille > MAX_DAMAGE_PERMILLE:
		issues.append(
			ValidationIssue.new(
				&"range",
				resource_path,
				"damage_permille is %d..%d" % [MIN_DAMAGE_PERMILLE, MAX_DAMAGE_PERMILLE]
			)
		)
	if skill == null:
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "skill is required (v0.3.5 K)")
		)
	else:
		issues.append_array(skill.validate(resource_path))
		if SkillDefinition.WEAPON_OF.get(skill.kind, -1) != weapon:
			issues.append(
				ValidationIssue.new(
					&"mismatch", resource_path, "skill.kind belongs to the other weapon"
				)
			)
	return issues
