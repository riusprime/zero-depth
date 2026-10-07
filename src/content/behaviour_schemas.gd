class_name BehaviourSchemas
extends RefCounted
## The params each enemy behaviour takes (CONTENT_SCHEMA §3). Missing or unknown keys fail validation.
## Lives in content (the lowest layer) so validation can use it; the sim's EnemyAi implements each behaviour.

## Every enemy attack's windup is at least this many ticks (0.4 s; owner, 2026-10-06). SimTick mirrors it.
const MIN_TELEGRAPH_TICKS := 24
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 2 LINE, 4 PROJECTILE.

const SCHEMAS := {
	&"charger":
	{
		"params": ["attack_range_m", "cooldown_seconds"],
		"shape": 2,
		"shape_params": ["length_m", "speed_mps"],
	},
	&"warden":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"front_arc_degrees",
			"front_mult_permille",
			"rear_arc_degrees",
			"rear_mult_permille",
			"turn_rate_dps",
		],
		"shape": 0,
		"shape_params": ["radius_m"],
	},
	&"needle":
	{
		"params": ["attack_range_m", "cooldown_seconds", "keep_distance_m", "flee_distance_m"],
		"shape": 4,
		"shape_params": ["count", "gap_seconds", "speed_mps", "radius_m", "range_m"],
	},
}
