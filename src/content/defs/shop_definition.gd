class_name ShopDefinition
extends ContentDef
## The shop (v0.5.0 PLAN R1, R2; ROADMAP "Shops", "salvage"): one terminal per floor in a side room. Its stock is
## drawn like a chest's offer; prices go by the card's rarity and the floor; a heal, a reroll, and salvage (sell a
## mod or stat card, or free an ability slot). Every number is a starting value the owner tunes.

## Cards in the stock.
@export var offer_size := 4
## A card's price on floor 1 by rarity: common, rare, epic (a mod or ability card is common or rare).
@export var rarity_prices := PackedInt32Array([30, 55, 90])
## Each floor after the first raises every price but the reroll by this share of the floor-1 price (x 1, 1.5, 2).
@export var floor_price_step := 0.5
## The heal: this share of max HP, once per shop, for heal_price x the floor step.
@export var heal_share := 0.3
@export var heal_price := 40
## The reroll: a new stock for reroll_price, then x (1 + reroll_step) per use at this shop.
@export var reroll_price := 20
@export var reroll_step := 0.5
## Salvage: a mod or stat card sells for this share of its shop price; an ability refunds this much per level.
@export var sell_share := 0.4
@export var ability_refund_per_level := 10
## The interact button opens the shop within this distance of the terminal.
@export var interact_radius_m := 1.8


func category() -> StringName:
	return &"shop"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "offer_size", offer_size)
	if offer_size > 9:
		issues.append(ValidationIssue.new(&"range", resource_path, "offer_size is at most 9"))
	if rarity_prices.size() != 3:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "rarity_prices has common, rare and epic")
		)
	for k in rarity_prices.size():
		check_positive(issues, "rarity_prices[%d]" % k, rarity_prices[k])
	if floor_price_step < 0.0 or reroll_step < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "a price step is negative"))
	for pair in [["heal_share", heal_share], ["sell_share", sell_share]]:
		if pair[1] <= 0.0 or pair[1] > 1.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s is in (0, 1]" % pair[0]))
	check_positive(issues, "heal_price", heal_price)
	check_positive(issues, "reroll_price", reroll_price)
	check_positive(issues, "ability_refund_per_level", ability_refund_per_level)
	check_positive(issues, "interact_radius_m", interact_radius_m)
	return issues
