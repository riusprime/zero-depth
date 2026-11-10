class_name ShopTable
extends RefCounted
## The shop's compiled rules (v0.5.0 SH, ROADMAP "Shops"), built from ShopDefinition by
## ContentCompiler.compile_shop. The defaults equal the data's starting values, so a world built without content still
## has a sane shop. Integer math only: prices in shards, shares in per mille.

## Cards in the stock.
var offer_size := 4
## A card's base price by its rarity (Offers.info: 0 common, 1 rare, 2 epic).
var rarity_prices := PackedInt32Array([30, 55, 90])
## Each floor after the first raises every price but the reroll by this share of the floor-1 price (x 1, 1.5, 2).
var floor_price_step_permille := 500
## Floors 2 and later multiply the stepped prices (cards, heal) by this too (x 1, 2.25, 3).
var late_floor_permille := 1500
## The most cards bought at one floor's shop (0 = no limit).
var max_buys := 4
## The heal: this share of max HP, once per shop, for heal_price x the floor step.
var heal_permille := 300
var heal_price := 40
## The reroll (only the unsold slots): reroll_price, then x (1 + step) per use at this shop, rounded
## half up (20, 30, 45, 68 ...).
var reroll_price := 20
var reroll_step_permille := 500
## The interact button opens the shop within this distance of the terminal.
var interact_radius_m := 1.8
## The shop stands on floor `first_floor`
## and every `every_floors` floors after it (FloorCadence: 1, 3, 5 ... as shipped; a 3-floor run has two).
var first_floor := 1
var every_floors := 2
## The biomes' shop rooms, biome id -> ShopRoomTable (RunContentCompiler.compile_shop_rooms).
## Empty on a floor saved before SR (RunState.shop_rooms; RunSaver.floor_tables), whose shop is the terminal.
var rooms := {}


## The shop room of biome `biome` (null: none, so the terminal).
func room_for(biome: StringName) -> ShopRoomTable:
	return rooms.get(biome, null)


## Whether floor `floor_index` (the run's floor number, counted on past the run's last floor) has the shop.
func on_floor(floor_index: int) -> bool:
	return FloorCadence.on(floor_index, first_floor, every_floors)


## The floor's price multiplier, per mille (1000 on floor 1): the floor step, and from floor 2 the late-floor
## multiplier on top.
func floor_step_permille(floor_index: int) -> int:
	var step := base_step_permille(floor_index)
	return step if floor_index < 2 else scaled(step, late_floor_permille)


## The floor step alone (1000, 1500, 2000), without the late-floor multiplier (WandMigration's refunds go by it).
func base_step_permille(floor_index: int) -> int:
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
