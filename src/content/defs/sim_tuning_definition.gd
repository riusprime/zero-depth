class_name SimTuningDefinition
extends ContentDef
## The designer numbers the sim used to keep in its code (docs/tools/DEV_PANEL.md Step 6), in content units
## (seconds, metres, per mille), compiled into SimTuning. The shipped file holds exactly the old constants.

@export var spawn_in_seconds := 0.6
@export var boss_intro_seconds := 1.0
@export var boss_after_stagger_seconds := 0.5
@export var gate_seconds := 1.0
@export var gate_adds_min := 2
@export var gate_adds_max := 4
@export var gate_add_ring_m := 3.2
@export var ai_commit_seconds := 0.2
@export var ai_snipe_commit_seconds := 0.4
@export var ai_strafe_permille := 600
@export var ai_flank_permille := 450
@export var ai_flank_min_m := 2.0
@export var ai_flank_range_m := 6.0
@export var ai_spread_radius_m := 1.6
@export var ai_spread_weight := 1.2
@export var ai_relocate_speed_permille := 1500
@export var ai_relocate_max_seconds := 2.5
@export var ai_mend_scan_seconds := 0.25
@export var heal_orbs_max := 16
@export var pickup_radius_m := 0.8
@export var fire_cap := 48
@export var fire_hit_seconds := 0.5
@export var fire_trail_spacing_m := 0.8
@export var field_min_m := 1.5
## v0.8.0 PF (owner O9): the player's projectiles alive at once, at most (the frame budget's sim cap).
@export var player_shots_max := 256
## v0.8.0 N11 (owner O69): the hero's arrival on the floor's receiver: floor 1 of a run, a later floor, reduced motion.
@export var arrival_first_seconds := 1.6
@export var arrival_seconds := 0.8
@export var arrival_calm_seconds := 0.3
## v0.8.0 SG (owner O91): the attack-speed curve (AttackRate): a raw bonus counts in full up to the knee, then at
## slope per mille up to knee2, then at slope2 (per mille; knee2 >= knee).
@export var attack_speed_knee_permille := 500
@export var attack_speed_knee2_permille := 1500
@export var attack_speed_slope_permille := 500
@export var attack_speed_slope2_permille := 250


func category() -> StringName:
	return &"tuning"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for pair: Array in [
		["spawn_in_seconds", spawn_in_seconds],
		["boss_intro_seconds", boss_intro_seconds],
		["gate_seconds", gate_seconds],
		["ai_relocate_max_seconds", ai_relocate_max_seconds],
		["ai_mend_scan_seconds", ai_mend_scan_seconds],
		["ai_spread_radius_m", ai_spread_radius_m],
		["pickup_radius_m", pickup_radius_m],
		["fire_hit_seconds", fire_hit_seconds],
		["fire_trail_spacing_m", fire_trail_spacing_m],
		["arrival_first_seconds", arrival_first_seconds],  # v0.8.0 N11
		["arrival_seconds", arrival_seconds],
		["arrival_calm_seconds", arrival_calm_seconds],
	]:
		if pair[1] <= 0.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s > 0" % pair[0]))
	check_positive(issues, "heal_orbs_max", heal_orbs_max)
	check_positive(issues, "fire_cap", fire_cap)
	check_positive(issues, "player_shots_max", player_shots_max)
	_validate_attack_speed(issues)
	if gate_adds_max < gate_adds_min:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "gate_adds_max >= gate_adds_min")
		)
	return issues


## v0.8.0 SG: the knees are 0 or more and in order; the slopes between 0 and 1000 per mille.
func _validate_attack_speed(issues: Array[ValidationIssue]) -> void:
	if attack_speed_knee_permille < 0 or attack_speed_knee2_permille < attack_speed_knee_permille:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "0 <= attack_speed knee <= knee2")
		)
	for pair: Array in [
		["attack_speed_slope_permille", attack_speed_slope_permille],
		["attack_speed_slope2_permille", attack_speed_slope2_permille],
	]:
		if pair[1] < 0 or pair[1] > 1000:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s in 0..1000" % pair[0]))
