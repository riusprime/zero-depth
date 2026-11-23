class_name DanceRules
extends RefCounted
## The content rules of a boss's dance (BossDefinition.dance: the Tidecaller's stronger Pull, Riptide, High Tide and
## the Maelstrom; its own file, as the time mechanics' rules). Every key is known and within its bounds, so no single
## hit takes more than MAX_HIT per mille of the hero's max HP; each cast's warning lasts the telegraph minimum; the
## stream and the attacks resume before the calm between two big mechanics is over; the boss holds a `tide` and a
## `wave` attack (the death recap names them).

## The most one hit of the dance may take, per mille of the hero's max HP: never a kill from full HP by one mistake.
const MAX_HIT := 400
## The casts a row of Riptide may hold: the written order's length.
const MAX_CASTS := 4
## The phases whose rhythm the data sets (beat_*_seconds, beat_*_2_seconds, beat_*_3_seconds); a later phase plays the
## last one's.
const BEAT_PHASES := 3
## key: [default, min, max]. Starting values (the owner's brief: three strips of four at 35 %, a dry circle 12 m away
## with 6 % a second outside it; one big mechanic at a time with calm between; the rest the lead's). A phase index
## past the boss's last phase means never.
const SPEC := {
	"pull_permille": [750, 0, 950],
	"pull_late_permille": [850, 0, 950],
	"pull_late_phase": [2, 0, 9],
	"push_m": [4.0, 0.0, 12.0],
	"push_clear_m": [3.0, 0.0, 6.0],
	"calm_seconds": [3.0, 0.5, 30.0],
	"resume_seconds": [1.5, 0.0, 30.0],
	"beat_first_seconds": [6.0, 0.5, 120.0],
	"beat_gap_seconds": [12.0, 0.0, 120.0],
	"beat_first_2_seconds": [6.0, 0.5, 120.0],
	"beat_gap_2_seconds": [8.0, 0.0, 120.0],
	"beat_first_3_seconds": [8.0, 0.5, 120.0],
	"beat_gap_3_seconds": [10.0, 0.0, 120.0],
	"riptide_phase": [1, 0, 9],
	"riptide_casts": [4, 1, MAX_CASTS],
	"riptide_warn_seconds": [2.5, 0.4, 10.0],
	"riptide_last_warn_seconds": [3.0, 0.4, 10.0],
	"riptide_run_margin_permille": [1300, 1000, 3000],
	"riptide_wave_seconds": [0.6, 0.1, 3.0],
	"riptide_permille": [350, 1, MAX_HIT],
	"high_tide_phase": [2, 0, 9],
	"high_tide_cast_seconds": [2.5, 0.4, 10.0],
	"high_tide_seconds": [6.0, 1.0, 30.0],
	"high_tide_tick_seconds": [0.5, 0.1, 2.0],
	"high_tide_permille_per_second": [60, 1, 200],
	"high_tide_radius_m": [4.0, 1.0, 8.0],
	"high_tide_gap_m": [12.0, 2.0, 20.0],
	"maelstrom_phase": [2, 0, 9],
	"maelstrom_spin_permille": [450, 0, 900],
	"maelstrom_in_permille": [250, 0, 900],
	"maelstrom_eye_m": [1.5, 0.5, 5.0],
	"maelstrom_permille": [400, 1, MAX_HIT],
	"maelstrom_throw_m": [10.0, 1.0, 15.0],
	"maelstrom_throw_seconds": [0.5, 0.1, 2.0],
	"maelstrom_grace_seconds": [3.0, 0.5, 10.0],
}


## The dance dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(dance: Dictionary, key: String) -> float:
	return float(dance.get(key, (SPEC[key] as Array)[0]))


## The key of phase k's (an index) beat value `what` ("first" or "gap").
static func beat_key(what: String, k: int) -> String:
	return "beat_%s_seconds" % what if k == 0 else "beat_%s_%d_seconds" % [what, k + 1]


static func _has_move(def: BossDefinition, move: StringName) -> bool:
	for a in def.attacks:
		if a != null and a.move == move:
			return true
	return false


## BossDefinition.validate: nothing to check without a dance.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var d := def.dance
	if d.is_empty():
		return
	var p := def.resource_path
	for k: Variant in d:
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "dance: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(d[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "dance.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	for k: String in [
		"riptide_warn_seconds", "riptide_last_warn_seconds", "high_tide_cast_seconds"
	]:
		if int(round(value(d, k) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(&"telegraph_short", p, "dance.%s is under the minimum" % k)
			)
	if value(d, "resume_seconds") >= value(d, "calm_seconds"):
		issues.append(
			ValidationIssue.new(&"duration", p, "dance.resume_seconds must be under calm_seconds")
		)
	var step := value(d, "high_tide_permille_per_second") * value(d, "high_tide_tick_seconds")
	if step < 1.0 or step > MAX_HIT:
		issues.append(
			ValidationIssue.new(
				&"range", p, "dance: a High Tide step takes 1..%d per mille" % MAX_HIT
			)
		)
	if not _has_move(def, &"tide") or not _has_move(def, &"wave"):
		issues.append(ValidationIssue.new(&"attacks", p, "dance needs a tide and a wave attack"))
