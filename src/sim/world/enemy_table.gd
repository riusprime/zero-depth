class_name EnemyTable
extends RefCounted
## One enemy kind's compiled numbers in sim units (metres, metres per tick, ticks, 1/4096 turns). Built from
## EnemyDefinition by the content compiler (v0.1.0 Step 4).

var kind := ActorStore.Kind.CHARGER
## The name's locale key (the dev panel shows it; v0.3.5 AI).
var name_key := &""
var hp := 1
var radius_m := 0.4
var speed := 0.0
## The attack: start range, cooldown after recovery, windup (the telegraph), active and recovery ticks, damage.
var attack_range_m := 0.0
var cooldown_ticks := 0
var windup_ticks := 24
## v0.3.5 AI: each attack's windup is drawn from windup_ticks..windup_max_ticks (the ai:enemy stream).
var windup_max_ticks := 24
var active_ticks := 1
var recover_ticks := 0
var damage := 0
## Economy (v0.3.0 E): shards per kill, scaled by the danger tier, or by the floor number when shards_by_floor.
var shards := 0
var shards_by_floor := false
## v0.10.5 O10 (Matchups): the form or element id it is weak to and the one it resists (&"": none), per mille.
var weak_to := &""
var resists := &""
var weak_permille := 1000
var resist_permille := 1000
## Charger.
var charge_speed := 0.0
var charge_distance_m := 0.0
## Warden: armour by the direction a hit comes from (1/4096 turns either side of facing, per-mille multipliers).
var front_half_arc := 0
var front_mult_permille := 1000
var rear_half_arc := 0
var rear_mult_permille := 1000
var turn_rate := 0
## The Warden's slam radius; also the Bomb Drone's bomb circle (v0.3.5 AI), whose fuse is its windup.
var slam_radius_m := 0.0
## Needle (and the Arc Caster's bolt). A burst's shots fan burst_spread (1/4096 turns) apart (v0.3.5 AI).
var keep_distance_m := 0.0
var flee_distance_m := 0.0
var burst_count := 0
var burst_gap_ticks := 1
var bolt_speed := 0.0
var bolt_radius_m := 0.12
var bolt_life_ticks := 120
var burst_spread := 0
## Ranged aim (v0.3.5 AI): shots lead the player by its velocity for their flight time, up to this many ticks.
var lead_max_ticks := 30
## Charger and hatchling (v0.3.5 AI): how fast a charge may turn toward the player, in 1/4096 turns per tick.
var charge_turn := 0
## Arc Caster (v0.3.5 AI): it keeps keep_min_m..keep_distance_m away and picks a spell by weight (bolt, spread,
## rune). Bolt: speed, radius, life; the spread's bolts (count, the angle between two, speed, life); the rune's
## radius and windup. The bolt and the spread wind up for windup_ticks.
var keep_min_m := 0.0
var spell_weights := PackedInt32Array()
var spread_count := 3
var spread_angle := 0
var spread_speed := 0.0
var spread_radius_m := 0.12
var spread_life_ticks := 1
var rune_radius_m := 0.0
var rune_windup_ticks := 24
## Horde kinds (v0.4.0 EN). A melee reach: a Splitter's swipe centre sits reach_m ahead of it, a Shield Bearer's
## bash lane runs reach_m past its body, a Sniper's line is reach_m long; lanes are lane_half_m either side.
var reach_m := 0.0
var lane_half_m := 0.0
## Splitter: how many Splitlings it splits into when it dies (once: a Splitling never splits).
var split_count := 0
## Mender: heal_amount HP to one hurt ally within heal_range_m every heal_period_ticks.
var heal_amount := 0
var heal_period_ticks := 1
var heal_range_m := 0.0
## Mine Layer: mines alive at once, an idle mine's life, and an armed mine's fuse (its circle's radius is
## slam_radius_m; its windup_ticks is the drop).
var max_mines := 0
var mine_life_ticks := 0
var fuse_ticks := 24
## v0.7.5 EF (owner N16): the slow fireball pattern each attack fires, by attack index (null where an attack fires
## none; empty for kinds with none): the Arc Caster's bolt and spread (fans of plasma balls), the Lens Drone's ring
## of orbs, the Bomb Drone's lobbed fireball that bursts into an X. EnemyAi.pattern_of picks the one in play.
var patterns: Array[BulletPatternTable] = []
## v0.9.0 EL: an elite archetype's ability and plain attack (EliteAi); null for every other kind.
var elite: EliteTable
## v0.11.0 O9 (PLAN H1; owner Q14): a horde critter's touch (EnemyAi.is_critter): `damage` (its contact_damage) on
## touching the hero, at most every contact_cd_ticks (the critter's own clock, ActorStore.cd); no windup, no attack.
## `flies`: it flies low (the Cave Bat), so the floor's hazards (EnemyAi.flies) never reach it.
var contact_cd_ticks := 30
var flies := false
## v0.11.0 O13a (ENEMIES.md V1-V5; owner Q23): a biome variant's own numbers (Variants; the defaults on every other
## kind). The Rubble Warden: its crust (already in `hp`) falls at half HP into crust_pieces rocks of cover (half side
## piece_half_m). The Dim Needle: its shots stay dark farther than dark_beyond_m from the hero. The Ember and Frost
## Chargers: their charge drops a `trail` patch (Variants.TRAIL_FIRE or TRAIL_SLICK) of trail_radius_m every
## trail_step_ticks, lasting trail_ticks; fire burns the hero for burn_damage every burn_period_ticks once
## trail_arm_ticks old; on a slick the hero eases at slick_permille a tick (a slide). The Split Sniper: its shot splits
## into 3 at split_at_permille of its reach, the outer two split_turn (1/4096 turns) out.
var crust_pieces := 0
var piece_half_m := 0.3
var dark_beyond_m := 0.0
var trail := 0
var trail_radius_m := 0.0
var trail_ticks := 0
var trail_step_ticks := 1
var trail_arm_ticks := 0
var burn_damage := 0
var burn_period_ticks := 1
var slick_permille := 1000
var split_at_permille := 0
var split_turn := 0
