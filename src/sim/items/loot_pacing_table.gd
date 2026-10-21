class_name LootPacingTable
extends RefCounted
## v0.8.0 FL (owner O91): the compiled pacing table (RunContentCompiler.compile_loot_pacing from LootPacingDefinition,
## data/rewards/pacing.tres). Loadout: never written in play, not hashed. A world without one (World.loot_pacing
## null: the labs, the older scenarios) draws as before FL: no multiplier, ceiling CardLevels.MAX_LEVEL, no guarantee,
## no jackpot draw. Stages are LootPacing.Stage; categories LootPacing.Category.

## Per stage, the draw-weight multiplier per mille of each weighted category [form, element, advanced, trigger,
## mutation] (a category's index − 1).
var weights: Array[PackedInt32Array] = [
	PackedInt32Array([1400, 1400, 400, 600, 20]),
	PackedInt32Array([1000, 1000, 1000, 1200, 100]),
	PackedInt32Array([900, 900, 1200, 1200, 300]),
	PackedInt32Array([800, 800, 1300, 1200, 600]),
]
## Per stage, the highest level a held wand card is offered up to.
var ceilings := PackedInt32Array([2, 3, 5, 5])
## Per stage, the floor's first N regular altars guarantee a card compatible with the wand.
var guaranteed_altars := PackedInt32Array([2, 0, 0, 0])
## Per regular offer, the jackpot's chance per mille.
var jackpot_permille := 15
