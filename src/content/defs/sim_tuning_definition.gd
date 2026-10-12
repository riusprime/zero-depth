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
	]:
		if pair[1] <= 0.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s > 0" % pair[0]))
	check_positive(issues, "heal_orbs_max", heal_orbs_max)
	check_positive(issues, "fire_cap", fire_cap)
	if gate_adds_max < gate_adds_min:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "gate_adds_max >= gate_adds_min")
		)
	return issues
