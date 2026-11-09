class_name EnemyTable
extends RefCounted
## One enemy kind's compiled numbers in sim units (metres, metres per tick, ticks, 1/4096 turns). Built from
## EnemyDefinition by the content compiler (v0.1.0 Step 4).

var kind := ActorStore.Kind.CHARGER
## The name's locale key (the dev panel shows it; v0.3.5 AI).
var name_key := &""
var hp := 1
## v0.11.0 F3: the kind's max HP as authored: the floor, Deep and loop scaling (RunState.scale_enemies) leave it, so a
## kill earns the same heal-orb points all run (HealOrbs).
var base_hp := 0
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
## kind). The Rubble Warden: its crust (already in `hp`) falls at half HP as a patch of patch_radius_m lasting
## patch_ticks that slows the hero on it to patch_slow_permille of its speed. The Dim Needle: its shots stay dark
## farther than dark_beyond_m from the hero. The Ember and Frost
## Chargers: their charge drops a `trail` patch (Variants.TRAIL_FIRE or TRAIL_SLICK) of trail_radius_m every
## trail_step_ticks, lasting trail_ticks; fire burns the hero for burn_damage every burn_period_ticks once
## trail_arm_ticks old; on a slick the hero eases at slick_permille a tick (a slide). The Split Sniper: its shot splits
## into 3 at split_at_permille of its reach, the outer two split_turn (1/4096 turns) out.
var patch_radius_m := 0.0
var patch_ticks := 0
var patch_slow_permille := 1000
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
## v0.11.0 O13b (ENEMIES.md R1-R4; RuinsRocks; the defaults on every other kind). The Wire Weaver: up to max_cables
## cables at once, each strung between two posts (post_hp, post_radius_m) at most reach_m apart, lane_half_m thick,
## hurting a touch at most every cable_period_ticks. The Scrap Hound: circles circle_m away, darts (charge_speed, up to
## charge_distance_m) only from within rear_half_arc (1/4096 turns) of the hero's back, stopped by a hit for
## stagger_ticks. The Rock Lurker: hides as a boulder (a wall of half side hide_half_m inside its body) until the hero
## is within wake_m (heard from rumble_m). The Stone Thrower: its rock flies flight_ticks, then stands rock_ticks as a
## wall of half side rock_half_m, at most max_rocks on a floor (slam_radius_m: the slam's or the landing's disc).
var max_cables := 0
var post_hp := 0
var post_radius_m := 0.3
var cable_period_ticks := 1
var circle_m := 0.0
var stagger_ticks := 0
var wake_m := 0.0
var rumble_m := 0.0
var hide_half_m := 0.0
var flight_ticks := 1
var rock_ticks := 0
var rock_half_m := 0.0
var max_rocks := 0
## v0.11.0 O13c (ENEMIES.md R5-R8): the signature enemies' own numbers (CanyonShore; the defaults on every other kind).
## The Kiln Beetle: its death bursts burst_radius_m round it burst_delay_ticks later, burst_damage to the hero and
## burst_enemy_damage to each enemy. The Cinder Priest: it plants (or takes) a vent within vent_reach_m and makes it
## erupt every vent_period_ticks (its pulse shown vent_warn_ticks first): a vent_radius_m column, vent_damage to the
## hero; once it dies the vent goes vent_linger_ticks later. The Frost Spitter: its blob flies flight_ticks and
## leaves a slick of slick_radius_m for slick_ticks (slick_permille: the hero's easing on it). The Glacier Turtle: its
## shell's shell_hp, then chunk_count chunks sliding at chunk_speed (m a tick) for chunk_ticks, chunk_damage each touch.
var burst_delay_ticks := 0
var burst_radius_m := 0.0
var burst_damage := 0
var burst_enemy_damage := 0
var vent_reach_m := 0.0
var vent_period_ticks := 1
var vent_warn_ticks := 0
var vent_radius_m := 0.0
var vent_damage := 0
var vent_linger_ticks := 0
var slick_radius_m := 0.0
var slick_ticks := 0
var shell_hp := 0
var chunk_count := 0
var chunk_speed := 0.0
var chunk_ticks := 0
var chunk_damage := 0
## v0.11.0 O13d (ENEMIES.md R9, R10; StarfallKinds; the defaults on every other kind). The Star Warper: its star lands
## mark_offset_m beside the hero (square to its line to the hero); the hero standing within mark_radius_m of the star
## when the windup ends cancels the blink and stuns it stun_ticks; else it blinks onto the star and strikes a disc of
## strike_radius_m round it. The Gravity Node: every projectile within pull_radius_m of it turns toward it by up to
## pull_accel (m per tick per tick at its centre, none at the reach), keeping its speed.
var mark_offset_m := 0.0
var mark_radius_m := 0.0
var strike_radius_m := 0.0
var stun_ticks := 0
var pull_radius_m := 0.0
var pull_accel := 0.0
