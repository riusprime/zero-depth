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
