class_name TimeRules
extends RefCounted
## The content rules of a boss's time mechanics (BossDefinition.time: the Clockwork Judge's Time Wave, hour orbs,
## stopped gears, slow fields, Rewind and its own return; its own file, as the quake pillars' rules). Every key is
## known and within its bounds; a boss with them holds a `time_wave` attack in every phase and its clocks fit one
## inside the other; it holds a `verdict` attack (the Bell's Verdict takes its square and damage from it); a
## `time_wave` attack needs them.

## The most points a trail keeps (its longest reach over its step).
const MAX_POINTS := 64
## key: [default, min, max]. Starting values (the owner's brief: a wave that takes 75 %, three orbs of 25 each; the
## rest the lead's). A phase index past the boss's last phase means never.
const SPEC := {
	"wave_first_seconds": [8.0, 1.0, 60.0],
	"wave_every_seconds": [25.0, 5.0, 120.0],
	"wave_cut_permille": [750, 1, 900],
	"orb_count": [3, 1, 6],
	"orb_permille": [250, 1, 900],
	"orb_radius_m": [1.2, 0.3, 3.0],
	"orb_gap_m": [8.0, 1.0, 20.0],
	"orb_late_phase": [2, 0, 9],
	"orb_late_seconds": [10.0, 1.0, 60.0],
	"gear_phase": [1, 0, 9],
	"gear_count": [4, 0, 6],
	"gear_length_m": [5.0, 1.0, 10.0],
	"gear_width_m": [0.8, 0.2, 2.0],
	"gear_seconds": [12.0, 1.0, 60.0],
	"field_phase": [1, 0, 9],
	"field_every_seconds": [7.0, 1.0, 60.0],
	"field_radius_m": [1.75, 0.5, 5.0],
	"field_seconds": [8.0, 1.0, 60.0],
	"field_speed_permille": [200, 1, 1000],
	"field_max": [3, 1, 6],
	"dodge_mps": [2.5, 0.0, 6.0],
	"rewind_phase": [1, 0, 9],
	"trail_step_seconds": [0.25, 0.05, 1.0],
	"trail_seconds": [4.0, 1.0, 10.0],
	"late_phase": [2, 0, 9],
	"late_trail_seconds": [6.0, 1.0, 10.0],
	"late_tolls": [2, 1, 3],
	"toll_gap_seconds": [3.0, 0.5, 10.0],
	"bell_first_seconds": [15.0, 1.0, 120.0],
	"bell_every_seconds": [20.0, 5.0, 120.0],
	"bell_cast_seconds": [2.0, 0.4, 10.0],
	"bell_verdict_delay_seconds": [0.45, 0.1, 3.0],
	"return_phase": [2, 0, 9],
	"return_hp_permille": [150, 0, 900],
	"return_seconds": [5.0, 1.0, 10.0],
	"return_heal_permille": [50, 0, 500],
	"return_near_m": [4.0, 0.0, 20.0],
}


## The time dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(time: Dictionary, key: String) -> float:
	return float(time.get(key, (SPEC[key] as Array)[0]))


static func _is_verdict(a: BossAttackDefinition) -> bool:
	return a != null and a.move == &"verdict"


## BossDefinition.validate.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var tm := def.time
	var p := def.resource_path
	var waves := def.attacks.filter(
		func(a: BossAttackDefinition) -> bool: return a != null and a.move == &"time_wave"
	)
	if tm.is_empty():
		if not waves.is_empty():
			issues.append(ValidationIssue.new(&"missing", p, "a time_wave attack needs `time`"))
		return
	for k: Variant in tm:
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "time: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(tm[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "time.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	var cast := 0.0
	for ph in def.phases:
		var wave: BossAttackDefinition = null
		for aid in ph.attack_ids if ph != null else PackedStringArray():
			var a := def.attack(StringName(aid))
			if a != null and a.move == &"time_wave":
				wave = a
				break
		if wave == null:
			issues.append(
				ValidationIssue.new(&"attacks", p, "time needs a time_wave in every phase")
			)
		else:
			cast = maxf(cast, wave.telegraph_seconds + wave.active_seconds + wave.recovery_seconds)
	if value(tm, "wave_every_seconds") <= cast:
		issues.append(
			ValidationIssue.new(&"duration", p, "time.wave_every_seconds must exceed its cast")
		)
	var step := value(tm, "trail_step_seconds")
	var reach := maxf(
		maxf(value(tm, "trail_seconds"), value(tm, "late_trail_seconds")),
		value(tm, "return_seconds")
	)
	if value(tm, "late_trail_seconds") < value(tm, "trail_seconds") or reach / step > MAX_POINTS:
		issues.append(
			ValidationIssue.new(
				&"range", p, "time: the late trail is the longer one, at most %d steps" % MAX_POINTS
			)
		)
	var tolls := value(tm, "bell_cast_seconds")
	tolls += (value(tm, "late_tolls") - 1.0) * value(tm, "toll_gap_seconds")
	if value(tm, "bell_every_seconds") <= tolls:
		issues.append(
			ValidationIssue.new(&"duration", p, "time.bell_every_seconds must exceed its tolls")
		)
	var delay := value(tm, "bell_verdict_delay_seconds")
	if delay >= value(tm, "bell_cast_seconds") or delay >= value(tm, "toll_gap_seconds"):
		issues.append(
			ValidationIssue.new(
				&"duration", p, "time.bell_verdict_delay_seconds must end before the next toll"
			)
		)
	if not def.attacks.any(_is_verdict):
		issues.append(ValidationIssue.new(&"attacks", p, "time needs a verdict attack"))
	if int(round(value(tm, "bell_cast_seconds") * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(&"telegraph_short", p, "time: the Bell's cast is under the minimum")
		)
