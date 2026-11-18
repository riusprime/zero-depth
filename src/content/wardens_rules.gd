class_name WardensRules
extends RefCounted
## The content rules of the Twin Wardens' own mechanics (BossDefinition.wardens: the amber Warden's side dash and
## sword combo, the Sword Lane's length, the violet Warden's Mirror Ward and Shadow Swords, the last phase's ward and
## Through the Rift; its own file, as the time mechanics' rules). Every key is known and within its bounds; a boss
## with them is a twin boss; its clocks fit one inside the other; the attack Through the Rift ends with is a charge
## in no phase that never takes more than RIFT_MAX_PERMILLE of the base hero's HP; a `sword_combo`, `mirror_ward` or
## `shadow_swords` attack needs them.

## The moves that need the dictionary.
const MOVES: Array[StringName] = [&"sword_combo", &"mirror_ward", &"shadow_swords"]
## The base hero's HP (data/player/runner.tres) and the most of it one hit of Through the Rift may take.
const BASE_HP := 100
const RIFT_MAX_PERMILLE := 400
## The most blades Shadow Swords shows (each takes one of the boss's locked points; the last holds their centre).
const MAX_SWORDS := 6
## key: [default, min, max]. Starting values (the owner's brief and the lead's numbers).
const SPEC := {
	"dash_m": [4.0, 1.0, 8.0],
	"dash_seconds": [0.25, 0.1, 1.0],
	"dash_every_seconds": [3.0, 0.5, 30.0],
	"combo_light_permille": [750, 100, 1000],
	"sword_lane_max_m": [9.0, 3.0, 14.0],
	"mirror_seconds": [4.0, 1.0, 10.0],
	"mirror_arc_degrees": [160.0, 30.0, 360.0],
	"mirror_damage_permille": [500, 0, 1000],
	"mirror_cap_permille": [200, 10, 400],
	"mirror_range_m": [16.0, 4.0, 30.0],
	"mirror_push_m": [2.0, 0.0, 5.0],
	"sword_count": [5, 1, 6],
	"sword_ring_m": [5.0, 2.0, 8.0],
	"sword_fan_degrees": [200.0, 30.0, 360.0],
	"sword_length_m": [8.0, 3.0, 14.0],
	"sword_width_m": [0.9, 0.3, 2.0],
	"sword_gap_seconds": [0.2, 0.05, 1.0],
	"ward_phase": [2, 0, 9],
	"ward_stun_seconds": [5.0, 1.0, 10.0],
	"ward_stun_permille": [1500, 1000, 3000],
	"ward_stagger_seconds": [2.0, 0.5, 5.0],
	"ward_return_seconds": [12.0, 5.0, 60.0],
	"rift_hp_permille": [500, 0, 900],
	"rift_gap_m": [8.0, 4.0, 12.0],
	"rift_radius_m": [1.2, 0.5, 3.0],
	"rift_open_seconds": [1.0, 0.4, 5.0],
	"rift_inside_seconds": [1.5, 0.6, 5.0],
	"rift_mark_seconds": [0.5, 0.2, 2.0],
	"ranged_beyond_m": [0.0, 0.0, 20.0],
	"charge_min_seconds": [10.0, 2.0, 60.0],
	"charge_max_seconds": [15.0, 2.0, 60.0],
	"ward_charge_min_seconds": [10.0, 2.0, 60.0],
	"ward_charge_max_seconds": [12.0, 2.0, 60.0],
	"ward_first_seconds": [4.0, 0.0, 30.0],
	"amber_warded_permille": [1000, 0, 1000],
	"shelter_m": [3.0, 1.0, 8.0],
}
## Keys that hold text: the returned shot's recap line and look, the attacks the rift's exit charge, the two charges
## on their own clocks, the whole ward's cast and the sheltering Crossfire are.
const TEXT_KEYS := [
	"mirror_cause_key",
	"mirror_look",
	"rift_attack",
	"charge_attack",
	"ward_charge_attack",
	"ward_attack",
	"shelter_attack"
]
## The base hero's walking speed (m/s, PlayerTable.starting_values) and the margin the shelter's warning leaves over
## the walk to it (per mille of the walk).
const BASE_SPEED_MPS := 6.0
const SHELTER_MARGIN_PERMILLE := 1300


