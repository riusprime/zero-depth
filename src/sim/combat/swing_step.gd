class_name SwingStep
extends RefCounted
## One compiled step of the melee combo (v0.3.0 PLAN L11), in sim units: ticks, metres, 1/4096 turns. Built from
## SwingStepDefinition by the content compiler; PlayerTable.starting_values() holds the same numbers.
##
## The swing occupies ticks 1..ticks (PlayerKit.advance). It hits on active_tick, so the recovery after the hit is
## ticks - active_tick. The lunge moves the wanderer lunge_m along the swing angle, spread evenly over the ticks
## before the hit (lunge_ticks()). motion and sweep_ticks are for the view only.

## Mirrors SwingStepDefinition.Motion.
enum Motion { SLASH_RIGHT_TO_LEFT, SLASH_LEFT_TO_RIGHT, THRUST, SPIN }

var motion := Motion.SLASH_RIGHT_TO_LEFT
var ticks := 14
var active_tick := 2
var half_arc := 683
var reach_m := 1.6
var damage := 10
var hitstop_ticks := 3
var lunge_m := 0.0
var sweep_ticks := 5


static func make(
	p_motion: Motion,
	p_active: int,
	p_recovery: int,
	p_half_arc: int,
	p_reach: float,
	p_damage: int,
	p_hitstop: int,
	p_lunge: float,
	p_sweep: int
) -> SwingStep:
	var s := SwingStep.new()
	s.motion = p_motion
	s.active_tick = p_active
	s.ticks = p_active + p_recovery
	s.half_arc = p_half_arc
	s.reach_m = p_reach
	s.damage = p_damage
	s.hitstop_ticks = p_hitstop
	s.lunge_m = p_lunge
	s.sweep_ticks = p_sweep
	return s


## Ticks the lunge is spread over: the ones before the hit (at least one).
func lunge_ticks() -> int:
	return maxi(1, active_tick - 1)


func recovery_ticks() -> int:
	return ticks - active_tick


## The numbers as a list, for comparing tables (tests) and evidence tables.
func to_array() -> Array:
	return [
		motion, ticks, active_tick, half_arc, reach_m, damage, hitstop_ticks, lunge_m, sweep_ticks
	]
