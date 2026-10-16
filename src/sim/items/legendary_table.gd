class_name LegendaryTable
extends RefCounted
## The boss-only legendary tier (v0.5.5 AR, owner X1b "Pick a legendary card"; RunContentCompiler.compile_legendary from
## LegendaryDefinition). Until the modifier engine (Step MX) swaps the pool, it is built from the current cards:
## stat cards at the legendary rarity (Offers.LEGENDARY: the epic amount x stat_permille, compiled into each
## StatTable) and the strongest mods. Loadout: never written in play.

## Stats.Stat indices offered as legendary stat cards, and item indices (World.item_tables) offered as mods.
var stats := PackedInt32Array()
var mods := PackedInt32Array()
## The draw weights [stat, mod] and the cards per offer.
var weights := PackedInt32Array([60, 40])
var offer_size := 3
## The legendary stat amount: the epic amount x this per mille.
var stat_permille := 1600
## v0.6.5 WN5b: 0, or every wand card (CardLevels.is_card) is a mod of the tier and a legendary pick takes it at this
## level (BossReward.on_pick).
var wand_level := 0
## v0.8.0 RR (owner O33; docs/roadmap/v0.8.0/evidence/RARITY.md): the chance, per mille, that a boss altar's offer
## holds a Legendary card (Offers.roll_legendary), and what each loop past the first adds; 0: never.
var card_permille := 0
var card_loop_permille := 0
## v0.8.0 RR: the picks a boss altar gives past the first, per loop past the first, and at most (BossReward): loop 1
## one pick, loop 2 two, ... each pick rolls a fresh offer with its own Legendary chance.
var extra_picks_per_loop := 0
var extra_picks_max := 0


## The Legendary chance on loop `loop` (1-based), per mille, 0..1000.
func chance(loop: int) -> int:
	return clampi(card_permille + card_loop_permille * maxi(0, loop - 1), 0, 1000)


## The picks past the first a boss altar gives on loop `loop`.
func extra_picks(loop: int) -> int:
	return clampi(extra_picks_per_loop * maxi(0, loop - 1), 0, extra_picks_max)
