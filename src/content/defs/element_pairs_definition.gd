class_name ElementPairsDefinition
extends ContentDef
## v0.9.5 EE3 (ELEMENTS.md X1-X10; the owner: "maybe we could add some special combinations so something else happens
## when you have 2 level 3 elements they do something special"): the numbers of the ten element pairs. A pair is on
## while the Gun holds both of its elements at Lv 3 (Fire, Lightning, Frost, Venom, Bleed). One `.tres`
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
