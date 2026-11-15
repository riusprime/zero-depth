class_name LatticeRules
extends RefCounted
## The content rules of a boss's lattice (BossDefinition.lattice: the Hive Lens fed by its drones, its Focus Beam
## cutting them, the burnt glass its beam leaves and the Lattice of light it weaves through them; its own file, as the
## forge's rules). Every key is known and within its bounds, so no single step of these mechanics takes more than
## MAX_HIT per mille of the hero's max HP; the Lattice's cast lasts the telegraph minimum and one Lattice ends before
## the next is due; the attacks named exist (the split is a deploy or brood attack with drones, so the drones that
## feed the boss are its kind).

## The most one step may take, per mille of the hero's max HP: never a kill from full HP by one mistake.
const MAX_HIT := 400
## key: [default, min, max]. Starting values (the lead's brief: 15 % less damage per living drone, at most 45 %; the
## drones sent again 12 s after the last one dies; a strip 8 m long and 1 m wide for 6 s, 6 damage a half second, at
## most 3; the Lattice 10 s into a phase and every 45 s, a 2 s cast, 10 s of strands 0.6 m wide that take 20 % at
## most twice a second, turning at 20 degrees a second 6..12 m out; 3 s of calm round the Gaze). A phase index past
## the boss's last phase means never.
const SPEC := {
	"feed_phase": [1, 0, 9],
	"feed_cut_permille": [150, 0, 500],
	"feed_cap_permille": [450, 0, 900],
	"resend_seconds": [12.0, 1.0, 120.0],
	"strip_phase": [2, 0, 9],
	"strip_length_m": [8.0, 0.5, 30.0],
	"strip_width_m": [1.0, 0.1, 5.0],
	"strip_seconds": [6.0, 0.5, 60.0],
	"strip_damage": [6, 1, 1000],
	"strip_tick_seconds": [0.5, 0.1, 5.0],
	"strip_max": [3, 1, 16],
	"lattice_phase": [1, 0, 9],
	"lattice_first_seconds": [10.0, 0.0, 120.0],
	"lattice_every_seconds": [45.0, 5.0, 300.0],
	"lattice_cast_seconds": [2.0, 0.4, 10.0],
	"lattice_seconds": [10.0, 1.0, 60.0],
	"lattice_min_drones": [2, 1, 8],
	"strand_width_m": [0.6, 0.1, 3.0],
	"strand_hit_permille": [200, 1, 1000],
	"strand_lockout_seconds": [0.5, 0.1, 5.0],
	"orbit_dps": [20.0, 0.0, 180.0],
	"orbit_min_m": [6.0, 1.0, 30.0],
	"orbit_max_m": [12.0, 1.0, 30.0],
	"calm_seconds": [3.0, 0.0, 30.0],
}
## The keys that name one of the boss's attacks: the split that sends the drones, and the attacks the death recap
## names for a strand and for the burnt glass.
const ATTACK_KEYS := ["split_attack", "strand_cause", "strip_cause"]
## The keys that list the boss's attacks: its Focus Beams (they cut drones and leave the glass) and the attacks it
## holds back while a Lattice is cast or runs.
const LIST_KEYS := ["beam_attacks", "lattice_holds"]


## The lattice dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(lattice: Dictionary, key: String) -> float:
	return float(lattice.get(key, (SPEC[key] as Array)[0]))


## BossDefinition.validate: nothing to check without a lattice.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var f := def.lattice
	if f.is_empty():
		return
	var p := def.resource_path
	for k: Variant in f:
		if ATTACK_KEYS.has(k) or LIST_KEYS.has(k):
			_check_attacks(def, k, f[k], issues)
			continue
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "lattice: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(f[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "lattice.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	for k: String in ATTACK_KEYS + LIST_KEYS:
		if not f.has(k):
			issues.append(ValidationIssue.new(&"missing", p, "lattice.%s is required" % k))
	var split := def.attack(StringName(str(f.get("split_attack", ""))))
	if (
		split != null
		and (
			(split.move != &"deploy" and split.move != &"brood")
			or str(split.shape_params.get("enemy_id", "")) == ""
		)
	):
		issues.append(ValidationIssue.new(&"attacks", p, "lattice.split_attack must send drones"))
	if int(round(value(f, "lattice_cast_seconds") * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short", p, "lattice.lattice_cast_seconds is under the minimum"
			)
		)
	var one := (
		value(f, "lattice_cast_seconds") + value(f, "lattice_seconds") + value(f, "calm_seconds")
	)
	if value(f, "lattice_every_seconds") <= one:
		issues.append(
			ValidationIssue.new(
				&"duration", p, "lattice.lattice_every_seconds must exceed a Lattice and its calm"
			)
		)
	if value(f, "orbit_min_m") > value(f, "orbit_max_m"):
		issues.append(
			ValidationIssue.new(&"range", p, "lattice.orbit_min_m must not exceed orbit_max_m")
		)
	if value(f, "strand_hit_permille") > MAX_HIT:
		issues.append(
			ValidationIssue.new(
				&"range", p, "lattice.strand_hit_permille: at most %d per mille" % MAX_HIT
			)
		)


## The attack ids key `k` names exist (a list for LIST_KEYS, one id for ATTACK_KEYS).
static func _check_attacks(
	def: BossDefinition, k: String, v: Variant, issues: Array[ValidationIssue]
) -> void:
	var p := def.resource_path
	var ids: Array = []
	if LIST_KEYS.has(k):
		if not (v is Array or v is PackedStringArray):
			issues.append(ValidationIssue.new(&"type", p, "lattice.%s: a list of attacks" % k))
			return
		ids = Array(v)
	else:
		ids = [v]
	for id: Variant in ids:
		if def.attack(StringName(str(id))) == null:
			issues.append(ValidationIssue.new(&"attacks", p, "lattice.%s: no attack %s" % [k, id]))
