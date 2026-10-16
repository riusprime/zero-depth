class_name BossSchemas
extends RefCounted
## The boss moves and the params each takes (PLAN v0.3.0 C; CONTENT_SCHEMA §4). Missing or unknown keys fail
## validation. Lives in content (the lowest layer) so validation can use it; the sim's BossAi implements each move.
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 1 CONE, 2 LINE, 3 RING, 4 PROJECTILE.

## The boss kinds, by boss id (each has its own actor kind and model).
## v0.8.0 FB1: the final boss's three bodies (FinalBossDefinition, data/final_boss).
const KINDS: Array[StringName] = [
	&"gatekeeper",
	&"brood_mother",
	&"siege_engine",
	&"warlord",
	&"hive_lens",
	&"foundry",
	&"colossus",
	&"prism",
	&"nemesis",
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
	## v0.8.0 FB1: an optional pattern_id fires its first wave from where it lands (the Colossus's shockwave ring).
	&"leap": {"shape": 0, "params": ["radius_m", "range_m", "chain"], "optional": ["pattern_id"]},
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
	## v0.8.0 BS2 (S5): an optional bounce_phase (1-based) makes the turrets' shots bounce off walls once from that
	## phase on (the Siege Engine's phase 3).
	&"deploy":
	{
		"shape": 0,
		"params": ["count", "radius_m", "distance_m", "enemy_id"],
		"optional": ["bounce_phase"],
	},
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
	## v0.8.0 BS2 (S5): an optional bounces makes its shots bounce off walls that many times (the Siege Engine's
	## ricochet shells: once), never coming back onto the player within 0.5 s of the bounce.
	&"pattern": {"shape": 4, "params": ["pattern_id"], "optional": ["recall_seconds", "bounces"]},
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
	## v0.8.0 BS2 (owner O5, S6): with lava_seconds the lanes leave molten floor where they struck for that long
	## (lava_damage every lava_burn_seconds to a player standing in it; enemies path round it), each lane cut by fords
	## ford_m wide so a lava-free way to the boss and to an exit always stays.
	&"row_flood":
	{
		"shape": 2,
		"params": ["count", "gap_m", "length_m", "width_m", "burn_seconds"],
		"optional": ["lava_seconds", "lava_damage", "lava_burn_seconds", "ford_m"],
	},
	## v0.8.0 BS2 (owner O5, S4): the Hive Lens's Gaze: a beam from its eye, length_m long from its edge (stopped by
	## walls), width_m wide, starting aimed away from the player (it keeps away through the windup: the eye
	## brightens, a thin aim line shows), then turning a quarter turn every quarter_seconds, reversing every
	## reverse_seconds, over the active time; it hurts once every burn_seconds. An optional pattern_id fires again
	## every orb_every_seconds (its orbs, aimed at the player).
	&"gaze":
	{
		"shape": 2,
		"params": ["length_m", "width_m", "quarter_seconds", "reverse_seconds", "burn_seconds"],
		"optional": ["pattern_id", "orb_every_seconds"],
	},
	## v0.8.0 BS2 (owner O5, S6): the Foundry's meltdown: after its windup (a roar and the outer ring glowing) the
	## room's outer ring_m melts for good (everything farther from the room's centre than its inscribed radius less
	## ring_m); every step_seconds it melts step_m closer (each step glows warn_seconds first), never closer than
	## min_radius_m. Standing in it hurts the attack's damage every burn_seconds; a bridge ford_m wide to the room's
	## exit stays cool.
	&"melt":
	{
		"shape": 3,
		"params":
		[
			"ring_m",
			"min_radius_m",
			"step_m",
			"step_seconds",
			"warn_seconds",
			"burn_seconds",
			"ford_m"
		],
	},
	## v0.8.0 FB1 (owner O17; FINAL_BOSS.md F4; BossColossus): the Colossus's fist combo: `count` swings (an arc of
	## arc_degrees, reach_m past its edge) that follow the player (it steps in at speed_mps) until the attack's lock,
	## stagger_seconds apart, then a ground slam (a circle of radius_m round its feet), tracked and locked the same way.
	&"combo":
	{
		"shape": 1,
		"params": ["count", "arc_degrees", "reach_m", "radius_m", "speed_mps", "stagger_seconds"],
	},
	## v0.8.0 FB1: `count` (1-2) lines of `steps` stone spikes chasing the player: each spike step_m on from the one
	## before toward where the player is, stagger_seconds apart, shown for the lock before it erupts (radius_m); the
	## lines start spread_degrees apart round the aim; a line ends at a wall.
	&"spike_chase":
	{
		"shape": 0,
		"params": ["count", "steps", "step_m", "radius_m", "stagger_seconds", "spread_degrees"],
	},
	## v0.8.0 FB1: `count` rays of spikes out of the boss, aimed between the rays at the player; `steps` rings step_m
	## apart, stagger_seconds apart, each shown for the lock before it erupts (radius_m).
	&"spike_burst":
	## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5, F7; BossPrism): the Prism's Cross: `count` beams in a plus from her
	## edge (length_m, width_m, stopped by walls). Through the windup thin aim lines keep the player midway between
	## two arms; then the beams turn a quarter turn every quarter_seconds at full HP, down to fast_quarter_seconds at
	## none, reversing every reverse_seconds, for spin_seconds, hurting once every burn_seconds; then a window of
	## window_seconds with the beams out and the shield down (the attack is shielded otherwise; active_seconds is at
	## least spin + window). An optional pattern_id fires every orb_every_seconds from her orbiting shards while the
	## beams turn; an optional bolt_attack (a `bolt_fan` of the same boss, its lock the aim line's time) fires a fast
	{"shape": 0, "params": ["count", "steps", "step_m", "radius_m", "stagger_seconds"]},
	## bolt from a shard every bolt_every_seconds.
	&"cross":
	{
		"shape": 2,
		"params":
		[
			"count",
			"length_m",
			"width_m",
			"quarter_seconds",
			"fast_quarter_seconds",
			"reverse_seconds",
			"burn_seconds",
			"spin_seconds",
			"window_seconds",
		],
		"optional": ["pattern_id", "orb_every_seconds", "bolt_attack", "bolt_every_seconds"],
	},
	## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards"; FINAL_BOSS.md F6; BossNemesis): the Nemesis's moves. An optional
	## `weapon` ("blade", "gun" or "any", the default) keeps an attack to the runs of that weapon.
	## `count` of the player's own combo steps in order (each its arc and reach; arc_degrees and reach_m without a
	## combo), stagger_seconds apart, each following the player (stepping in at speed_mps) until the lock, then held.
	&"mimic_combo":
	{
		"shape": 1,
		"params": ["count", "arc_degrees", "reach_m", "speed_mps", "stagger_seconds"],
		"optional": ["weapon"],
	},
	## `volleys` of the run's ranged form gap_seconds apart down the lines locked at the lock: a Gun run's own shot (its
	## cards on it), a Blade run's thrown crescents (`count` of them spread_degrees apart when its wand throws none;
	## speed_mps and radius_m optional).
	&"mimic_shots":
	{
		"shape": 4,
		"params": ["count", "spread_degrees", "volleys", "gap_seconds"],
		"optional": ["weapon", "speed_mps", "radius_m"],
	},
	## The player's card `card` (0 = the strongest held, then 1, 2) as the Nemesis's own attack: its arc (repeats
	## stagger_seconds apart), its volley and its blast, tracked then locked.
	&"card_cast": {"shape": 0, "params": ["card", "stagger_seconds"], "optional": ["weapon"]},
}
## v0.8.0 FB3: the runs an attack's `weapon` may name.
const WEAPONS: Array[String] = ["any", "blade", "gun"]
## v0.8.0 FB3: the most cards the Nemesis casts (its card_cast attacks' `card` is below it).
const MAX_CARD_CASTS := 3

