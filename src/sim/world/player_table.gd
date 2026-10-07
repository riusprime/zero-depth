class_name PlayerTable
extends RefCounted
## The player's compiled numbers, in sim units (metres, ticks). Built from PlayerDefinition by the
## content compiler (v0.0.1 Step 6); starting_values() is the same data for tests and tools.

## The utility chosen before the run (PD-01).
enum Utility { NONE, GUARD, BLINK }

var hp := 100
var radius_m := 0.35
## Metres per tick.
var move_speed := 0.0
## Movement eases toward the target velocity: this per-mille of the gap closes each tick, speeding up and
## stopping (owner, 2026-10-07: "a fast smooth curve"). 319 = 90% in 6 ticks (0.10 s); 369 = 90% in 5 ticks.
var accel_permille := 319
var decel_permille := 369
var dash_distance_m := 0.0
var dash_ticks := 1
var dash_cooldown_ticks := 0
## Invulnerable ticks at the start of a dash (the whole dash by default).
var dash_iframe_ticks := 9
## After taking a hit: invulnerable ticks and hit-stop ticks.
var hurt_iframe_ticks := 30
var hurt_freeze_ticks := 4
## Guard: half arc (1/4096 turns) and the per-mille multiplier for hits from inside it.
var guard_half_arc := 683
var guard_mult_permille := 200
var utility := Utility.NONE
var guard_move_permille := 400
## Blink: range in metres, cooldown and invulnerable ticks.
var blink_range_m := 5.0
var blink_cooldown_ticks := 150
var blink_iframe_ticks := 6
## Melee: a combo of distinct swings (v0.3.0 L11), one SwingStep per step in order; a press within
## combo_window_ticks of a swing's end starts the next step, otherwise (and after the last step) the combo
## starts over. Shooting: bolts. Distances in metres, speeds in metres per tick.
var combo: Array[SwingStep] = default_combo()
var combo_window_ticks := 12
## Shooting: a bolt every shot_period_ticks while held, bolt_damage each.
var shot_period_ticks := 7
var bolt_damage := 4
var bolt_speed := 18.0 / 60.0
var bolt_radius_m := 0.16
var bolt_life_ticks := 36


## The v0.0.1 starting values (docs/design/GAME_BLUEPRINT.md §C): 6 m/s, dash 4 m over 0.15 s, 0.8 s cooldown.
static func starting_values() -> PlayerTable:
	var t := PlayerTable.new()
	t.hp = 100
	t.radius_m = 0.35
	t.move_speed = 6.0 / SimTick.TICKS_PER_SECOND
	t.dash_distance_m = 4.0
	t.dash_ticks = SimTick.seconds_to_ticks(0.15)
	t.dash_cooldown_ticks = SimTick.seconds_to_ticks(0.8)
	t.dash_iframe_ticks = SimTick.seconds_to_ticks(0.15)
	return t


## The v0.3.0 four-slash combo (PLAN L11, starting values): a horizontal slash right to left, a backhand left to
## right, a forward thrust (narrow, longer, a slight step) and a heavy spinning finisher (all around, more damage
## and hit-stop, a longer recovery, a small lunge). The same numbers as data/player/runner.tres.
static func default_combo() -> Array[SwingStep]:
	var out: Array[SwingStep] = [
		SwingStep.make(SwingStep.Motion.SLASH_RIGHT_TO_LEFT, 2, 11, 683, 1.6, 10, 3, 0.0, 5),
		SwingStep.make(SwingStep.Motion.SLASH_LEFT_TO_RIGHT, 3, 11, 683, 1.6, 10, 3, 0.0, 5),
		SwingStep.make(SwingStep.Motion.THRUST, 4, 12, 228, 2.3, 12, 4, 0.35, 4),
		SwingStep.make(SwingStep.Motion.SPIN, 7, 24, 2048, 1.9, 24, 7, 0.6, 9),
	]
	return out


## The combo step `i` (0-based).
func step(i: int) -> SwingStep:
	return combo[i]
