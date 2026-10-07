class_name PlayerDefinition
extends ContentDef
## The player character (CONTENT_SCHEMA §8). Values: starting values listed in GAME_BLUEPRINT §C.

## Limits on the melee combo (v0.3.0 L11): steps, and how far one step may lunge.
const MAX_COMBO_STEPS := 8
const MAX_LUNGE_M := 2.0

@export var hp := 100
@export var radius_m := 0.35
@export var move_speed_mps := 6.0
## Time to close 90% of the gap to full speed, and to a stop (owner, 2026-10-07: "a fast smooth curve").
@export var accel_seconds := 0.1
@export var stop_seconds := 5.0 / 60.0
@export var dash: DashDefinition
@export var primary: PrimaryDefinition
## After taking a hit: invulnerability and hit-stop.
@export var hurt_iframes_seconds := 0.5
@export var hurt_hitstop_seconds := 4.0 / 60.0
## Out-of-combat regen (v0.3.0 L25, starting values): after this long without dealing or taking damage, heal this
## per mille of max HP each second.
@export var regen_delay_seconds := 10.0
@export var regen_permille_per_second := 10


func category() -> StringName:
	return &"player"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if hp <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "hp must be > 0"))
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "move_speed_mps", move_speed_mps)
	if dash == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "dash is missing"))
	else:
		check_positive(issues, "dash.distance_m", dash.distance_m)
		check_duration(issues, "dash.duration_seconds", dash.duration_seconds)
		check_duration(issues, "dash.cooldown_seconds", dash.cooldown_seconds)
		check_duration(issues, "dash.iframes_seconds", dash.iframes_seconds)
		if dash.duration_seconds <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"not_positive", resource_path, "dash.duration_seconds must be > 0"
				)
			)
	check_duration(issues, "hurt_iframes_seconds", hurt_iframes_seconds)
	check_duration(issues, "hurt_hitstop_seconds", hurt_hitstop_seconds)
	check_duration(issues, "regen_delay_seconds", regen_delay_seconds)
	if regen_permille_per_second < 0 or regen_permille_per_second > 1000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "regen_permille_per_second is 0..1000")
		)
	if primary == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "primary is missing"))
	else:
		_check_primary(issues)
	return issues


func _check_primary(issues: Array[ValidationIssue]) -> void:
	var p := primary
	check_duration(issues, "primary.combo_window_seconds", p.combo_window_seconds)
	check_duration(issues, "primary.shot_period_seconds", p.shot_period_seconds)
	check_positive(issues, "primary.bolt_speed_mps", p.bolt_speed_mps)
	if p.combo.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "primary.combo is empty"))
	elif p.combo.size() > MAX_COMBO_STEPS:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "primary.combo has more than %d steps" % MAX_COMBO_STEPS
			)
		)
	for k in p.combo.size():
		_check_step(issues, "primary.combo[%d]" % k, p.combo[k])
	if p.shot_period_seconds <= 0.0 or p.bolt_damage <= 0:
		issues.append(
			ValidationIssue.new(
				&"not_positive", resource_path, "shooting needs a period and damage"
			)
		)


## One combo step: it must hit (a positive active time, damage, reach and arc up to all around), its timings must
## be whole ticks, and a lunge needs at least one tick before the hit to happen in.
func _check_step(issues: Array[ValidationIssue], field: String, s: SwingStepDefinition) -> void:
	if s == null:
		issues.append(ValidationIssue.new(&"missing", resource_path, "%s is missing" % field))
		return
	check_duration(issues, field + ".active_seconds", s.active_seconds)
	check_duration(issues, field + ".recovery_seconds", s.recovery_seconds)
	check_duration(issues, field + ".hitstop_seconds", s.hitstop_seconds)
	check_duration(issues, field + ".sweep_seconds", s.sweep_seconds)
	check_positive(issues, field + ".active_seconds", s.active_seconds)
	check_positive(issues, field + ".sweep_seconds", s.sweep_seconds)
	check_positive(issues, field + ".reach_m", s.reach_m)
	check_positive(issues, field + ".damage", s.damage)
	if s.arc_degrees <= 0.0 or s.arc_degrees > 360.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s.arc_degrees is in (0, 360]" % field)
		)
	if s.lunge_m < 0.0 or s.lunge_m > MAX_LUNGE_M:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "%s.lunge_m is in [0, %s]" % [field, MAX_LUNGE_M]
			)
		)
	elif s.lunge_m > 0.0 and int(round(s.active_seconds * 60.0)) < 2:
		issues.append(
			ValidationIssue.new(
				&"order", resource_path, "%s lunges, so it must hit 2 ticks or more in" % field
			)
		)
