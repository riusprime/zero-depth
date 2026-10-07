class_name ItemDefinition
extends ContentDef
## An item that changes one attack (v0.2.0 PLAN, Items). `kind` picks the effect; only that kind's fields are
## read and validated. Values are starting values the owner tunes after playing.

## Appended, never renumbered (the compiler maps each to a sim kind).
enum Kind {
	LONG_EDGE,
	TWIN_ARC,
	EMBER_EDGE,
	SPLINTER_SHOT,
	RAPID_COIL,
	RICOCHET_CORE,
	KINETIC_DASH,
	OVERCHARGE,
}

@export var kind := Kind.LONG_EDGE
@export var name_key: StringName
@export var desc_key: StringName
## Long Edge: swing reach × (1 + bonus / 1000).
@export var reach_bonus_permille := 0
## Twin Arc: the echo swing's delay and its damage share of the swing.
@export var echo_delay_seconds := 0.0
@export var echo_damage_permille := 0
## Ember Edge: damage per burn stack per period, the burn's length (refreshed by each new stack), the stack cap.
@export var burn_damage := 0
@export var burn_period_seconds := 0.0
@export var burn_duration_seconds := 0.0
@export var burn_max_stacks := 0
## Splinter Shot: bolts per shot, the fan's full width, each bolt's damage share (rounded down, at least 1).
@export var split_count := 0
@export var split_spread_degrees := 0.0
@export var split_damage_permille := 0
## Rapid Coil: fire rate × (1 + bonus / 1000).
@export var fire_rate_bonus_permille := 0
## Ricochet Core: wall bounces per bolt.
@export var bounces := 0
## Kinetic Dash: damage to each enemy the dash passes through (once per dash).
@export var dash_hit_damage := 0
## Overcharge: every Nth swing deals × mult and a shockwave of this radius at a share of the swing's damage.
@export var overcharge_every := 0
@export var overcharge_mult_permille := 0
@export var shockwave_radius_m := 0.0
@export var shockwave_damage_permille := 0


func category() -> StringName:
	return &"items"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	match kind:
		Kind.LONG_EDGE:
			check_positive(issues, "reach_bonus_permille", reach_bonus_permille)
		Kind.TWIN_ARC:
			check_positive(issues, "echo_delay_seconds", echo_delay_seconds)
			check_duration(issues, "echo_delay_seconds", echo_delay_seconds)
			check_positive(issues, "echo_damage_permille", echo_damage_permille)
		Kind.EMBER_EDGE:
			check_positive(issues, "burn_damage", burn_damage)
			check_positive(issues, "burn_period_seconds", burn_period_seconds)
			check_duration(issues, "burn_period_seconds", burn_period_seconds)
			check_positive(issues, "burn_duration_seconds", burn_duration_seconds)
			check_duration(issues, "burn_duration_seconds", burn_duration_seconds)
			check_positive(issues, "burn_max_stacks", burn_max_stacks)
		Kind.SPLINTER_SHOT:
			if split_count < 2:
				issues.append(ValidationIssue.new(&"range", resource_path, "split_count is >= 2"))
			check_positive(issues, "split_spread_degrees", split_spread_degrees)
			check_positive(issues, "split_damage_permille", split_damage_permille)
		Kind.RAPID_COIL:
			check_positive(issues, "fire_rate_bonus_permille", fire_rate_bonus_permille)
		Kind.RICOCHET_CORE:
			check_positive(issues, "bounces", bounces)
		Kind.KINETIC_DASH:
			check_positive(issues, "dash_hit_damage", dash_hit_damage)
		Kind.OVERCHARGE:
			if overcharge_every < 2:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "overcharge_every is >= 2")
				)
			check_positive(issues, "overcharge_mult_permille", overcharge_mult_permille)
			check_positive(issues, "shockwave_radius_m", shockwave_radius_m)
			check_positive(issues, "shockwave_damage_permille", shockwave_damage_permille)
	return issues
