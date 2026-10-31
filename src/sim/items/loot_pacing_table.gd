class_name LootPacingTable
extends RefCounted
## v0.8.0 FL (owner O91): the compiled pacing table (RunContentCompiler.compile_loot_pacing from LootPacingDefinition,
## data/rewards/pacing.tres). Loadout: never written in play, not hashed. A world without one (World.loot_pacing
## null: the labs, the older scenarios) draws as before FL: no multiplier, ceiling CardLevels.MAX_LEVEL, no guarantee,
## no jackpot draw. Stages are LootPacing.Stage; categories LootPacing.Category.

## Per stage, the draw-weight multiplier per mille of each weighted category [form, element, advanced, trigger,
## mutation] (a category's index − 1).
var weights: Array[PackedInt32Array] = [
	PackedInt32Array([1500, 1600, 900, 600, 20]),
	PackedInt32Array([1300, 1400, 1100, 1200, 100]),
	PackedInt32Array([900, 900, 1200, 1200, 300]),
	PackedInt32Array([800, 800, 1300, 1200, 600]),
]
## Per stage, the highest level a held wand card is offered up to.
var ceilings := PackedInt32Array([2, 3, 5, 5])
## Per stage, the floor's first N regular altars guarantee a card compatible with the wand.
var guaranteed_altars := PackedInt32Array([2, 0, 0, 0])
## Per regular offer, the jackpot's chance per mille.
var jackpot_permille := 15
## v0.9.5 EP2: per stage (floor 1, 2, 3, deep), the card-type weights [ability, stat, mod] of an altar's / a chest's
## draw, 3 per stage; empty = the reward table's weights.
var altar_type_weights := PackedInt32Array()
var chest_type_weights := PackedInt32Array()
