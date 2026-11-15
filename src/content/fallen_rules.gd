class_name FallenRules
extends RefCounted
## The content rules of The Fallen's own mechanics (FinalBossDefinition.reposition: its dash to a new spot between two
## moves; FinalBossDefinition.remembered: the mechanics of the bosses killed in the run, which it casts at 66 % and
## 33 % of its HP and between them, one at a time). Every key is known and within its bounds, so no single hit of a
## remembered mechanic takes more than MAX_HIT per mille of the hero's max HP; the two HP gates fall in order; a
## charge's aim locks inside its wind-up; the body holds the carrier attacks the death recap names.

## The most one hit of a remembered mechanic may take, per mille of the hero's max HP: never a kill from full.
const MAX_HIT := 400
## The attacks (move `remembered`, in no phase) whose cause keys the death recap names for Riptide and the shade's
## charge (the quake pillars name the table's quake cause, CAUSE_GATEKEEPER_PILLAR).
const RIPTIDE_CARRIER := &"fallen_riptide"
const SHADE_CARRIER := &"fallen_shade"
## key: [default, min, max] (seconds, metres, m/s).
const REPOSITION_SPEC := {
	"dash_telegraph_seconds": [0.4, 0.3, 1.0],
	"dash_seconds": [0.2, 0.1, 0.6],
	"dash_min_m": [6.0, 2.0, 12.0],
	"dash_max_m": [9.0, 2.0, 14.0],
	"dash_wall_m": [3.0, 1.0, 6.0],
}
## key: [default, min, max]. Starting values (the owner's direction HC-A and the lead's step brief): one mechanic at
## 66 % and at 33 % of the HP and otherwise one every 30 s from the end of the last, the first no sooner than 12 s in,
## 3 s of calm on each side of a mimic window, a 1.5 s cast. *_permille of a hit: of the hero's max HP.
const SPEC := {
	"first_permille": [660, 100, 900],
	"second_permille": [330, 50, 800],
	"every_seconds": [30.0, 10.0, 120.0],
	"first_seconds": [12.0, 0.0, 60.0],
	"calm_seconds": [3.0, 1.0, 10.0],
	"cast_seconds": [1.5, 0.5, 4.0],
	# Time Wave (the Clockwork Judge's): the cut, its hour orbs (each returns its share), their life
	"time_cut_permille": [750, 100, 900],
	"time_orbs": [3, 1, 5],
	"time_orb_permille": [250, 50, 900],
	"time_orb_radius_m": [1.2, 0.5, 3.0],
	"time_orb_gap_m": [8.0, 2.0, 16.0],
	"time_seconds": [12.0, 4.0, 30.0],
	# Riptide (the Tidecaller's): one row on the room's four strips
	"riptide_casts": [3, 1, 4],
	"riptide_warn_seconds": [2.5, 1.0, 6.0],
	"riptide_wave_seconds": [0.6, 0.2, 2.0],
	"riptide_run_margin_permille": [1300, 1000, 2000],
	"riptide_permille": [300, 10, MAX_HIT],
	# Quake pillars (the Gatekeeper's): their pulse, and the dash that shatters one and stuns
	"pillar_count": [3, 1, 4],
	"pillar_seconds": [15.0, 5.0, 30.0],
	"pillar_m": [1.2, 0.6, 2.4],
	"pillar_ring_m": [7.0, 2.0, 10.0],
	"pillar_pulse_seconds": [3.0, 1.0, 8.0],
	"pillar_warn_seconds": [0.8, 0.5, 2.0],
	"pillar_permille": [60, 1, MAX_HIT],
	"pillar_gap_m": [7.0, 2.0, 12.0],
	"pillar_wall_m": [1.5, 0.5, 4.0],
	"pillar_boss_m": [2.0, 0.5, 6.0],
	"pillar_hero_m": [3.0, 0.0, 8.0],
	"pillar_dash_seconds": [3.0, 1.0, 8.0],
	"pillar_stun_seconds": [3.0, 0.5, 8.0],
	"pillar_stuns": [2, 0, 4],
	# Both stuns (a pillar shattered, the ward broken): the share of every hit the body takes
	"stun_taken_permille": [1500, 1000, 3000],
	# The ward (the Twin Wardens'): the amber Warden's shade charges at the hero; its lane through The Fallen breaks it
	"ward_seconds": [12.0, 4.0, 20.0],
	"ward_windup_seconds": [1.4, 0.8, 4.0],
	"ward_lock_seconds": [0.5, 0.1, 2.0],
	"ward_speed_mps": [26.0, 8.0, 40.0],
	"ward_overshoot_m": [3.0, 0.0, 8.0],
	"ward_charges": [2, 1, 3],
	"ward_gap_seconds": [3.0, 0.5, 8.0],
	"ward_radius_m": [0.9, 0.3, 2.0],
	"ward_edge_m": [1.5, 0.5, 4.0],
	"ward_permille": [250, 1, MAX_HIT],
	"ward_burst_m": [3.5, 1.0, 6.0],
	"ward_burst_seconds": [0.25, 0.1, 1.0],
	"ward_burst_permille": [300, 1, MAX_HIT],
	"ward_stun_seconds": [4.0, 0.5, 8.0],
}


## The remembered dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(d: Dictionary, key: String) -> float:
	return float(d.get(key, (SPEC[key] as Array)[0]))


## The reposition dictionary's value for `key` (its default when the dictionary leaves it out).
static func dash_value(d: Dictionary, key: String) -> float:
	return float(d.get(key, (REPOSITION_SPEC[key] as Array)[0]))


## FinalBossDefinition.validate.
static func validate(def: FinalBossDefinition, issues: Array[ValidationIssue]) -> void:
	var p := def.resource_path
	if not def.reposition.is_empty():
		if not def.mimic:
			issues.append(ValidationIssue.new(&"missing", p, "reposition needs mimic"))
		_bounds(def.reposition, REPOSITION_SPEC, "reposition", p, issues)
		if dash_value(def.reposition, "dash_min_m") > dash_value(def.reposition, "dash_max_m"):
			issues.append(ValidationIssue.new(&"range", p, "reposition: dash_min_m <= dash_max_m"))
	var d := def.remembered
	if d.is_empty():
		return
	if not def.mimic or def.reposition.is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "remembered needs mimic and reposition"))
	_bounds(d, SPEC, "remembered", p, issues)
	if value(d, "second_permille") >= value(d, "first_permille"):
		issues.append(
			ValidationIssue.new(&"range", p, "remembered: second_permille < first_permille")
		)
	if value(d, "ward_lock_seconds") >= value(d, "ward_windup_seconds"):
		issues.append(
			ValidationIssue.new(&"duration", p, "remembered: the shade's aim locks in its wind-up")
		)
	for id: StringName in [RIPTIDE_CARRIER, SHADE_CARRIER]:
		var a := def.attack(id)
		if a == null or a.move != &"remembered" or String(a.cause_key).is_empty():
			issues.append(
				ValidationIssue.new(&"attacks", p, "remembered needs a `remembered` attack %s" % id)
			)


static func _bounds(
	d: Dictionary, spec: Dictionary, name: String, p: String, issues: Array[ValidationIssue]
) -> void:
	for k: Variant in d:
		if not spec.has(k):
			issues.append(
				ValidationIssue.new(&"unknown_field", p, "%s: unknown key %s" % [name, k])
			)
			continue
		var s: Array = spec[k]
		var v := float(d[k])
		if v < float(s[1]) or v > float(s[2]):
			issues.append(ValidationIssue.new(&"range", p, "%s.%s: %s..%s" % [name, k, s[1], s[2]]))
