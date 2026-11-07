class_name BehaviourSchemas
extends RefCounted
## The params each enemy behaviour takes (CONTENT_SCHEMA §3). Missing or unknown keys fail validation.
## Lives in content (the lowest layer) so validation can use it; the sim's EnemyAi implements each behaviour.

## Every enemy attack's windup is at least this many ticks (0.4 s; owner, 2026-10-06). SimTick mirrors it.
const MIN_TELEGRAPH_TICKS := 24
## v0.11.0 O9: the horde critters' schema (one rule set, five bodies).
const CRITTER := {"params": ["contact_damage", "contact_cd_seconds", "flies"], "attacks": []}
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
	## v0.4.0 BO: the Hive Lens's drones, split off at half HP; they fly the Needle's behaviour (EnemyAi.behaviour_of).
	## v0.7.5 EF (owner N16): they fire a slow fireball pattern (data/bullet_patterns, a ring of orbs), not a burst.
	&"lens_drone":
	{
		"params": ["attack_range_m", "cooldown_seconds", "keep_distance_m", "flee_distance_m"],
		"shape": 4,
		"shape_params": ["pattern_id"],
	},
	## v0.3.5 AI (owner F5): keeps keep_min_m..keep_max_m away and casts one of three spells, picked by weight.
	## v0.7.5 EF (owner N16): the bolt and the spread each fire a slow fireball pattern (a fan of plasma balls).
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
			{"id": &"bolt", "shape": 4, "shape_params": ["pattern_id"]},
			{"id": &"spread", "shape": 4, "shape_params": ["pattern_id"]},
			{"id": &"rune", "shape": 0, "shape_params": ["radius_m"]},
		],
	},
	## v0.3.5 AI (owner F6): hovers keep_min_m..keep_max_m away and lobs a bomb whose circle fills for the windup.
	## v0.7.5 EF (owner N16): it lobs a fireball (a BURST pattern) that bursts into small ones; no ground circle.
	&"bomb_drone":
	{
		"params": ["attack_range_m", "cooldown_seconds", "keep_min_m", "keep_max_m"],
		"shape": 4,
		"shape_params": ["pattern_id"],
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
	## v0.11.0 O9 (PLAN H1; owner Q14): the horde critters, one per biome, one rule set (EnemyAi.is_critter): no attack;
	## a touch hurts for contact_damage at most every contact_cd_seconds; `flies` (true or false) lets it fly over the
	## floor's hazards (the Cave Bat).
	&"dust_mite": CRITTER,
	&"cave_bat": CRITTER,
	&"ember_flea": CRITTER,
	&"ice_crab": CRITTER,
	&"star_mote": CRITTER,
	## v0.11.0 O13a (ENEMIES.md V1-V5; owner Q23): the biome variants, each its base's params and attack (VARIANT_OF)
	## plus its own (Variants). The Rubble Warden: a crust of crust_hp on top of its HP that falls off at half HP as
	## crust_pieces small rocks of cover (half side piece_half_m).
	&"rubble_warden":
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
			"crust_hp",
			"crust_pieces",
			"piece_half_m",
		],
		"shape": 0,
		"shape_params": ["radius_m"],
	},
	## The Dim Needle: its shots stay dark while farther than dark_beyond_m from the hero.
	&"dim_needle":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"keep_distance_m",
			"flee_distance_m",
			"dark_beyond_m",
		],
		"shape": 4,
		"shape_params":
		["count", "gap_seconds", "speed_mps", "radius_m", "range_m", "spread_degrees"],
	},
	## The Ember Charger: its charge leaves fire patches (radius trail_radius_m, every trail_step_seconds, lasting
	## trail_seconds) that burn the hero for burn_damage every burn_period_seconds once trail_arm_seconds old.
	&"ember_charger":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"charge_turn_dps",
			"trail_radius_m",
			"trail_seconds",
			"trail_step_seconds",
			"trail_arm_seconds",
			"burn_damage",
			"burn_period_seconds",
		],
		"shape": 2,
		"shape_params": ["length_m", "speed_mps"],
	},
	## The Frost Charger: its charge leaves ice slick patches; on one the hero eases over slick_ease_seconds (slides).
	&"frost_charger":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"charge_turn_dps",
			"trail_radius_m",
			"trail_seconds",
			"trail_step_seconds",
			"slick_ease_seconds",
		],
		"shape": 2,
		"shape_params": ["length_m", "speed_mps"],
	},
	## The Split Sniper: its shot splits into 3 at split_at_permille of its range, the outer two split_degrees out.
	&"split_sniper":
	{
		"params":
		[
			"attack_range_m",
			"cooldown_seconds",
			"keep_min_m",
			"keep_max_m",
			"split_at_permille",
			"split_degrees",
		],
		"shape": 2,
		"shape_params": ["range_m", "half_width_m"],
	},
	## v0.11.0 O13d (ENEMIES.md R9): the Star Warper marks a star mark_offset_m beside the hero, then after its windup
	## (1 s) blinks onto it and strikes a disc of radius_m; the hero standing within mark_radius_m of the star cancels
	## the blink and stuns it stun_seconds.
	&"star_warper":
	{
		"params":
		["attack_range_m", "cooldown_seconds", "mark_offset_m", "mark_radius_m", "stun_seconds"],
		"shape": 0,
		"shape_params": ["radius_m"],
	},
	## v0.11.0 O13d (ENEMIES.md R10): the Gravity Node, stationary and floating, no attack: every projectile within
	## pull_radius_m turns toward it (pull_mps2 at its centre, none at the reach), its speed kept.
	&"gravity_node": {"params": ["pull_radius_m", "pull_mps2"], "attacks": []},
}
## v0.11.0 O13a: a variant's base behaviour (it walks, aims and hits as its base: EnemyAi.behaviour_of).
const VARIANT_OF := {
	&"rubble_warden": &"warden",
	&"dim_needle": &"needle",
	&"ember_charger": &"charger",
	&"frost_charger": &"charger",
	&"split_sniper": &"sniper",
}


## v0.11.0 O13a: the behaviour `behaviour` runs (its base for a variant, else itself).
static func base_of(behaviour: StringName) -> StringName:
	return VARIANT_OF.get(behaviour, behaviour)
