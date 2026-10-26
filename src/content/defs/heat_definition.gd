class_name HeatDefinition
extends ContentDef
## Overclock heat (v0.3.0 PLAN L18; docs/design/SIGNATURE.md §Overclock): every landed attack builds heat, the
## thresholds transform the attacks, the overheat point stalls you, and a dash or blink while Hot vents it in a
## blast. Heat is in points (0..max_heat). Every number is a starting value the owner tunes after playing.

## The overheat point: heat never goes past it, and reaching it overheats.
@export var max_heat := 100
## Heat each landed attack adds, by attack type (data-driven so Blade and Gun builds tune apart): a combo step
## that is not the finisher, the finisher, one landed bolt. A swing adds once however many enemies it hits.
@export var gain_swing := 2.5
@export var gain_finisher := 5.0
@export var gain_bolt := 0.9
## v0.9.5 HT: a Gun run's heat fills by time spent firing (the primary attack held and armed), whatever the form:
## 0 to max_heat in gun_fill_seconds. gain_bolt no longer applies on a Gun run (the Blade's gains are unchanged).
@export var gun_fill_seconds := 14.0
## Heat starts to fall this long after the last gain (a firing tick or a landed Blade attack), at this rate.
@export var cool_delay_seconds := 1.0
@export var cool_per_second := 25.0
## Hot: the blade reaches farther and each bolt pierces one enemy.
@export var hot_threshold := 40
@export var hot_reach_bonus := 0.2
## Overclock: attacks deal more and leave embers; with a burn item (the fire engine) they add burn stacks.
@export var overclock_threshold := 75
@export var overclock_damage_bonus := 0.25
@export var overclock_burn_stacks := 1
## Overheat: this long without attacking, moving at this share of your speed; heat drains to 0 meanwhile.
@export var overheat_seconds := 1.2
@export var overheat_move_multiplier := 0.6
## Vent: a dash or blink started while Hot blasts every enemy within vent_radius_m for vented heat ×
## vent_damage_per_heat, and resets heat to 0.
@export var vent_radius_m := 2.5
@export var vent_damage_per_heat := 0.5
## v0.9.5 HT: Vent needs at least vent_min_heat and then waits vent_cooldown_seconds before it can go again.
@export var vent_min_heat := 40.0
@export var vent_cooldown_seconds := 6.0


func category() -> StringName:
	return &"heat"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "max_heat", max_heat)
	for pair in [
		["gain_swing", gain_swing],
		["gain_finisher", gain_finisher],
		["gain_bolt", gain_bolt],
		["gun_fill_seconds", gun_fill_seconds],
		["cool_per_second", cool_per_second],
		["vent_min_heat", vent_min_heat],
		["vent_cooldown_seconds", vent_cooldown_seconds],
		["hot_reach_bonus", hot_reach_bonus],
		["overclock_damage_bonus", overclock_damage_bonus],
		["overheat_seconds", overheat_seconds],
		["vent_radius_m", vent_radius_m],
		["vent_damage_per_heat", vent_damage_per_heat],
	]:
		check_positive(issues, pair[0], pair[1])
	check_duration(issues, "cool_delay_seconds", cool_delay_seconds)
	check_duration(issues, "gun_fill_seconds", gun_fill_seconds)
	check_duration(issues, "vent_cooldown_seconds", vent_cooldown_seconds)
	check_duration(issues, "overheat_seconds", overheat_seconds)
	if not (
		0 < hot_threshold and hot_threshold < overclock_threshold and overclock_threshold < max_heat
	):
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "0 < hot_threshold < overclock_threshold < max_heat"
			)
		)
	if overclock_burn_stacks < 0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "overclock_burn_stacks is negative")
		)
	if overheat_move_multiplier <= 0.0 or overheat_move_multiplier > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "overheat_move_multiplier is in (0, 1]")
		)
	return issues
