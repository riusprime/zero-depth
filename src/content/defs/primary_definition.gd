class_name PrimaryDefinition
extends Resource
## The attacks (PLAN v0.1.0 Steps 2, 7b): melee = a swing combo; shooting (its own button, held) = a bolt every
## shot_period_seconds.
## Times in seconds, compiled to ticks once. Values are starting values (GAME_BLUEPRINT §C, the v0.1.0 PLAN).

@export var swing_duration_seconds := 14.0 / 60.0
## When the swing hits, after it starts.
@export var swing_active_seconds := 2.0 / 60.0
@export var swing_reach_m := 1.6
@export var swing_arc_degrees := 120.0
@export var swing_damage: Array[int] = [10, 10, 18]
@export var combo_window_seconds := 0.2
@export var swing_hitstop_seconds := 3.0 / 60.0
@export var shot_period_seconds := 0.12
@export var bolt_damage := 4
@export var bolt_speed_mps := 18.0
## The bolt's hit radius: a little bigger than the drawn dart so shots connect (owner, 2026-10-07).
@export var bolt_radius_m := 0.16
@export var bolt_life_seconds := 0.6
