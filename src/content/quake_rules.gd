class_name QuakeRules
extends RefCounted
## v0.11.0 O3 (owner L5, Q9 a; BossQuake): the content rules of a boss's quake pillars (BossDefinition.quake, its own
## file: the boss definitions stay small). Every key is known and within its bounds; the ring's warning lasts the
## telegraph minimum and fits in its pulse; the pillars start in a phase the boss has; a recap line is named.

## key: [default, min, max]. Starting values (owner Q9 a: 3 pillars from phase 2, a pulse every 3 s of about 3 % of
## the player's HP, a break stuns 2 s at +50 % damage taken, at most twice per phase).
const SPEC := {
	"count": [3, 1, 4],
	"from_phase": [1, 1, 4],
	"pillar_m": [1.2, 0.6, 2.0],
	"pulse_seconds": [3.0, 1.0, 8.0],
	"warn_seconds": [0.8, 0.4, 2.0],
	"ring_m": [2.6, 1.0, 10.0],
	"damage_permille": [30, 5, 100],
	"stun_seconds": [2.0, 0.5, 5.0],
	"stun_permille": [1500, 1000, 3000],
	"stuns_per_phase": [2, 0, 5],
	"gap_m": [5.0, 2.0, 12.0],
	"wall_m": [1.5, 0.5, 6.0],
	"boss_m": [2.0, 0.0, 6.0],
}


## The quake dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(quake: Dictionary, key: String) -> float:
	return float(quake.get(key, (SPEC[key] as Array)[0]))


## BossDefinition.validate: nothing to check without pillars.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var q := def.quake
	if q.is_empty():
		return
	var p := def.resource_path
	for k: Variant in q:
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "quake: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(q[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "quake.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	var warn := int(round(value(q, "warn_seconds") * 60.0))
	var pulse := int(round(value(q, "pulse_seconds") * 60.0))
	if warn < BehaviourSchemas.MIN_TELEGRAPH_TICKS or warn >= pulse:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				p,
				"quake: the ring's warning must last the telegraph minimum and fit in its pulse"
			)
		)
	if int(value(q, "from_phase")) >= def.phases.size():
		issues.append(ValidationIssue.new(&"range", p, "quake.from_phase is not a phase"))
	if String(def.quake_cause_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "quake needs quake_cause_key"))
