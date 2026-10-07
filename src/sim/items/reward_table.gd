class_name RewardTable
extends RefCounted
## A floor's compiled reward rules (v0.3.0 E), built from RewardsDefinition by ContentCompiler.compile_rewards.
## The defaults equal the data's starting values, so a world built without content still has sane rewards.

var altars_min := 2
var altars_max := 3
var chests_min := 2
var chests_max := 3
## Floor-1 chest prices by chest order; the last repeats.
var chest_prices := PackedInt32Array([40, 60, 80])
## Each floor after the first adds this per mille of the floor-1 price.
var floor_price_step_permille := 500
var rare_weight_chest := 3
var rare_weight_altar := 1
var offer_size := 3
var interact_radius_m := 1.6
## A kill's shards × (1000 + bonus × tier) / 1000, rounded half up.
var shard_tier_bonus_permille := 250
## A boss kill pays boss_shards × the floor number.
var boss_shards := 60


## The price of the `order`-th chest (0-based) on floor `floor_index` (1-based), integer math.
func chest_price(order: int, floor_index: int) -> int:
	var base := chest_prices[mini(order, chest_prices.size() - 1)]
	return base * (1000 + floor_price_step_permille * maxi(0, floor_index - 1)) / 1000
