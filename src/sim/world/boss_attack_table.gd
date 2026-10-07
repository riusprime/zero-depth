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
	FLOOD
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
