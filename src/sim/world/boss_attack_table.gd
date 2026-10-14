class_name BossAttackTable
extends RefCounted
## One boss attack in sim units (BossAttackDefinition compiled). Only the fields its move uses are set.

enum Move {
	SLAM_RING,
	LANES,
	SWEEP,
	CHARGE,
	LEAP,
	BURROW,
	BROOD,
	BARRAGE,
	RAIL,
	BOLT_FAN,
	DEPLOY,
	PULL,
	FLOOD,
	PATTERN,
	MARKS,
	ROW_LANES,
	GRID,
	ROW_FLOOD,
	GAZE,
	MELT,
}

var id := &""
var move := Move.SLAM_RING
var cause_key := &""
var windup_ticks := 24
var active_ticks := 1
var recover_ticks := 0
var cooldown_ticks := 0
var damage := 0
var min_range_m := 0.0
var max_range_m := 99.0
var weight := 1
## Counts: lanes, bolts, eggs, shells, turrets; leaps in a chain; volleys.
var count := 1
var chain := 1
var volleys := 1
var gap_ticks := 1
## Discs and rings: radius, inner radius; spawn spots' distance from the boss; a mortar's scatter.
var radius_m := 0.0
var inner_radius_m := 0.0
var distance_m := 0.0
var spread_m := 0.0
## Fans and arcs (1/4096 turns): the angle between two lanes, an arc's half width.
var spread := 0
var half_arc := 0
## Lengths and widths: a lane's or a charge's length, a sweep's reach, a lane's half width.
var length_m := 0.0
var reach_m := 0.0
var half_width_m := 0.0
## Speeds in metres per tick (a charge, a ripple, a bolt); a bolt's life in ticks.
var speed := 0.0
var bolt_life_ticks := 1
## Burrow: ticks the ripple tracks, then ticks its eruption is marked.
var track_ticks := 0
var erupt_ticks := 24
## Brood and deploy: the actor kind that comes out, and how many of them may be alive.
var enemy_kind := ActorStore.Kind.CHARGER
var max_alive := 99
## Boss challenge (v0.3.0 BX): a pull drags the player toward the boss during its windup at pull speed (metres per
## tick) from within pull_range_m; its recovery opens the weak point; a follow-up attack (index, -1 = none) may start
## at once instead of the recovery, follow_up_permille of the time.
var pull := 0.0
var pull_range_m := 0.0
var opens_weak := false
var follow_up := -1
var follow_up_permille := 0
## v0.4.0 BO: a flood's lanes stand gap_m apart (centre to centre) and hurt again every burn_ticks while active.
var gap_m := 0.0
var burn_ticks := 1
## v0.7.5 BF1 (owner N15, "Track, then lock 0.8 s"): a tracked attack follows the player's exact position until its
## last lock_ticks of windup (0 = the boss's track_commit rule, with lead), then holds; a `marks` or `row_lanes`
## attack's later markers start mark_gap_ticks apart, each with the same track and lock. A shielded attack (the
## signature pattern) keeps the boss shielded through its windup and active time (BossDodge.shielded). A `pattern`
## attack fires `pattern` (BulletPatterns) over its active time.
var lock_ticks := 0
var mark_gap_ticks := 0
var shielded := false
var pattern: BulletPatternTable = null
## v0.7.5 BF3: a `grid` attack's cells stand cell_m apart (centre to centre), `count` a side, struck in `volleys`
## alternating colours of the checkerboard, mark_gap_ticks apart.
var cell_m := 0.0
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S1): a `row_lanes` attack with pillar_ticks > 0 leaves stone pillars
## along its struck lanes (squares pillar_m a side, pillar_step_m apart from the crossing) that stand as walls for
## pillar_ticks (BossSignatures).
var pillar_ticks := 0
var pillar_m := 0.0
var pillar_step_m := 0.0
## v0.8.0 BS1 (S2): a `pattern` attack with recall_ticks > 0 throws javelins that stick where they stop and all fly
## back along their lines recall_at ticks after its active time began (the pattern's waves, their flight, then
## recall_ticks); its active time covers their way back too.
var recall_ticks := 0
var recall_at := 0
## v0.8.0 BS1 (S3): a `marks` attack with egg_ticks > 0 lays an egg (enemy_kind, egg_hp at the kind's base HP) on
## each circle as it strikes, up to max_alive of the kind; an egg hatches after egg_ticks, or from phase index
## burst_phase on bursts into the attack's pattern instead.
var egg_ticks := 0
var egg_hp := 0
var burst_phase := 99
## v0.8.0 BS1: the death line for the attack's late part (the javelins coming back, an egg's burst).
var late_cause_key := &""
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4): a `gaze` attack's beam turns a quarter turn (1024) every
## quarter_ticks from its start (aimed away from the player), reversing every reverse_ticks; it reaches length_m
## from the boss's edge (cut short by walls), half_width_m each side, and hurts once every burn_ticks. Its `pattern`
## (the orbs) fires again every orb_every_ticks from orb_every_ticks on (0 = none).
var quarter_ticks := 0
var reverse_ticks := 0
var orb_every_ticks := 0
## v0.8.0 BS2 (S5): a `pattern` attack's shots bounce off walls this many times (once); a `deploy` attack's turrets'
## shots bounce once from phase index bounce_phase on (99 = never).
var bounces := 0
var bounce_phase := 99
## v0.8.0 BS2 (S6): a `row_flood` attack's lanes leave molten floor for lava_ticks where they struck (lava_damage
## once every lava_burn_ticks to a player standing in it), every lane cut by fords ford_m wide (a lava-free way to
## the boss and to an exit). A `melt` attack melts the room's outer ring for good: everything farther from the room's
## centre than its inscribed radius less melt_ring_m, then melt_step_m closer every melt_step_ticks (each step glows
## melt_warn_ticks first), never closer than melt_min_m; it hurts its damage once every burn_ticks; a ford_m bridge
## to the exit stays cool.
var lava_ticks := 0
var lava_damage := 0
var lava_burn_ticks := 1
var ford_m := 0.0
var melt_ring_m := 0.0
var melt_min_m := 0.0
var melt_step_m := 0.0
var melt_step_ticks := 0
var melt_warn_ticks := 0
