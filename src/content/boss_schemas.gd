class_name BossSchemas
extends RefCounted
## The boss moves and the params each takes (PLAN v0.3.0 C; CONTENT_SCHEMA §4). Missing or unknown keys fail
## validation. Lives in content (the lowest layer) so validation can use it; the sim's BossAi implements each move.
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 1 CONE, 2 LINE, 3 RING, 4 PROJECTILE.

## The boss kinds, by boss id (each has its own actor kind and model).
const KINDS: Array[StringName] = [&"gatekeeper", &"brood_mother", &"siege_engine"]

## Arena interior templates, in FloorLayout.Template order (a test pins the match).
const ARENA_TEMPLATES: Array[String] = [
	"open", "scatter", "pillars", "centre", "cross", "lines", "bunkers"
]
## Arena size limits, in cells per side.
const ARENA_MAX_CELLS := 4

const MOVES := {
	## A ring of spikes around the boss, from inner_radius_m to radius_m (hugging it is safe).
	&"slam_ring": {"shape": 3, "params": ["inner_radius_m", "radius_m"]},
	## `count` straight shockwaves fanned toward the player, travelling along the ground over the active time.
	&"lanes": {"shape": 2, "params": ["count", "spread_degrees", "length_m", "width_m"]},
	## A melee arc in front.
	&"sweep": {"shape": 1, "params": ["arc_degrees", "reach_m"]},
	## A straight charge along a locked lane; touching the body hurts.
	&"charge": {"shape": 2, "params": ["length_m", "speed_mps"]},
	## Jumps onto the player's marked spot; `chain` leaps in a row.
	&"leap": {"shape": 0, "params": ["radius_m", "range_m", "chain"]},
	## Dives under, a ripple tracks the player, stops, and erupts after erupt_seconds (its own telegraph).
	&"burrow": {"shape": 0, "params": ["radius_m", "track_seconds", "erupt_seconds", "speed_mps"]},
	## Spits `count` eggs around itself; each lands on a marked disc and hatches an enemy (at most max_alive).
	&"brood": {"shape": 0, "params": ["count", "radius_m", "distance_m", "enemy_id", "max_alive"]},
	## Mortar shells on marked discs: the first on the player, the rest within spread_m of them.
	&"barrage": {"shape": 0, "params": ["count", "radius_m", "spread_m"]},
	## A beam that sweeps an arc toward the player over the active time.
	&"rail": {"shape": 1, "params": ["arc_degrees", "reach_m"]},
	## Volleys of bolts down `count` locked lines fanned toward the player.
	&"bolt_fan":
	{
		"shape": 4,
		"params":
		["count", "spread_degrees", "volleys", "gap_seconds", "speed_mps", "radius_m", "range_m"],
	},
	## Drops `count` turrets on marked discs beside itself (an enemy each).
	&"deploy": {"shape": 0, "params": ["count", "radius_m", "distance_m", "enemy_id"]},
	## Boss challenge (v0.3.0 BX): a vortex drags the player (within pull_range_m, at pull_mps) toward the boss for
	## its whole windup, then a ring of inner_radius_m..radius_m around it slams.
	&"pull": {"shape": 3, "params": ["inner_radius_m", "radius_m", "pull_mps", "pull_range_m"]},
}

## Params that name an enemy (resolved by the compiler; a content test checks they exist).
const ENEMY_PARAMS: Array[String] = ["enemy_id"]
