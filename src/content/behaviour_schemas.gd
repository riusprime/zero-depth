class_name BehaviourSchemas
extends RefCounted
## The params each enemy behaviour takes (CONTENT_SCHEMA §3). Missing or unknown keys fail validation.
## Lives in content (the lowest layer) so validation can use it; the sim's EnemyAi implements each behaviour.

## Every enemy attack's windup is at least this many ticks (0.4 s; owner, 2026-10-06). SimTick mirrors it.
const MIN_TELEGRAPH_TICKS := 24
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 2 LINE, 4 PROJECTILE.
## A behaviour with one attack names its "shape" and "shape_params"; one with several (v0.3.5 AI: the Arc Caster)
## lists "attacks", each with its "id", "shape" and "shape_params", in the order the definition must give them.

const SCHEMAS := {
	&"charger":
	{
		"params": ["attack_range_m", "cooldown_seconds", "charge_turn_dps"],
		"shape": 2,
		"shape_params": ["length_m", "speed_mps"],
	},
	## The Brood Mother's hatchlings (PLAN v0.3.0 C): a small Charger.
	&"hatchling":
	{
		"params": ["attack_range_m", "cooldown_seconds", "charge_turn_dps"],
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
		"shape_params":
		["count", "gap_seconds", "speed_mps", "radius_m", "range_m", "spread_degrees"],
	},
	## v0.3.5 AI (owner F5): keeps keep_min_m..keep_max_m away and casts one of three spells, picked by weight.
	&"arc_caster":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"keep_min_m",
			"keep_max_m",
			"bolt_weight",
			"spread_weight",
			"rune_weight",
		],
		"attacks":
		[
			{"id": &"bolt", "shape": 4, "shape_params": ["speed_mps", "radius_m", "range_m"]},
			{
				"id": &"spread",
				"shape": 4,
				"shape_params": ["count", "spread_degrees", "speed_mps", "radius_m", "range_m"],
			},
			{"id": &"rune", "shape": 0, "shape_params": ["radius_m"]},
		],
	},
	## v0.3.5 AI (owner F6): hovers keep_min_m..keep_max_m away and lobs a bomb whose circle fills for the windup.
	&"bomb_drone":
	{
		"params": ["attack_range_m", "cooldown_seconds", "keep_min_m", "keep_max_m"],
		"shape": 0,
		"shape_params": ["radius_m"],
	},
	## v0.4.0 EN, the horde kinds. A Swarmer is a tiny Charger whose charge is a short lunge bite.
	&"swarmer":
	{
		"params": ["attack_range_m", "cooldown_seconds", "charge_turn_dps"],
		"shape": 2,
		"shape_params": ["length_m", "speed_mps"],
	},
	## A Splitter swipes a disc reach_m ahead of it and, when it dies, splits into split_count Splitlings.
	&"splitter":
	{
		"params": ["attack_range_m", "cooldown_seconds", "split_count"],
		"shape": 0,
		"shape_params": ["radius_m", "reach_m"],
	},
	&"splitling":
	{
		"params": ["attack_range_m", "cooldown_seconds"],
		"shape": 0,
		"shape_params": ["radius_m", "reach_m"],
	},
	## A Shield Bearer blocks every hit from its front shield_arc_degrees, turns slowly and bashes a short lane.
	&"shield_bearer":
	{
		"params": ["attack_range_m", "cooldown_seconds", "shield_arc_degrees", "turn_rate_dps"],
		"shape": 2,
		"shape_params": ["length_m", "half_width_m"],
	},
	## A Mender keeps away and heals; it has no attack.
	&"mender":
	{
		"params":
		["keep_min_m", "keep_max_m", "heal_amount", "heal_period_seconds", "heal_range_m"],
		"attacks": [],
	},
	## A Mine Layer drops mines (the drop takes drop_seconds); a mine arms when the player steps into its circle and
	## blows after its telegraph (the fuse).
	&"mine_layer":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"keep_min_m",
			"keep_max_m",
			"drop_seconds",
			"max_mines",
			"mine_life_seconds",
		],
		"shape": 0,
		"shape_params": ["radius_m"],
	},
	## A Sniper keeps far, draws a long line for its telegraph, shoots down it and walks to a new spot.
	&"sniper":
	{
		"params": ["attack_range_m", "cooldown_seconds", "keep_min_m", "keep_max_m"],
		"shape": 2,
		"shape_params": ["range_m", "half_width_m"],
	},
}
