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
