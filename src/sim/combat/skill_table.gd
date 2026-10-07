class_name SkillTable
extends RefCounted
## A build's second ability in sim units (v0.3.5 K, owner F18), compiled from SkillDefinition (ContentCompiler.
## compile_skill) and set on PlayerTable.skill by the run's build. Ticks, metres, 1/4096 turns; heat in milli-points.
## PlayerSkill runs it. Starting values (PLAN v0.3.5 "Second abilities").

## Mirrors SkillDefinition.Kind (appended, never renumbered).
enum Kind { LUNGE_CLEAVE, SCATTER_BLAST }

var kind := Kind.LUNGE_CLEAVE
## Ticks from the press until the skill may start again.
var cooldown_ticks := 240
## Damage per hit (the cleave), or per pellet (the blast), before the build's factor.
var damage := 28
## Heat a landed skill adds, once per use (HeatTable milli-points).
var heat_gain := 5000
# Lunge Cleave: the lunge (lunge_m over lunge_ticks along the facing), then the cleave fan and its hit-stop.
var lunge_m := 3.5
var lunge_ticks := 12
var half_arc := 1024
var reach_m := 2.2
var hitstop_ticks := 7
# Scatter Blast: pellets spread evenly over the cone (2 x half_cone), each a ray out to range_m from the player's
# edge; an enemy hit is pushed knockback_m away over knockback_ticks; the user steps back recoil_m over recoil_ticks.
var pellets := 7
var half_cone := 341
var range_m := 4.0
var pellet_radius_m := 0.12
var knockback_m := 1.5
var knockback_ticks := 8
var recoil_m := 0.8
var recoil_ticks := 6


## The ticks the skill moves the user: the lunge, or the step back.
func move_ticks() -> int:
	return lunge_ticks if kind == Kind.LUNGE_CLEAVE else recoil_ticks


## The distance it moves the user along its angle (negative = backwards).
func move_m() -> float:
	return lunge_m if kind == Kind.LUNGE_CLEAVE else -recoil_m


## The numbers as a list (tests compare tables with it).
func to_array() -> Array:
	return [
		kind,
		cooldown_ticks,
		damage,
		heat_gain,
		lunge_m,
		lunge_ticks,
		half_arc,
		reach_m,
		hitstop_ticks,
		pellets,
		half_cone,
		range_m,
		pellet_radius_m,
		knockback_m,
		knockback_ticks,
		recoil_m,
		recoil_ticks
	]