## v0.7.5 BF1: moves that need a lock (BossAttackDefinition.lock_seconds > 0): their markers track, then lock.
## v0.8.0 FB1: the Colossus's combo and spikes (0.5 s locks as shipped).
## v0.8.0 FB3: and the Nemesis's three.
const LOCKED_MOVES: Array[StringName] = [
	&"marks",
	&"row_lanes",
	&"grid",
	&"row_flood",
	&"combo",
	&"spike_chase",
	&"spike_burst",
	&"mimic_combo",
	&"mimic_shots",
	&"card_cast",
]
## v0.8.0 FB1: the most spikes a line or a ray lays (steps).
const MAX_STEPS := 16
## v0.8.0 FB2 (F7): the most seconds the final fight's damage meter holds (FinalFight's ring).
const DPS_MAX_SECONDS := 60
## v0.8.0 BP (owner O27): how big a boss hit is (BossAttackDefinition.hit_class) and how many of them kill the hero at
## the data's damage (loop 1, before the floor, Deep, catch-up and loop factors, which scale every class alike):
## small orbs and shots 4-5, medium strikes 3-4, big attacks 2. Inclusive [min, max].
const HIT_CLASSES := {&"small": [4, 5], &"medium": [3, 4], &"big": [2, 2]}
## v0.8.0 BP (owner O27, "not making them unkillable by the blade"): after a big attack the boss recovers, still, for
## this window (ticks, after its recovery_permille): starting values 0.6..0.9 s.
const PUNISH_MIN_TICKS := 36
const PUNISH_MAX_TICKS := 54
## v0.7.5 BF1: params that name a bullet pattern (resolved by the compiler; a content test checks they exist).
const PATTERN_PARAMS: Array[String] = ["pattern_id"]

## Params that name an enemy (resolved by the compiler; a content test checks they exist).
const ENEMY_PARAMS: Array[String] = ["enemy_id"]


## v0.8.0 BP: the hits of `damage` that kill a hero of `hp` (rounded up; a damage under 1 counts as 1).
static func hits_to_kill(hp: int, damage: int) -> int:
	return (hp + maxi(1, damage) - 1) / maxi(1, damage)
