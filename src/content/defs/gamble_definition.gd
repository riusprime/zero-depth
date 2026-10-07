class_name GambleDefinition
extends ContentDef
## The gamble shrine (v0.3.0 PLAN L19, owner: "a gamble feature where you spend money on incrementing steps and
## have a random stat increase"). One per floor, in the start hall. Each use costs more than the last on that floor;
## the price resets on a new floor, whose base price is raised like the chests'. A use grants one stat from the
## weighted pool, never past its cap; the stats won last for the whole run. Starting values the owner tunes.

## Shards for the first use on floor 1.
@export var base_price := 25
## Each use on a floor multiplies the next price by (1 + price_step), rounded half up (0.5: 25, 38, 57, 86 ...).
@export var price_step := 0.5
## Each floor after the first raises the base price by this share (like the chests: × 1.5, × 2).
@export var floor_price_step := 0.5
## The interact button uses the shrine within this distance of the player.
@export var interact_radius_m := 1.8
## Placement: the shrine stands this far from the start point, on the side of the start hall away from its exit
## (turning by 45° steps until the spot is inside the hall and clear of walls by clear_radius_m); without such a
## spot, at the hall's nearest clear spawn point, then at the nearest clear spawn point of a room next to the hall.
@export var spot_distance_m := 2.6
@export var clear_radius_m := 0.9
@export var stats: Array[GambleStatEntry] = []


func category() -> StringName:
	return &"gamble"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "base_price", base_price)
	if price_step < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "price_step is negative"))
	if floor_price_step < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "floor_price_step is negative")
		)
	check_positive(issues, "interact_radius_m", interact_radius_m)
	check_positive(issues, "spot_distance_m", spot_distance_m)
	check_positive(issues, "clear_radius_m", clear_radius_m)
	if stats.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "the stat pool is empty"))
	var seen := {}
	for k in stats.size():
		var e := stats[k]
		if e == null or not GambleStatEntry.STATS.has(e.stat):
			issues.append(
				ValidationIssue.new(
					&"unknown_stat", resource_path, "stats[%d] names no known stat" % k
				)
			)
			continue
		if seen.has(e.stat):
			issues.append(
				ValidationIssue.new(
					&"duplicate_stat", resource_path, "stat %s is listed twice" % e.stat
				)
			)
		seen[e.stat] = true
		check_positive(issues, "stats[%d].amount" % k, e.amount)
		check_positive(issues, "stats[%d].weight" % k, e.weight)
		check_positive(issues, "stats[%d].max_stacks" % k, e.max_stacks)
	return issues