## The wardens dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(wd: Dictionary, key: String) -> float:
	return float(wd.get(key, (SPEC[key] as Array)[0]))


static func _needs(a: BossAttackDefinition) -> bool:
	return a != null and MOVES.has(a.move)


## BossDefinition.validate.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var wd := def.wardens
	var p := def.resource_path
	if wd.is_empty():
		if def.attacks.any(_needs):
			issues.append(
				ValidationIssue.new(&"missing", p, "a sword combo, a ward or swords need `wardens`")
			)
		return
	if String(def.twin_kind_id).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "wardens needs a twin"))
	for k: Variant in wd:
		if TEXT_KEYS.has(k):
			continue
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "wardens: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(wd[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "wardens.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	if String(wd.get("mirror_cause_key", "")).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "wardens needs mirror_cause_key"))
	if value(wd, "ward_return_seconds") <= value(wd, "ward_stun_seconds"):
		issues.append(
			ValidationIssue.new(&"duration", p, "wardens: the ward returns after the stun ends")
		)
	if value(wd, "rift_mark_seconds") > value(wd, "rift_inside_seconds"):
		issues.append(
			ValidationIssue.new(&"duration", p, "wardens: the exit is marked while it is inside")
		)
	if value(wd, "dash_every_seconds") <= value(wd, "dash_seconds"):
		issues.append(ValidationIssue.new(&"duration", p, "wardens: a dash ends before the next"))
	_check_rift(def, issues)
	_check_clocks(def, issues)


## The charges on their own clocks name charges, each clock's shortest wait is within its longest; the whole ward's
## cast is a `mirror_ward` in no phase; the sheltering Crossfire's spot is walked to with SHELTER_MARGIN_PERMILLE of
## the walk to spare inside its warning.
static func _check_clocks(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var wd := def.wardens
	var p := def.resource_path
	for c: Array in [["charge", "charge"], ["ward_charge", "charge"], ["ward", "mirror_ward"]]:
		var id := String(wd.get(c[0] + "_attack", ""))
		var a := def.attack(StringName(id))
		if not id.is_empty() and (a == null or a.move != StringName(c[1])):
			issues.append(ValidationIssue.new(&"missing", p, "wardens.%s_attack" % c[0]))
	for c: String in ["charge", "ward_charge"]:
		if value(wd, c + "_min_seconds") > value(wd, c + "_max_seconds"):
			issues.append(ValidationIssue.new(&"duration", p, "wardens: %s's clock" % c))
	var ward := def.attack(StringName(String(wd.get("ward_attack", ""))))
	for ph in def.phases:
		if ward != null and ph != null and ph.attack_ids.has(String(ward.id)):
			issues.append(ValidationIssue.new(&"attacks", p, "wardens.ward_attack in no phase"))
	var sid := String(wd.get("shelter_attack", ""))
	if sid.is_empty():
		return
	var s := def.attack(StringName(sid))
	if s == null or s.move != &"crossfire":
		issues.append(
			ValidationIssue.new(&"missing", p, "wardens.shelter_attack names a crossfire")
		)
		return
	var walk := value(wd, "shelter_m") / BASE_SPEED_MPS * SHELTER_MARGIN_PERMILLE / 1000.0
	if walk > s.telegraph_seconds:
		issues.append(
			ValidationIssue.new(&"duration", p, "wardens: the shelter is reached in its warning")
		)


## The exit charge is a `charge` of this boss, in no phase, and neither its body nor its burst takes more than
## RIFT_MAX_PERMILLE of the base hero's HP.
static func _check_rift(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var wd := def.wardens
	var p := def.resource_path
	if value(wd, "rift_hp_permille") <= 0.0:
		return
	var a := def.attack(StringName(String(wd.get("rift_attack", ""))))
	if a == null or a.move != &"charge":
		issues.append(ValidationIssue.new(&"missing", p, "wardens.rift_attack names a charge"))
		return
	if a.damage * 1000 > BASE_HP * RIFT_MAX_PERMILLE:
		issues.append(
			ValidationIssue.new(&"range", p, "wardens: the rift's charge takes at most 40 % HP")
		)
	for ph in def.phases:
		if ph != null and ph.attack_ids.has(String(a.id)):
			issues.append(
				ValidationIssue.new(&"attacks", p, "wardens.rift_attack is in no phase's list")
			)
