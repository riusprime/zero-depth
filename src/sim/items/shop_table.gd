class_name ShopTable
extends RefCounted
## The shop's compiled rules (v0.5.0 SH, ROADMAP "Shops", "salvage"), built from ShopDefinition by
## ContentCompiler.compile_shop. The defaults equal the data's starting values, so a world built without content still
## has a sane shop. Integer math only: prices in shards, shares in per mille.

## Cards in the stock.
var offer_size := 4
## A card's base price by its rarity (Offers.info: 0 common, 1 rare, 2 epic).
var rarity_prices := PackedInt32Array([30, 55, 90])
## Each floor after the first raises every price but the reroll by this share of the floor-1 price (x 1, 1.5, 2).
var floor_price_step_permille := 500
## The heal: this share of max HP, once per shop, for heal_price x the floor step.
var heal_permille := 300
var heal_price := 40
## The reroll: reroll_price, then x (1 + step) per use at this shop, rounded half up (20, 30, 45, 68 ...).
var reroll_price := 20
var reroll_step_permille := 500
## Salvage: a mod or stat card sells for this share of its shop price; an ability refunds this much per level.
var sell_permille := 400
var ability_refund_per_level := 25
## The interact button opens the shop within this distance of the terminal.
var interact_radius_m := 1.8


## The floor's price multiplier, per mille (1000 on floor 1).
func floor_step_permille(floor_index: int) -> int:
	return 1000 + floor_price_step_permille * maxi(0, floor_index - 1)


static func scaled(base: int, permille: int) -> int:
	return (base * permille + 500) / 1000


## A card of `rarity` on floor `floor_index`.
func card_price(rarity: int, floor_index: int) -> int:
	var r := clampi(rarity, 0, rarity_prices.size() - 1)
	return maxi(1, scaled(rarity_prices[r], floor_step_permille(floor_index)))


func heal_cost(floor_index: int) -> int:
	return maxi(1, scaled(heal_price, floor_step_permille(floor_index)))


## The next reroll after `uses` rerolls at this shop.
func reroll_cost(uses: int) -> int:
	var p := reroll_price
	for k in uses:
		p = scaled(p, 1000 + reroll_step_permille)
	return maxi(1, p)


## What a card of `rarity` sells for on floor `floor_index`.
func sell_price(rarity: int, floor_index: int) -> int:
	return scaled(card_price(rarity, floor_index), sell_permille)
