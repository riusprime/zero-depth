class_name GreatJavelinRules
extends RefCounted
## The content rules of a `great_javelin` attack (its own file:
## BossAttackDefinition stays small). Its numbers sit inside the quake pillars' own bounds (QuakeRules.SPEC: a pulse
## is at most 100 per mille of the hero's max HP, its ring at most 5 m), every warning lasts at least the telegraph
## minimum and the ring's fits in its pulse; a thrown one embeds at least one pulse long; its way back names a recap
## line.

## shape_params key -> [min, max] (the same bounds as QuakeRules.SPEC for the ring and the pulse).
const BOUNDS := {
	"embed_seconds": [1.0, 12.0],
	"pulse_seconds": [1.0, 8.0],
	"warn_seconds": [0.4, 2.0],
	"ring_m": [1.0, 5.0],
	"pulse_permille": [5, 100],
	"recall_warn_seconds": [0.4, 2.0],
}


static func validate(
	def: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	if def.move != &"great_javelin":
		return
	var sp := def.shape_params
	for k: String in BOUNDS:
		var v := float(sp.get(k, 0.0))
		var spec: Array = BOUNDS[k]
		if v < float(spec[0]) or v > float(spec[1]):
			issues.append(
				ValidationIssue.new(&"range", path, where + "%s: %s..%s" % [k, spec[0], spec[1]])
			)
	for k in ["speed_mps", "radius_m", "range_m", "recall_speed_mps"]:
		if float(sp.get(k, 0.0)) <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "%s must be > 0" % k))
	var warn := int(round(float(sp.get("warn_seconds", 0.0)) * 60.0))
	var pulse := int(round(float(sp.get("pulse_seconds", 0.0)) * 60.0))
	var recall := int(round(float(sp.get("recall_warn_seconds", 0.0)) * 60.0))
	var embed := int(round(float(sp.get("embed_seconds", 0.0)) * 60.0))
	if warn < BehaviourSchemas.MIN_TELEGRAPH_TICKS or warn >= pulse:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				path,
				where + "the ring's warning: the minimum, inside its pulse"
			)
		)
	if recall < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				path,
				where + "recall_warn_seconds is under the telegraph minimum"
			)
		)
	if embed < pulse:
		issues.append(ValidationIssue.new(&"range", path, where + "it embeds at least one pulse"))
	if String(def.late_cause_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, where + "late_cause_key is required"))
