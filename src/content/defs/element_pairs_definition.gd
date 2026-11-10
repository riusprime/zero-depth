class_name ElementPairsDefinition
extends ContentDef
## v0.9.5 EE3 (ELEMENTS.md X1-X10; the owner: "maybe we could add some special combinations so something else happens
## when you have 2 level 3 elements they do something special"): the numbers of the ten element pairs. A pair is on
## while the Gun holds both of its elements (Fire, Lightning, Frost, Venom, Bleed) at any level; its pair
## level is the lower of the two elements' levels, and level_permille scales its strength (the numbers below are Lv 3).
## One `.tres`
## (data/combos/element_pairs.tres), compiled by WandCompiler into ElementPairTable (World.pair_table). Every number
## here is a starting value, editable without code; the names and one-line texts are the keys PAIR_<ID> and
## PAIR_<ID>_DESC in locale/strings.csv (ElementPairs.IDS).
## - triggers_per_second: the most times each pair rule that does work (a burst, a cloud, a status on a jump) fires in
##   any second of a world (owner line 21: a 20-enemy pack can't chain into a lag spike).
## - X1 Thermal Shock: a hero hit on a burning and frozen enemy removes both and bursts for x burst_permille of the
##   hit within burst_radius_m.
## - X2 Toxic Fumes: a poisoned enemy catching fire leaves a cloud_radius_m gas cloud for cloud_seconds that poisons
##   cloud_stacks onto whatever walks in, once per enemy per cloud_gap_seconds.
## - X3 Ignition Arc / X8 Neurotoxin / X9 Arterial Arc: a chain jump applies arc_burn_stacks burn / arc_poison_stacks
##   poison / arc_bleed_stacks bleed to the enemy it lands on.
## - X4 Boiling Blood: a bleed tick on a burning enemy deals boil_permille.
## - X5 Cold Circuit: a chain jump goes to the nearest frozen enemy in reach first and deals circuit_permille to it.
## - X6 Black Ice: a poisoned enemy moves at ice_slow_permille more slowly (a factor of 1000 - this), and its poison
##   does not run down while it is frozen.
## - X7 Brittle: a frozen enemy shattered or killed bursts its remaining bleed damage on the enemies within
##   brittle_radius_m, split evenly.
## - X10 Sepsis: an enemy with sepsis_stacks or more of both poison and bleed takes sepsis_permille from the hero.

## A pair's strength at pair Lv 1/2/3, per mille of the Lv 3 bonus.
@export var level_permille := PackedInt32Array([400, 700, 1000])
## Elements add with diminishing returns on one target.
## An element's damage on an enemy already carrying k other elements counts at this share, per mille, for k = 0, 1, 2
## and 3 or more (ElementStack). 0..4 values, each 1..1000, never rising; empty = no falloff.
@export var stack_falloff_permille := PackedInt32Array()
## On a run without an Element limit (the Blade's), each Prism held makes the
## falloff this many steps softer: an element counts as if its enemy carried that many fewer other elements. 0..3.
@export var prism_falloff_steps := 1
## A hero Lightning hit (the Storm card's chain or strike) leaves its enemy charged this long, so
## Lightning counts as carried in the others' falloff (ElementStack). 0 = no mark; 0..5 s.
@export var storm_mark_seconds := 0.0
@export var triggers_per_second := 4
@export var burst_permille := 3000
@export var burst_radius_m := 1.5
@export var cloud_radius_m := 2.0
@export var cloud_seconds := 3.0
@export var cloud_stacks := 1
@export var cloud_gap_seconds := 1.0
@export var arc_burn_stacks := 1
@export var arc_poison_stacks := 1
@export var arc_bleed_stacks := 1
@export var boil_permille := 2000
@export var circuit_permille := 2000
@export var ice_slow_permille := 200
@export var brittle_radius_m := 2.0
@export var sepsis_stacks := 3
@export var sepsis_permille := 1200


func category() -> StringName:
	return &"element_pairs"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_duration(issues, "storm_mark_seconds", storm_mark_seconds)  # v0.10.5 W3-P1b
	if storm_mark_seconds > 5.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "storm_mark_seconds is outside 0..5 s")
		)
	for pair: Array in [
		["triggers_per_second", triggers_per_second, 1, 60],
		["cloud_stacks", cloud_stacks, 1, 8],
		["arc_burn_stacks", arc_burn_stacks, 1, 8],
		["arc_poison_stacks", arc_poison_stacks, 1, 8],
		["arc_bleed_stacks", arc_bleed_stacks, 1, 8],
		["boil_permille", boil_permille, 1000, 10000],
		["circuit_permille", circuit_permille, 1000, 10000],
		["burst_permille", burst_permille, 1000, 20000],
		["ice_slow_permille", ice_slow_permille, 1, 900],
		["sepsis_stacks", sepsis_stacks, 1, 8],
		["sepsis_permille", sepsis_permille, 1000, 10000],
	]:
		if int(pair[1]) < int(pair[2]) or int(pair[1]) > int(pair[3]):
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s is outside %d..%d" % [pair[0], pair[2], pair[3]]
				)
			)
	var ok_levels := level_permille.size() == 3
	if ok_levels:
		for k in 3:
			if level_permille[k] < 1 or level_permille[k] > 1000:
				ok_levels = false
			if k > 0 and level_permille[k] < level_permille[k - 1]:
				ok_levels = false
	if not ok_levels:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "level_permille needs 3 ascending values in 1..1000"
			)
		)
	var ok_falloff := stack_falloff_permille.size() <= 4
	for k in stack_falloff_permille.size():
		var v := stack_falloff_permille[k]
		if v < 1 or v > 1000 or (k > 0 and v > stack_falloff_permille[k - 1]):
			ok_falloff = false
	if not ok_falloff:
		issues.append(
			ValidationIssue.new(
				&"range",
				resource_path,
				"stack_falloff_permille: 0..4 values in 1..1000, never rising"
			)
		)
	if prism_falloff_steps < 0 or prism_falloff_steps > 3:  # v0.10.5 W3-P10c
		issues.append(
			ValidationIssue.new(&"range", resource_path, "prism_falloff_steps must be 0..3")
		)
	for pair: Array in [
		["burst_radius_m", burst_radius_m],
		["cloud_radius_m", cloud_radius_m],
		["brittle_radius_m", brittle_radius_m],
	]:
		if float(pair[1]) <= 0.0 or float(pair[1]) > 8.0:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s is outside 0..8 m" % pair[0])
			)
	check_duration(issues, "cloud_seconds", cloud_seconds)
	check_duration(issues, "cloud_gap_seconds", cloud_gap_seconds)
	if cloud_seconds <= 0.0 or cloud_gap_seconds <= 0.0:
		issues.append(
			ValidationIssue.new(&"not_positive", resource_path, "cloud times must be > 0")
		)
	return issues
