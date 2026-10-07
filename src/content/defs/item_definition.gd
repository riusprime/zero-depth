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
	VAMPIRIC_CORE,
	STATIC_CHAIN,
	MOMENTUM,
	FROST_CORE,
	THORN_MANTLE,
	EXECUTIONER,
	SWIFT_FEET,
	PHASE_STRIKE,
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
## Vampiric Core: HP healed per kill, at most heal_cap HP in each heal_window_seconds.
@export var heal_per_kill := 0
@export var heal_cap := 0
@export var heal_window_seconds := 0.0
## Static Chain: every Nth bolt that lands jumps to the nearest other enemy within chain_range_m.
@export var chain_every := 0
@export var chain_range_m := 0.0
@export var chain_damage := 0
## Momentum: a swing started within the window after a dash ends deals × (1 + bonus / 1000).
@export var momentum_window_seconds := 0.0
@export var momentum_bonus_permille := 0
## Frost Core: a bolt hit slows the enemy to slow_permille / 1000 of its speed (refreshed, never stacked).
@export var slow_permille := 0
@export var slow_seconds := 0.0
## Thorn Mantle: taking damage releases a ring of thorn_bolts bolts of thorn_damage each.
@export var thorn_bolts := 0
@export var thorn_damage := 0
## Executioner: your hits on enemies below threshold / 1000 of their max HP deal × (1 + bonus / 1000).
@export var execute_threshold_permille := 0
@export var execute_bonus_permille := 0
## Swift Feet: move speed × (1 + bonus / 1000); dash cooldown × (1 − cut / 1000).
@export var move_speed_bonus_permille := 0
@export var dash_cooldown_cut_permille := 0
## Phase Strike: a blink's arrival, or the first guarded hit in each window, deals phase_damage in a ring.
@export var phase_damage := 0
@export var phase_radius_m := 0.0
@export var phase_guard_window_seconds := 0.0


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
		Kind.VAMPIRIC_CORE:
			check_positive(issues, "heal_per_kill", heal_per_kill)
			check_positive(issues, "heal_cap", heal_cap)
			check_positive(issues, "heal_window_seconds", heal_window_seconds)
			check_duration(issues, "heal_window_seconds", heal_window_seconds)
		Kind.STATIC_CHAIN:
			check_positive(issues, "chain_every", chain_every)
			check_positive(issues, "chain_range_m", chain_range_m)
			check_positive(issues, "chain_damage", chain_damage)
		Kind.MOMENTUM:
			check_positive(issues, "momentum_window_seconds", momentum_window_seconds)
			check_duration(issues, "momentum_window_seconds", momentum_window_seconds)
			check_positive(issues, "momentum_bonus_permille", momentum_bonus_permille)
		Kind.FROST_CORE:
			_check_permille_below_1000(issues, "slow_permille", slow_permille)
			check_positive(issues, "slow_seconds", slow_seconds)
			check_duration(issues, "slow_seconds", slow_seconds)
		Kind.THORN_MANTLE:
			check_positive(issues, "thorn_bolts", thorn_bolts)
			check_positive(issues, "thorn_damage", thorn_damage)
		Kind.EXECUTIONER:
			_check_permille_below_1000(
				issues, "execute_threshold_permille", execute_threshold_permille
			)
			check_positive(issues, "execute_bonus_permille", execute_bonus_permille)
		Kind.SWIFT_FEET:
			check_positive(issues, "move_speed_bonus_permille", move_speed_bonus_permille)
			_check_permille_below_1000(
				issues, "dash_cooldown_cut_permille", dash_cooldown_cut_permille
			)
		Kind.PHASE_STRIKE:
			check_positive(issues, "phase_damage", phase_damage)
			check_positive(issues, "phase_radius_m", phase_radius_m)
			check_positive(issues, "phase_guard_window_seconds", phase_guard_window_seconds)
			check_duration(issues, "phase_guard_window_seconds", phase_guard_window_seconds)
	return issues


## A per-mille share strictly between 0 and 1000.
func _check_permille_below_1000(issues: Array[ValidationIssue], field: String, v: int) -> void:
	if v <= 0 or v >= 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s is in 1..999" % field))
