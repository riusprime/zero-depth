class_name RewardTable
extends RefCounted
## A floor's compiled reward rules, built from RewardsDefinition by ContentCompiler.compile_rewards.
## The defaults equal the data's starting values, so a world built without content still has sane rewards.

var altars_min := 2
var altars_max := 3
var chests_min := 2
var chests_max := 3
## Band k covers floors of at most count_rooms[k] rooms (start hall in,
## boss room out) with its own ranges [altars_min, altars_max, chests_min, chests_max] (band_counts[k]); a floor with
## more rooms than the last band uses the four above (counts_for). Empty: the four above on every floor.
var count_rooms := PackedInt32Array()
var band_counts: Array[PackedInt32Array] = []
## The most placed altars per floor (0 = no cap); the data ships 2.
var altars_cap := 0
## Per mille more chests / free altars than the floor rolls (Rewards._place_extras); the data ships 120.
var extra_chest_permille := 0
var extra_altar_permille := 0
## Floor-1 chest prices by chest order; the last repeats.
var chest_prices := PackedInt32Array([40, 60, 80])
## Each floor after the first adds this per mille of the floor-1 price.
var floor_price_step_permille := 500
var rare_weight_chest := 3
var rare_weight_altar := 1
## An epic and a legendary mod's draw weight, per mille of a common one's (ItemPool.card_weight).
## A world without reward data draws no legendary.
var epic_permille_chest := 1500
var epic_permille_altar := 500
var legendary_permille_chest := 0
var legendary_permille_altar := 0
## BLADE_AUDIT B5: the run's own weapon's wand cards weigh this per mille against a shared card's 1000.
var own_weapon_card_permille := 1500
var offer_size := 3
## A regular altar's Starbound chance per mille, loop 2, loop 3.. (the last repeats; Starbound).
var starbound_permille := PackedInt32Array([200, 300])
var interact_radius_m := 1.6
## A kill's shards × (1000 + bonus × tier) / 1000, rounded half up.
var shard_tier_bonus_permille := 250
## The shard tier stops at the floor's peak phase start (starting value, owner 2026-11-01).
var shard_tier_caps_at_peak := true
## The cap tick is at least this many ticks (starting value 180 s).
var shard_cap_min_ticks := 10800
## Every kill's shards × this per mille (the data ships 700: −30 %).
var shard_permille := 1000
## A boss kill pays boss_shards × the floor number.
var boss_shards := 60
## Offers: card type weights [ability, stat, mod] and stat rarity weights [common, rare, epic] by source.
var altar_card_weights := PackedInt32Array([15, 75, 10])
var chest_card_weights := PackedInt32Array([15, 55, 30])
var altar_rarity_weights := PackedInt32Array([70, 25, 5])
var chest_rarity_weights := PackedInt32Array([40, 40, 20])
## The heal, per mille of max HP, and the reach.
var heal_orb_heal_permille := 200
var heal_orb_reach_m := 0.9
## HealOrbs, owner's playtest §6: the ticks a pickup keeps orbs away, the points that fill the meter (0
## here: a world without reward data earns none), and a kill's points: its kind's base max HP × per_hp_permille / 1000,
## clamped to min..max.
var heal_orb_cooldown_ticks := 1800
var heal_orb_meter := 0
var heal_orb_points_per_hp_permille := 1000
var heal_orb_points_min := 1
var heal_orb_points_max := 100


## The price of the `order`-th chest (0-based) on floor `floor_index` (1-based), integer math.
func chest_price(order: int, floor_index: int) -> int:
	var base := chest_prices[mini(order, chest_prices.size() - 1)]
	return base * (1000 + floor_price_step_permille * maxi(0, floor_index - 1)) / 1000


## [altars_min, altars_max, chests_min, chests_max] for a floor of `rooms` rooms (start hall in, boss room
## out): the first band that holds it, else the table's own four.
func counts_for(rooms: int) -> PackedInt32Array:
	for k in mini(count_rooms.size(), band_counts.size()):
		if rooms <= count_rooms[k]:
			return band_counts[k]
	return PackedInt32Array([altars_min, altars_max, chests_min, chests_max])
