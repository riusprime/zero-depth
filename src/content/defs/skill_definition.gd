class_name SkillDefinition
extends Resource
## A build's second ability on the Skill button (v0.3.5 K, owner F18; CONTENT_SCHEMA §8), a sub-resource of its
## BuildDefinition. Times in seconds and angles in degrees, compiled to ticks and 1/4096 turns once
## (ContentCompiler.compile_skill). Starting values the owner tunes after playing.
## - LUNGE_CLEAVE (the Blade): a lunge of lunge_m along the facing over lunge_seconds, then a fan arc_degrees wide
##   reaching reach_m past the user's edge, `damage` (x the build's factor) with hitstop_seconds of hit-stop.
## - SCATTER_BLAST (the Gun): `pellets` rays spread over cone_degrees toward the aim, out to range_m past the user's
##   edge, `damage` each (x the build's factor); an enemy hit slides knockback_m away over knockback_seconds; the
##   user steps back recoil_m over recoil_seconds.

## Appended, never renumbered (SkillTable.Kind mirrors it).
enum Kind { LUNGE_CLEAVE, SCATTER_BLAST }

## The build weapon (BuildDefinition.Weapon) each kind belongs to.
const WEAPON_OF := {Kind.LUNGE_CLEAVE: 0, Kind.SCATTER_BLAST: 1}
const MAX_COOLDOWN_SECONDS := 60.0
const MAX_DAMAGE := 1000
const MAX_DISTANCE_M := 12.0
const MAX_PELLETS := 32

@export var kind := Kind.LUNGE_CLEAVE
@export var name_key: StringName
@export var desc_key: StringName
@export var cooldown_seconds := 4.0
@export var damage := 28
## Heat points a use adds when it lands (once per use).
@export var heat := 5.0
@export_group("Lunge Cleave")
@export var lunge_m := 3.5
@export var lunge_seconds := 0.2
@export var arc_degrees := 180.0
@export var reach_m := 2.2
@export var hitstop_seconds := 0.1166667
@export_group("Scatter Blast")
@export var pellets := 7
@export var cone_degrees := 60.0
@export var range_m := 4.0
@export var pellet_radius_m := 0.12
@export var knockback_m := 1.5
@export var knockback_seconds := 0.1333333
@export var recoil_m := 0.8
@export var recoil_seconds := 0.1


## Issues are reported against `path` (the build's file).
func validate(path: String) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	if kind < Kind.LUNGE_CLEAVE or kind > Kind.SCATTER_BLAST:
		issues.append(
			ValidationIssue.new(&"range", path, "skill.kind is lunge_cleave or scatter_blast")
		)
		return issues
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", path, "skill name_key and desc_key are required")
		)
	_ticks(issues, path, "cooldown_seconds", cooldown_seconds, MAX_COOLDOWN_SECONDS)
	if damage < 1 or damage > MAX_DAMAGE:
		issues.append(ValidationIssue.new(&"range", path, "skill.damage is 1..%d" % MAX_DAMAGE))
	if heat < 0.0 or heat > 100.0:
		issues.append(ValidationIssue.new(&"range", path, "skill.heat is 0..100"))
	if kind == Kind.LUNGE_CLEAVE:
		_metres(issues, path, "lunge_m", lunge_m)
		_metres(issues, path, "reach_m", reach_m)
		_ticks(issues, path, "lunge_seconds", lunge_seconds, 2.0)
		_degrees(issues, path, "arc_degrees", arc_degrees)
		if hitstop_seconds < 0.0 or hitstop_seconds > 8.0 / 60.0 + 1e-6:
			issues.append(
				ValidationIssue.new(&"range", path, "skill.hitstop_seconds is 0..8 ticks (the cap)")
			)
	else:
		if pellets < 1 or pellets > MAX_PELLETS:
			issues.append(
				ValidationIssue.new(&"range", path, "skill.pellets is 1..%d" % MAX_PELLETS)
			)
		_degrees(issues, path, "cone_degrees", cone_degrees)
		_metres(issues, path, "range_m", range_m)
		if pellet_radius_m <= 0.0 or pellet_radius_m > 1.0:
			issues.append(ValidationIssue.new(&"range", path, "skill.pellet_radius_m is (0, 1]"))
		if knockback_m < 0.0 or knockback_m > MAX_DISTANCE_M:
			issues.append(ValidationIssue.new(&"range", path, "skill.knockback_m is 0..12"))
		if knockback_m > 0.0:
			_ticks(issues, path, "knockback_seconds", knockback_seconds, 2.0)
		if recoil_m < 0.0 or recoil_m > MAX_DISTANCE_M:
			issues.append(ValidationIssue.new(&"range", path, "skill.recoil_m is 0..12"))
		_ticks(issues, path, "recoil_seconds", recoil_seconds, 2.0)
	return issues


static func _ticks(
	issues: Array[ValidationIssue], path: String, field: String, seconds: float, most: float
) -> void:
	if int(round(seconds * 60.0)) < 1 or seconds > most:
		issues.append(
			ValidationIssue.new(
				&"range", path, "skill.%s is at least 1 tick and at most %s s" % [field, most]
			)
		)


static func _metres(issues: Array[ValidationIssue], path: String, field: String, m: float) -> void:
	if m <= 0.0 or m > MAX_DISTANCE_M:
		issues.append(ValidationIssue.new(&"range", path, "skill.%s is (0, 12] m" % field))


static func _degrees(
	issues: Array[ValidationIssue], path: String, field: String, deg: float
) -> void:
	if deg <= 0.0 or deg > 360.0:
		issues.append(ValidationIssue.new(&"range", path, "skill.%s is (0, 360]" % field))
