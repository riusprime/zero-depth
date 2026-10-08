class_name RewardTable
extends RefCounted
## A floor's compiled reward rules (v0.3.0 E), built from RewardsDefinition by ContentCompiler.compile_rewards.
## The defaults equal the data's starting values, so a world built without content still has sane rewards.

var altars_min := 2
var altars_max := 3
var chests_min := 2
var chests_max := 3
## v0.5.5 EC (S1): the most placed altars per floor (0 = no cap); the data ships 2.
var altars_cap := 0
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
## v0.5.5 EC (S4): every kill's shards × this per mille (the data ships 700: −30 %).
var shard_permille := 1000
## A boss kill pays boss_shards × the floor number.
var boss_shards := 60
## v0.4.0 BS (Offers): card type weights [ability, stat, mod] and stat rarity weights [common, rare, epic] by source.
var altar_card_weights := PackedInt32Array([15, 75, 10])
var chest_card_weights := PackedInt32Array([15, 55, 30])
var altar_rarity_weights := PackedInt32Array([70, 25, 5])
var chest_rarity_weights := PackedInt32Array([40, 40, 20])
## v0.4.0 TU (owner D8; HealOrbs): the drop chance per normal kill and the heal, per mille of max HP, and the reach.
## 0 here (a world without reward data drops none); the data ships 100 and 250.
var heal_orb_chance_permille := 0
var heal_orb_heal_permille := 250
var heal_orb_reach_m := 0.9


## The price of the `order`-th chest (0-based) on floor `floor_index` (1-based), integer math.
func chest_price(order: int, floor_index: int) -> int:
	var base := chest_prices[mini(order, chest_prices.size() - 1)]
	return base * (1000 + floor_price_step_permille * maxi(0, floor_index - 1)) / 1000
