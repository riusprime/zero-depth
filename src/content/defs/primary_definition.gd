class_name PrimaryDefinition
extends Resource
## The attacks (PLAN v0.1.0 Steps 2, 7b; v0.3.0 L11): melee = a combo of distinct swings (`combo`, one
## SwingStepDefinition per step, in order); shooting (its own button, held) = a bolt every shot_period_seconds.
## Times in seconds, compiled to ticks once. Values are starting values (GAME_BLUEPRINT §C, the v0.3.0 PLAN).

@export var combo: Array[SwingStepDefinition] = []
## After a swing ends, a press within this starts the next step; otherwise the combo starts over.
@export var combo_window_seconds := 0.2
## v0.8.0 GF1 (owner O18): the Gun's shot 25 % bigger, x0.75 the fire rate (0.12 s -> 0.15 s: 7 -> 9 ticks), x4/3
## the damage rounded to a whole point (4 -> 5; the DPS 34.3 -> 33.3 a second: what whole ticks and points allow),
## x0.9 the flight speed (18 -> 16.2 m/s) and its life 0.6 -> 0.667 s so the range stays 10.8 m.
@export var shot_period_seconds := 0.15
@export var bolt_damage := 5
@export var bolt_speed_mps := 16.2
## The bolt's hit radius, which is also the blue pulse's drawn radius (v0.8.0 GF1: what you see is what hits).
@export var bolt_radius_m := 0.2
@export var bolt_life_seconds := 0.6666667
