class_name HazardRules
extends RefCounted
## The content rules of a boss's arena hazards (BossDefinition.hazard, its own file:
## the boss definitions stay small). Every key is known and within its bounds; the warning lasts the telegraph minimum;
## the kind's numbers agree; the attacks that leave one exist; a hazard that hurts names a recap line. The cover bound
## (at most 30 % of the arena) is the strict cap's own: it leaves most of the floor safe.

## key: [default, min, max]. Starting values.
const SPEC := {
	"radius_m": [2.0, 0.5, 4.0],
	"life_seconds": [20.0, 1.0, 60.0],
	"warn_seconds": [0.8, 0.4, 3.0],
	"max_count": [6, 1, 12],
	"max_cover_permille": [250, 50, 300],
	"damage": [0, 0, 50],
	"burn_seconds": [0.5, 0.1, 2.0],
	"slow_permille": [1000, 300, 1000],
	"impact_damage": [0, 0, 100],
	"per_attack": [1, 1, 4],
}
const KINDS := ["damage", "slow"]
const LOOKS := ["lava", "venom", "rock"]
const TEXT_KEYS := ["kind", "look", "attack_ids"]


## The hazard dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(hazard: Dictionary, key: String) -> float:
	return float(hazard.get(key, (SPEC[key] as Array)[0]))


## BossDefinition.validate: nothing to check without hazards.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var h := def.hazard
	if h.is_empty():
		return
	var p := def.resource_path
	for k: Variant in h:
		if TEXT_KEYS.has(k):
			continue
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "hazard: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(h[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "hazard.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	if int(round(value(h, "warn_seconds") * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short", p, "hazard: its warning must last the telegraph minimum"
			)
		)
	_check_text(def, issues)
	_check_kind(def, issues)


static func _check_text(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var h := def.hazard
	var p := def.resource_path
	if not KINDS.has(String(h.get("kind", ""))):
		issues.append(ValidationIssue.new(&"range", p, "hazard.kind: %s" % ", ".join(KINDS)))
	if not LOOKS.has(String(h.get("look", ""))):
		issues.append(ValidationIssue.new(&"range", p, "hazard.look: %s" % ", ".join(LOOKS)))
	var ids: Array = h.get("attack_ids", [])
	if ids.is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "hazard needs attack_ids"))
	for id: Variant in ids:
		var known := false
		for a in def.attacks:
			known = known or (a != null and String(a.id) == String(id))
		if not known:
			issues.append(ValidationIssue.new(&"missing", p, "hazard: no attack %s" % id))


static func _check_kind(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var h := def.hazard
	var p := def.resource_path
	var hurts := value(h, "damage") > 0.0
	var drags := value(h, "slow_permille") < 1000.0
	if String(h.get("kind", "")) == "damage" and not hurts:
		issues.append(ValidationIssue.new(&"range", p, "hazard: a damage kind needs its damage"))
	if String(h.get("kind", "")) == "slow" and (hurts or not drags):
		issues.append(
			ValidationIssue.new(&"range", p, "hazard: a slow kind drags and does not burn")
		)
	if (hurts or value(h, "impact_damage") > 0.0) and String(def.hazard_cause_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "hazard needs hazard_cause_key"))
