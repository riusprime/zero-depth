class_name BladeFormsDefinition
extends ContentDef
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool; CONTENT_SCHEMA "The wand"): the runner numbers the Blade's cards
## share that no card's ops name, one `.tres` in data/wand/ (its own file, so the dev panel's tuning data merges
## beside it; id blade_forms). Compiled by BladeCompiler into BladeTable (World.blade_table). Every number is a
## starting value the owner tunes by play (never a measurement: no bot sims, P1).
## - Orbit Blades (B15): at most orbit_max blades at once (the oldest leaves), each turning orbit_turns_per_second
##   round the hero and resting orbit_gap_seconds after a hit.
## - Heavy (B7): its knockback slides the enemy over knock_seconds.
## - Lunge Step (B13): the step is spread over at least lunge_seconds (not one tick: it reads as a drive, and it never
##   jumps through thin cover).
## - The fastest a swing may get: min_rate_permille of its own speed's divisor floor for stacked slow cards (Heavy
##   twice and more), so a swing never takes forever.

@export var orbit_max := 6
@export var orbit_turns_per_second := 1.0
@export var orbit_gap_seconds := 0.2
@export var knock_seconds := 0.13
@export var lunge_seconds := 0.1
@export var min_rate_permille := 250


func category() -> StringName:
	return &"wand"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if orbit_max < 1 or orbit_max > 32:
		issues.append(ValidationIssue.new(&"range", resource_path, "orbit_max is 1..32"))
	if min_rate_permille < 50 or min_rate_permille > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "min_rate_permille is 50..1000"))
	for pair: Array in [
		["orbit_turns_per_second", orbit_turns_per_second],
		["orbit_gap_seconds", orbit_gap_seconds],
		["knock_seconds", knock_seconds],
		["lunge_seconds", lunge_seconds],
	]:
		check_positive(issues, pair[0], pair[1])
	for pair: Array in [
		["orbit_gap_seconds", orbit_gap_seconds],
		["knock_seconds", knock_seconds],
		["lunge_seconds", lunge_seconds],
	]:
		check_duration(issues, pair[0], pair[1])
	return issues
