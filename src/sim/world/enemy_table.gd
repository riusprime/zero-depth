class_name EnemyTable
extends RefCounted
## One enemy kind's compiled numbers in sim units (metres, metres per tick, ticks, 1/4096 turns). Built from
## EnemyDefinition by the content compiler (v0.1.0 Step 4).

var kind := ActorStore.Kind.CHARGER
var hp := 1
var radius_m := 0.4
var speed := 0.0
## The attack: start range, cooldown after recovery, windup (the telegraph), active and recovery ticks, damage.
var attack_range_m := 0.0
var cooldown_ticks := 0
var windup_ticks := 24
var active_ticks := 1
var recover_ticks := 0
var damage := 0
## Charger.
var charge_speed := 0.0
var charge_distance_m := 0.0
## Warden: armour by the direction a hit comes from (1/4096 turns either side of facing, per-mille multipliers).
var front_half_arc := 0
var front_mult_permille := 1000
var rear_half_arc := 0
var rear_mult_permille := 1000
var turn_rate := 0
var slam_radius_m := 0.0
## Needle.
var keep_distance_m := 0.0
var flee_distance_m := 0.0
var burst_count := 0
var burst_gap_ticks := 1
var bolt_speed := 0.0
var bolt_radius_m := 0.12
var bolt_life_ticks := 120
