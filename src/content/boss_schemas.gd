class_name BossSchemas
extends RefCounted
## The boss moves and the params each takes (PLAN v0.3.0 C; CONTENT_SCHEMA §4). Missing or unknown keys fail
## validation. Lives in content (the lowest layer) so validation can use it; the sim's BossAi implements each move.
## Shapes are AttackDefinition.Shape values: 0 CIRCLE, 1 CONE, 2 LINE, 3 RING, 4 PROJECTILE.

## The boss kinds, by boss id (each has its own actor kind and model).
## The final boss's three bodies (FinalBossDefinition, data/final_boss).
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
	&"tidecaller",  # Floor 4 (BOSSES_4_5.md N1)
	&"twin_wardens",  # Floor 4 (BOSSES_4_5.md N2): the amber body's kind (its twin's: BossDefinition)
	&"clockwork_judge",  # Floor 5 (BOSSES_4_5.md N3)
	&"lantern_shade",  # Floor 5 (BOSSES_4_5.md N4)
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
	&"lanes":
	{
		"shape": 2,
		"params": ["count", "spread_degrees", "length_m", "width_m"],
		"optional": ["turn_dps"],  # The Focus Beam burns, turning toward the player
	},
	## A melee arc in front.
	&"sweep": {"shape": 1, "params": ["arc_degrees", "reach_m"]},
	## A straight charge along a locked lane; touching the body hurts.
	&"charge": {"shape": 2, "params": ["length_m", "speed_mps"]},
	## Jumps onto the player's marked spot; `chain` leaps in a row.
	## An optional pattern_id fires its first wave from where it lands (the Colossus's shockwave ring).
	&"leap":
	{
		"shape": 0,
		"params": ["radius_m", "range_m", "chain"],
		"optional": ["pattern_id", "last_lead_seconds", "last_radius_bonus_permille"],  # v0.9.5 BH2
	},
	## Dives under, a ripple tracks the player, stops, and erupts after erupt_seconds (its own telegraph).
	## With lock_seconds its eruption circle follows the player's exact position while it tracks, then
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
	## An optional bounce_phase (1-based) makes the turrets' shots bounce off walls once from that
	## phase on (the Siege Engine's phase 3).
	&"deploy":
	{
		"shape": 0,
		"params": ["count", "radius_m", "distance_m", "enemy_id"],
		"optional": ["bounce_phase"],
	},
	## Boss challenge: a vortex drags the player (within pull_range_m, at pull_mps) toward the boss for
	## its whole windup, then a ring of inner_radius_m..radius_m around it slams.
	&"pull": {"shape": 3, "params": ["inner_radius_m", "radius_m", "pull_mps", "pull_range_m"]},
	## `count` parallel lanes gap_m apart, centred on the line toward the player, marked for the windup;
	## then for the whole active time the lanes stay (the Warlord's spears, the Foundry's molten floor) and hurt
	## a player standing in them once every burn_seconds.
	&"flood": {"shape": 2, "params": ["count", "gap_m", "length_m", "width_m", "burn_seconds"]},
	## Fires a bullet pattern (data/bullet_patterns, by id) over the active time: slow fireballs
	## in a shape (BulletPatterns). A BURST pattern's shell lands on the target its windup tracked.
	## An optional recall_seconds makes its shots javelins that stick where they stop and
	## all fly back along their lines recall_seconds after the last could have landed (the Warlord's Javelin Fan).
	## An optional bounces makes its shots bounce off walls that many times (the Siege Engine's
	## ricochet shells: once), never coming back onto the player within 0.5 s of the bounce.
	## An optional aim_degrees fires every wave from that fixed angle
	## (the world's frame, 0 = +x) instead of at the player (the Prism's orb spells).
	&"pattern":
	{
		"shape": 4,
		"params": ["pattern_id"],
		"optional":
		[
			"recall_seconds",
			"bounces",
			"aim_degrees",
			"lead_seconds",  # The Javelin Fan's first fan leads, the next aims at you
			"hard",  # Marks the Furnace Waves and the Gear Spiral for the 0.55 s rule (HardRules)
			"dark_seconds",  # The Lantern Shade's Lights Out (ShadeRules.LIGHT_PARAMS)
			"dark_lasts_seconds",  # How long its dark lasts
			"light_lasts_seconds",  # How long the light lasts before the dark falls again
			"dark_mult_permille",  # The Shade's damage taken in the dark
			"lit_mult_permille",  # And in a lit lantern's pool
			"light_m",
			"lamps",
			"lamp_m",
			"lamp_seconds",
			"relight_m",
			"inset_m",
			"twin_look",  # The Twin Wardens' standing-back bolt from the violet twin (its own colour)
		]
	},
	## `count` ground circles, stagger_seconds apart, each following the player's exact position until
	## the attack's lock_seconds, then locked and flashing until it strikes (BOSS_FIGHTS.md rule 1).
	## An optional pattern_id makes each circle an egg's landing (the Brood Mother's Egg Storm): a shell
	## lobbed onto it while it is locked, and the pattern (a BURST's star) bursting from it as it strikes.
	## With egg_seconds each landing lays an egg instead (enemy_id, egg_hp, at most max_alive of the
	## kind) that hatches after egg_seconds, or from phase burst_phase (1 = the first) bursts into the pattern.
	&"marks":
	{
		"shape": 0,
		"params": ["count", "radius_m", "stagger_seconds"],
		"optional":
		[
			"pattern_id",
			"egg_seconds",
			"egg_hp",
			"enemy_id",
			"max_alive",
			"burst_phase",
			"drag_m",  # The Undertow (BossTide)
			"drag_reach_m",
			"snuff",  # The Snuff puts out the nearest lantern (BossShade)
		],
	},
	## `count` crosses of two lanes (the player's row and column, length_m long), stagger_seconds apart,
	## tracked then locked like `marks`; cut short by walls.
	## With pillar_seconds the struck lanes leave stone pillars (pillar_m a side,
	## pillar_step_m apart) that stand as walls for pillar_seconds (the Gatekeeper's Stone Spikes that stay).
	&"row_lanes":
	{
		"shape": 2,
		"params": ["count", "length_m", "width_m", "stagger_seconds"],
		"optional":
		["pillar_seconds", "pillar_m", "pillar_step_m", "second_seconds", "second_offset_m"],  # BH2
	},
	## A checkerboard of `count` × `count` ground circles (count odd; radius_m each, cell_m apart) centred
	## on the player's exact position until the attack's lock_seconds, then locked; `volleys` strikes stagger_seconds
	## apart, alternating the board's two colours (the first holds the player's cell). Each colour shows only for
	## its own lock before it strikes.
	&"grid":
	{
		"shape": 0,
		"params": ["count", "cell_m", "radius_m", "volleys", "stagger_seconds"],
		"optional": ["safe_cells"],  # Every volley strikes all but these cells
	},
	## `count` lanes along the room's rows (x), gap_m apart and centred on the player's row, length_m
	## long centred on the player (cut short by walls); tracked then locked like `marks`, then standing for the
	## active time and hurting once every burn_seconds, like `flood` (the Foundry's molten floor).
	## With lava_seconds the lanes leave molten floor where they struck for that long
	## (lava_damage every lava_burn_seconds to a player standing in it; enemies path round it), each lane cut by fords
	## ford_m wide so a lava-free way to the boss and to an exit always stays.
	&"row_flood":
	{
		"shape": 2,
		"params": ["count", "gap_m", "length_m", "width_m", "burn_seconds"],
		"optional": ["lava_seconds", "lava_damage", "lava_burn_seconds", "ford_m"],
	},
	## The Hive Lens's Gaze: a beam from its eye, length_m long from its edge (stopped by
	## walls), width_m wide, starting just behind the player in its turn (v0.10.5 W3-O2; it keeps so through the
	## windup: the eye brightens, a thin aim line shows), then turning a quarter turn every quarter_seconds,
	## reversing every reverse_seconds, over the active time; it hurts once every burn_seconds. An optional pattern_id
	## fires again every orb_every_seconds (its orbs, aimed at the player).
	&"gaze":
	{
		"shape": 2,
		"params": ["length_m", "width_m", "quarter_seconds", "reverse_seconds", "burn_seconds"],
		"optional": ["pattern_id", "orb_every_seconds"],
	},
	## The Foundry's meltdown: after its windup (a roar and the outer ring glowing) the
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
	## The Colossus's fist combo: `count` swings (an arc of
	## arc_degrees, reach_m past its edge) that follow the player (it steps in at speed_mps) until the attack's lock,
	## stagger_seconds apart, then a ground slam (a circle of radius_m round its feet), tracked and locked the same way.
	&"combo":
	{
		"shape": 1,
		"params": ["count", "arc_degrees", "reach_m", "radius_m", "speed_mps", "stagger_seconds"],
	},
	## `count` (1-2) lines of `steps` stone spikes chasing the player: each spike step_m on from the one
	## before toward where the player is, stagger_seconds apart, shown for the lock before it erupts (radius_m); the
	## lines start spread_degrees apart round the aim; a line ends at a wall.
	&"spike_chase":
	{
		"shape": 0,
		"params": ["count", "steps", "step_m", "radius_m", "stagger_seconds", "spread_degrees"],
	},
	## `count` rays of spikes out of the boss, aimed between the rays at the player; `steps` rings step_m
	## apart, stagger_seconds apart, each shown for the lock before it erupts (radius_m).
	&"spike_burst":
	## The Prism's Cross: `count` beams in a plus from her
	## edge (length_m, width_m, stopped by walls). Through the windup thin aim lines keep the player midway between
	## two arms; then the beams turn a quarter turn every quarter_seconds at full HP, down to fast_quarter_seconds at
	## none, reversing every reverse_seconds, for spin_seconds, hurting once every burn_seconds; then a window of
	## window_seconds with the beams out and the shield down (the attack is shielded otherwise; active_seconds is at
	## least spin + window). An optional bolt_attack (a `bolt_fan` of the same boss, its lock the aim line's time)
	## fires a fast bolt from a shard every bolt_every_seconds through the window (v0.8.0 PR, owner O84: only then,
	{"shape": 0, "params": ["count", "steps", "step_m", "radius_m", "stagger_seconds"]},
	## with the beams out; a Cross fires no orbs).
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
		"optional": ["bolt_attack", "bolt_every_seconds"],
	},
	## The Nemesis's moves. An optional
	## `weapon` ("blade", "gun" or "any", the default) keeps an attack to the runs of that weapon (in a mimic window,
	## v0.8.0 N2; outside one every non-card attack is its own kit), "own" to outside the windows only.
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
	## BOSSES_4_5.md N1; BossTide: the Tidecaller's Pull, its shielded signature. After its windup (the bell
	## rings) the room pulls the player toward it at pull_mps for pull_seconds (its pattern, the Tide Rings, fires
	## inside the pull, and its shots bend toward it at bend_dps), then pushes them out at push_mps for push_seconds
	## (no ring spawns); its active time is the two. Never faster than TIDE_MAX_MPS, never pressing the player toward
	## a wall. (A `marks` attack with drag_m, the Undertow, drags a player within drag_reach_m of each struck circle
	## drag_m toward its centre.)
	&"tide":
	{
		"shape": 4,
		"params": ["pull_mps", "push_mps", "pull_seconds", "push_seconds", "bend_dps"],
		# The rings run all fight (BossStream), so the Pull has none of its own; max_mps: the most
		# it moves the player (<= TIDE_MAX_MPS)
		"optional": ["pattern_id", "max_mps"],
	},
	## BOSSES_4_5.md N2; BossTwin: the Twin Wardens' Crossfire, their shielded signature pattern. Each body
	## fires its pattern (a fan) at a safe spot distance_m off the middle of their chain on the player's side, leaving
	## out the shots within gap_m of the spot there, so the two gaps cross only at the spot, between them. twin_look:
	## the look of the twin's shots (its own colour; the pattern's look is the boss's).
	&"crossfire":
	## The Chain Sweep: the boss's line from its body through the player and reach_m past them (held to the
	## chain's lengths, cut short by walls) tracks them until the lock, then the chain lashes a lane width_m wide along
	{
		"shape": 4,
		"params": ["pattern_id", "gap_m", "distance_m"],
		"optional": ["twin_look", "lines_follow_seconds", "lines_turn_dps"],  # The lines follow you
	},
	## it; the twin swings to the line's end. A lock is required; its late_cause_key names the chain's burn.
	&"chain_sweep": {"shape": 2, "params": ["width_m", "reach_m"]},
	## BOSSES_4_5.md N3; BossJudge: the Clockwork Judge's echo, its shielded signature on its cadence. The
	## Judge records where the player walked, a point every step_seconds over the last record_seconds; as the echo
	## starts the path locks and shows for its windup, then a ghost strike lands on each point in the order walked,
	## step_seconds apart (radius_m each). A point within radius_m + the player's radius + safe_m of where the player
	## stands as it starts is left out.
	&"echo": {"shape": 4, "params": ["radius_m", "record_seconds", "step_seconds", "safe_m"]},
	## The Verdict: a square half_m each way from its centre (not a circle) follows the player, locks, and a
	## pendulum strike drops on it. A lock is required.
	&"verdict": {"shape": 2, "params": ["half_m"]},
	## BOSSES_HARD.md T3; BossStream: the Tidecaller's crossing wave, in no attack list. A phase's
	## wave_attack forms one every wave_every_seconds. lengths_m: the lengths one is drawn from; thickness_m; speed_mps
	## across the room after the telegraph (a foam line at the wall); shove_m along its travel when it hits; clear_m: it
	## never forms within that of the hero's projection on its wall.
	&"wave":
	## BOSSES_HARD.md HC5; BossInterphase: a carrier of the Fallen's interphase hits, in no attack list: its
	## damage, telegraph and recap cause belong to the hazards (fallen_rays, fallen_rain, fallen_dark, fallen_erupt,
	{"shape": 2, "params": ["lengths_m", "thickness_m", "speed_mps", "shove_m", "clear_m"]},
	## fallen_return).
	&"interphase": {"shape": 2, "params": []},
	## The Prism's Facet Lances: `count`
	## lances stagger_seconds apart, each from a rim spot distance_m from her (spread_degrees apart round her, the first
	## on the player's side) through the player: it follows them for track_seconds, holds for the attack's lock, then
	## strikes for strike_seconds as a lane width_m wide, as far as length_m or a wall. A lock is required.
	&"lances":
	{
		"shape": 2,
		"params":
		[
			"count",
			"stagger_seconds",
			"track_seconds",
			"strike_seconds",
			"distance_m",
			"spread_degrees",
			"length_m",
			"width_m",
		],
	},
	## The Warlord's great javelin: thrown at the hero (speed_mps, radius_m, its
	## line and landing tracked, then held for the attack's lock), it hurts on the way, embeds at the point (or the first
	## wall) for embed_seconds and quakes: a ring of ring_m round it every pulse_seconds (warned warn_seconds, the hero's
	## max HP per mille pulse_permille). Then a recall_warn_seconds line to the boss, and it flies back at
	## recall_speed_mps.
	&"great_javelin":
	{
		"shape": 4,
		"params":
		[
			"speed_mps",
			"radius_m",
			"range_m",
			"embed_seconds",
			"ring_m",
			"pulse_seconds",
			"warn_seconds",
			"pulse_permille",
			"recall_warn_seconds",
			"recall_speed_mps",
		],
	},
	## L6: "Needs something cooler while he's down": the Prism's Shattered Kneel: down (open, nothing
	## fired) for its active time; hits from within the weak point's range of her edge deal core_mult_permille; once
	## she has lost crack_permille of her max HP since it began, her core bursts for burst_permille of it and she rises.
	&"kneel": {"shape": 0, "params": ["crack_permille", "burst_permille", "core_mult_permille"]},
}
## The runs an attack's `weapon` may name.
## "own" is The Fallen's own kit, only outside its mimic windows.
const WEAPONS: Array[String] = ["any", "blade", "gun", "own"]
## The most cards the Nemesis casts (its card_cast attacks' `card` is below it).
const MAX_CARD_CASTS := 3

