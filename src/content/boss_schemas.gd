class_name BossSchemas
extends RefCounted
## The boss moves and the params each takes (PLAN v0.3.0 C; CONTENT_SCHEMA §4). Missing or unknown keys fail
## validation. Lives in content (the lowest layer) so validation can use it; the sim's BossAi implements each move.
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 1 CONE, 2 LINE, 3 RING, 4 PROJECTILE.

## The boss kinds, by boss id (each has its own actor kind and model).
const KINDS: Array[StringName] = [
	&"gatekeeper", &"brood_mother", &"siege_engine", &"warlord", &"hive_lens", &"foundry"
]

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
	## v0.7.5 BF2: with lock_seconds its eruption circle follows the player's exact position while it tracks, then
	## holds for the lock; an optional pattern_id (a RING) bursts from the eruption.
	&"burrow":
	{
		"shape": 0,
		"params": ["radius_m", "track_seconds", "erupt_seconds", "speed_mps"],
		"optional": ["pattern_id"],
	},
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
	## v0.4.0 BO: `count` parallel lanes gap_m apart, centred on the line toward the player, marked for the windup;
	## then for the whole active time the lanes stay (the Warlord's spears, the Foundry's molten floor) and hurt
	## a player standing in them once every burn_seconds.
	&"flood": {"shape": 2, "params": ["count", "gap_m", "length_m", "width_m", "burn_seconds"]},
	## v0.7.5 BF1 (owner N15): fires a bullet pattern (data/bullet_patterns, by id) over the active time: slow fireballs
	## in a shape (BulletPatterns). A BURST pattern's shell lands on the target its windup tracked.
	## v0.8.0 BS1 (owner O5, S2): an optional recall_seconds makes its shots javelins that stick where they stop and
	## all fly back along their lines recall_seconds after the last could have landed (the Warlord's Javelin Fan).
	&"pattern": {"shape": 4, "params": ["pattern_id"], "optional": ["recall_seconds"]},
	## v0.7.5 BF1: `count` ground circles, stagger_seconds apart, each following the player's exact position until
	## the attack's lock_seconds, then locked and flashing until it strikes (BOSS_FIGHTS.md rule 1).
	## v0.7.5 BF2: an optional pattern_id makes each circle an egg's landing (the Brood Mother's Egg Storm): a shell
	## lobbed onto it while it is locked, and the pattern (a BURST's star) bursting from it as it strikes.
	## v0.8.0 BS1 (S3): with egg_seconds each landing lays an egg instead (enemy_id, egg_hp, at most max_alive of the
	## kind) that hatches after egg_seconds, or from phase burst_phase (1 = the first) bursts into the pattern.
	&"marks":
	{
		"shape": 0,
		"params": ["count", "radius_m", "stagger_seconds"],
		"optional": ["pattern_id", "egg_seconds", "egg_hp", "enemy_id", "max_alive", "burst_phase"],
	},
	## v0.7.5 BF1: `count` crosses of two lanes (the player's row and column, length_m long), stagger_seconds apart,
	## tracked then locked like `marks`; cut short by walls.
	## v0.8.0 BS1 (owner O5, S1): with pillar_seconds the struck lanes leave stone pillars (pillar_m a side,
	## pillar_step_m apart) that stand as walls for pillar_seconds (the Gatekeeper's Stone Spikes that stay).
	&"row_lanes":
	{
		"shape": 2,
		"params": ["count", "length_m", "width_m", "stagger_seconds"],
		"optional": ["pillar_seconds", "pillar_m", "pillar_step_m"],
	},
	## v0.7.5 BF3: a checkerboard of `count` × `count` ground circles (count odd; radius_m each, cell_m apart) centred
	## on the player's exact position until the attack's lock_seconds, then locked; `volleys` strikes stagger_seconds
	## apart, alternating the board's two colours (the first holds the player's cell). Each colour shows only for
	## its own lock before it strikes.
	&"grid": {"shape": 0, "params": ["count", "cell_m", "radius_m", "volleys", "stagger_seconds"]},
	## v0.7.5 BF3: `count` lanes along the room's rows (x), gap_m apart and centred on the player's row, length_m
	## long centred on the player (cut short by walls); tracked then locked like `marks`, then standing for the
	## active time and hurting once every burn_seconds, like `flood` (the Foundry's molten floor).
	&"row_flood": {"shape": 2, "params": ["count", "gap_m", "length_m", "width_m", "burn_seconds"]},
}

## v0.7.5 BF1: moves that need a lock (BossAttackDefinition.lock_seconds > 0): their markers track, then lock.
const LOCKED_MOVES: Array[StringName] = [&"marks", &"row_lanes", &"grid", &"row_flood"]
## v0.7.5 BF1: params that name a bullet pattern (resolved by the compiler; a content test checks they exist).
const PATTERN_PARAMS: Array[String] = ["pattern_id"]

## Params that name an enemy (resolved by the compiler; a content test checks they exist).
const ENEMY_PARAMS: Array[String] = ["enemy_id"]
