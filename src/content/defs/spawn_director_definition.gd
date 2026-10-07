class_name SpawnDirectorDefinition
extends ContentDef
## Continuous spawning for a floor (PLAN v0.2.0 L6, PD-05 flipped): every tier_seconds a new tier raises the
## alive cap, shortens the spawn interval, unlocks more of the mix and scales enemy HP. Starting values.

## Tier n starts at n × tier_seconds of run time.
@export var tier_seconds := 30.0
## Alive cap: min(cap_base + cap_per_tier × tier, cap_max).
@export var cap_base := 3
@export var cap_per_tier := 2
@export var cap_max := 14
## Interval between spawns: max(interval_min, interval_start − interval_step × tier).
@export var interval_start_seconds := 3.0
@export var interval_step_seconds := 0.25
@export var interval_min_seconds := 0.8
## Enemy HP × (1 + hp_scale_per_tier × tier).
@export var hp_scale_per_tier := 0.08
## Enemies never appear closer than this to the player.
@export var min_distance_m := 8.0
@export var mix: Array[SpawnMixEntry] = []


func category() -> StringName:
	return &"spawning"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "tier_seconds", tier_seconds)
	check_duration(issues, "tier_seconds", tier_seconds)
	check_positive(issues, "cap_base", cap_base)
	check_positive(issues, "cap_max", cap_max)
	if cap_per_tier < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "cap_per_tier is negative"))
	if cap_max < cap_base:
		issues.append(ValidationIssue.new(&"cap_range", resource_path, "cap_max is below cap_base"))
	check_positive(issues, "interval_start_seconds", interval_start_seconds)
	check_positive(issues, "interval_min_seconds", interval_min_seconds)
	check_duration(issues, "interval_min_seconds", interval_min_seconds)
	check_duration(issues, "interval_step_seconds", interval_step_seconds)
	if interval_min_seconds > interval_start_seconds:
		issues.append(
			ValidationIssue.new(
				&"interval_range",
				resource_path,
				"interval_min_seconds is above interval_start_seconds"
			)
		)
	if hp_scale_per_tier < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "hp_scale_per_tier is negative")
		)
	check_positive(issues, "min_distance_m", min_distance_m)
	if mix.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "the mix is empty"))
	var opens := false
	for k in mix.size():
		var e := mix[k]
		if e == null or String(e.enemy_id).is_empty() or e.weight <= 0 or e.unlock_tier < 0:
			issues.append(ValidationIssue.new(&"mix_entry", resource_path, "mix[%d] is bad" % k))
			continue
		if e.unlock_tier == 0:
			opens = true
	if not mix.is_empty() and not opens:
		issues.append(
			ValidationIssue.new(&"mix_tier0", resource_path, "no enemy is unlocked at tier 0")
		)
	return issues


## Enemy ids that must exist in the repository.
func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in mix:
		if e != null and not out.has(e.enemy_id):
			out.append(e.enemy_id)
	return out
