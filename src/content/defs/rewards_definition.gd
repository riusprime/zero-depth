class_name RewardsDefinition
extends ContentDef
## A floor's rewards (v0.3.0 PLAN, L6, L7, L9): how many free altars and shard chests it has, what the chests
## cost, how much chests favour rare items, and how kills pay shards. Starting values the owner tunes.

## Altars and chests per floor, inclusive ranges (drawn from the loot stream).
@export var altars_min := 2
@export var altars_max := 3
@export var chests_min := 2
@export var chests_max := 3
## Chest prices on floor 1, by chest order on the floor (the last price repeats for any further chest).
@export var chest_prices := PackedInt32Array([40, 60, 80])
## Each floor after the first raises prices by this share of the floor-1 price (0.5: × 1.5, × 2).
@export var floor_price_step := 0.5
## Draw weight of a rare item against a common one's 1, in a chest and at an altar.
@export var rare_weight_chest := 3
@export var rare_weight_altar := 1
## Cards an altar or chest offers.
@export var offer_size := 3
## The interact button opens an altar or chest within this distance of the player.
@export var interact_radius_m := 1.6
## A kill's shards × (1 + shard_tier_bonus × danger tier).
@export var shard_tier_bonus := 0.25


func category() -> StringName:
	return &"rewards"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for pair in [["altars", altars_min, altars_max], ["chests", chests_min, chests_max]]:
		if pair[1] < 0 or pair[2] < pair[1]:
			issues.append(
				ValidationIssue.new(
					&"range",
					resource_path,
					"%s_min must be >= 0 and <= %s_max" % [pair[0], pair[0]]
				)
			)
	if chest_prices.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "chest_prices is empty"))
	for k in chest_prices.size():
		if chest_prices[k] <= 0:
			issues.append(
				ValidationIssue.new(
					&"not_positive", resource_path, "chest_prices[%d] must be > 0" % k
				)
			)
	if floor_price_step < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "floor_price_step is negative")
		)
	check_positive(issues, "rare_weight_chest", rare_weight_chest)
	check_positive(issues, "rare_weight_altar", rare_weight_altar)
	if offer_size < 1 or offer_size > 3:
		issues.append(ValidationIssue.new(&"range", resource_path, "offer_size is 1..3"))
	check_positive(issues, "interact_radius_m", interact_radius_m)
	if shard_tier_bonus < 0.0:
		issues.append(
			ValidationIssue.new(&"negative", resource_path, "shard_tier_bonus is negative")
		)
	return issues
