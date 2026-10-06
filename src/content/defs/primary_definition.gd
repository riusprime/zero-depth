class_name PrimaryDefinition
extends Resource
## The primary (PLAN v0.1.0 Step 2): press = swing (a combo), keep holding = charge, release = a bolt.
## Times in seconds, compiled to ticks once. Values are starting values (GAME_BLUEPRINT §C, the v0.1.0 PLAN).

@export var swing_duration_seconds := 14.0 / 60.0
## When the swing hits, after it starts.
@export var swing_active_seconds := 2.0 / 60.0
@export var swing_reach_m := 1.6
@export var swing_arc_degrees := 120.0
@export var swing_damage: Array[int] = [10, 10, 18]
@export var combo_window_seconds := 0.2
@export var swing_hitstop_seconds := 3.0 / 60.0
@export var charge_start_seconds := 0.2
@export var charge_full_seconds := 0.8
@export var charge_move_multiplier := 0.5
@export var bolt_min_damage := 12
@export var bolt_max_damage := 36
@export var bolt_speed_mps := 16.0
@export var bolt_radius_m := 0.15
@export var bolt_life_seconds := 1.5
@export var bolt_full_hitstop_seconds := 5.0 / 60.0
