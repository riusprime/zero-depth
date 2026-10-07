class_name PrimaryDefinition
extends Resource
## The attacks (PLAN v0.1.0 Steps 2, 7b; v0.3.0 L11): melee = a combo of distinct swings (`combo`, one
## SwingStepDefinition per step, in order); shooting (its own button, held) = a bolt every shot_period_seconds.
## Times in seconds, compiled to ticks once. Values are starting values (GAME_BLUEPRINT §C, the v0.3.0 PLAN).

@export var combo: Array[SwingStepDefinition] = []
## After a swing ends, a press within this starts the next step; otherwise the combo starts over.
@export var combo_window_seconds := 0.2
@export var shot_period_seconds := 0.12
@export var bolt_damage := 4
@export var bolt_speed_mps := 18.0
## The bolt's hit radius: a little bigger than the drawn dart so shots connect (owner, 2026-10-07).
@export var bolt_radius_m := 0.16
@export var bolt_life_seconds := 0.6
