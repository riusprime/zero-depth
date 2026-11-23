class_name WarlordRules
extends RefCounted
## The content rules of the Warlord's own mechanics (BossDefinition.warlord: the War Banner of its second phase and
## the Duel of its last; its own file, as the forge's rules). Every key is known and within its bounds, so no single
## hit of these mechanics takes more than MAX_HIT per mille of the hero's max HP; each cast and the recall's warning
## last the telegraph minimum; the banner and the duel never share a phase (one big mechanic at a time); the cage
## only closes and its centre zone is smaller than its last ring; the attacks it names are the boss's own.

## The most one hit may take, per mille of the hero's max HP: never a kill from full HP by one mistake.
const MAX_HIT := 400
## key: [default, min, max]. Starting values (the lead's brief: a 6 m banner for 20 s, the Warlord's cooldowns ×0.7
## and the hero's damage ×1.4 inside it; a 9 m cage closing to 5 m over 12 s, 10 % a fence touch, 40 % for the recall
## through its 2.5 m centre). A phase index past the boss's last phase means never.
const SPEC := {
	"banner_phase": [1, 0, 9],
	"banner_first_seconds": [8.0, 0.0, 120.0],
	"banner_gap_seconds": [12.0, 0.0, 120.0],
	"banner_cast_seconds": [1.0, 0.4, 10.0],
	"banner_radius_m": [6.0, 1.0, 20.0],
	"banner_seconds": [20.0, 1.0, 120.0],
	"banner_cooldown_permille": [700, 100, 1000],
	"banner_damage_permille": [1400, 1000, 3000],
	"banner_pole_m": [0.8, 0.0, 5.0],
	"duel_phase": [2, 0, 9],
	"duel_first_seconds": [8.0, 0.0, 120.0],
	"duel_gap_seconds": [25.0, 0.0, 120.0],
	"duel_cast_seconds": [1.2, 0.4, 10.0],
	"duel_radius_m": [9.0, 3.0, 30.0],
	"duel_end_radius_m": [5.0, 2.0, 30.0],
	"duel_seconds": [12.0, 1.0, 60.0],
	"fence_touch_m": [0.3, 0.0, 2.0],
	"fence_permille": [100, 1, 400],
	"fence_every_seconds": [0.6, 0.1, 10.0],
	"recall_warn_seconds": [1.0, 0.4, 10.0],
	"recall_radius_m": [2.5, 0.5, 20.0],
	"recall_permille": [400, 1, 400],
}
## The keys that name one of the boss's attacks (the death recap's line): the fence's (its own cause line) and the
## recall's (that attack's late part, its late_cause_key).
const CAUSE_KEYS := ["fence_cause", "recall_cause"]
## The key that lists the attacks the Warlord may start inside the cage (ids of its own attacks).
const DUEL_ATTACKS := "duel_attacks"


## The warlord dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(d: Dictionary, key: String) -> float:
	return float(d.get(key, (SPEC[key] as Array)[0]))


## BossDefinition.validate: nothing to check without the Warlord's mechanics.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var d := def.warlord
	if d.is_empty():
		return
	var p := def.resource_path
	for k: Variant in d:
		if CAUSE_KEYS.has(k):
			if def.attack(StringName(str(d[k]))) == null:
				issues.append(ValidationIssue.new(&"attacks", p, "warlord.%s: no such attack" % k))
			continue
		if k == DUEL_ATTACKS:
			_check_duel_attacks(def, d[k], issues)
			continue
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "warlord: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(d[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "warlord.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	for k: String in CAUSE_KEYS + [DUEL_ATTACKS]:
		if not d.has(k):
			issues.append(ValidationIssue.new(&"missing", p, "warlord.%s is required" % k))
	for k: String in ["banner_cast_seconds", "duel_cast_seconds", "recall_warn_seconds"]:
		if int(round(value(d, k) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(&"telegraph_short", p, "warlord.%s is under the minimum" % k)
			)
	if int(value(d, "banner_phase")) == int(value(d, "duel_phase")):
		issues.append(
			ValidationIssue.new(&"range", p, "warlord: the banner and the duel share no phase")
		)
	if value(d, "duel_end_radius_m") > value(d, "duel_radius_m"):
		issues.append(ValidationIssue.new(&"range", p, "warlord.duel_end_radius_m: <= the start"))
	if value(d, "recall_radius_m") + value(d, "fence_touch_m") >= value(d, "duel_end_radius_m"):
		issues.append(
			ValidationIssue.new(
				&"range", p, "warlord.recall_radius_m: room between it and the last fence"
			)
		)


static func _check_duel_attacks(
	def: BossDefinition, ids: Variant, issues: Array[ValidationIssue]
) -> void:
	var p := def.resource_path
	if not ids is Array or (ids as Array).is_empty():
		issues.append(ValidationIssue.new(&"range", p, "warlord.duel_attacks: a list of ids"))
		return
	for id: Variant in ids:
		var atk := def.attack(StringName(str(id)))
		if atk == null:
			issues.append(ValidationIssue.new(&"attacks", p, "warlord.duel_attacks: no %s" % id))
		elif atk.move == &"great_javelin":
			issues.append(
				ValidationIssue.new(&"attacks", p, "warlord.duel_attacks: no great javelin")
			)