## Moves that need a lock (BossAttackDefinition.lock_seconds > 0): their markers track, then lock.
## The Colossus's combo and spikes (0.5 s locks as shipped).
## And the Nemesis's three.
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
	&"chain_sweep",  # v0.9.0 NB2
	&"verdict",  # v0.9.0 NB3
	&"lances",  # The Facet Lances (each lance's lock)
	&"great_javelin",  # The throw's line
]
## The most spikes a line or a ray lays (steps).
const MAX_STEPS := 16
## The most seconds the final fight's damage meter holds (FinalFight's ring).
const DPS_MAX_SECONDS := 60
## How big a boss hit is (BossAttackDefinition.hit_class) and how many of them kill the hero at
## the data's damage (loop 1, before the floor, Deep, catch-up and loop factors, which scale every class alike):
## small orbs and shots 4-5, medium strikes 3-4, big attacks 2. Inclusive [min, max].
const HIT_CLASSES := {&"small": [4, 5], &"medium": [3, 4], &"big": [2, 2]}
## After a big attack the boss recovers, still, for
## this window (ticks, after its recovery_permille): starting values 0.6..0.9 s.
const PUNISH_MIN_TICKS := 36
const PUNISH_MAX_TICKS := 54
## BOSSES_4_5.md N1; v0.9.5 BH4: 1.5 -> 2.2 m/s: the most a tide attack may be set to move the player.
const TIDE_MAX_MPS := 2.2
## BOSSES_4_5.md N2: "the chain is never shorter than 3 m or longer than 9 m": the bounds a twin boss's
## chain lengths keep, and the most its anger may speed a body (per mille).
## The twins a boss may rise with (BossDefinition.twin_kind_id; PatternCompiler maps each to its actor kind).
const TWIN_KINDS: Array[StringName] = [&"twin_warden_violet"]
const TWIN_CHAIN_MIN_M := 3.0
const TWIN_CHAIN_MAX_M := 9.0
const TWIN_ANGER_MAX_PERMILLE := 2000
## BOSSES_4_5.md N3: the most points an echo records (record_seconds / step_seconds).
const ECHO_MAX_POINTS := 24
## Params that name a bullet pattern (resolved by the compiler; a content test checks they exist).
const PATTERN_PARAMS: Array[String] = ["pattern_id"]

## Params that name an enemy (resolved by the compiler; a content test checks they exist).
const ENEMY_PARAMS: Array[String] = ["enemy_id"]


## The hits of `damage` that kill a hero of `hp` (rounded up; a damage under 1 counts as 1).
static func hits_to_kill(hp: int, damage: int) -> int:
	return (hp + maxi(1, damage) - 1) / maxi(1, damage)
