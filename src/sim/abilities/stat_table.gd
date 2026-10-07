class_name StatTable
extends RefCounted
## One stat card's compiled numbers (v0.4.0 BS; ContentCompiler.compile_stat_cards from StatCardDefinition): the
## stat (Stats.Stat), its amount per rarity in per mille (points x 10 for crit; per mille of max HP per second for
## regen), its cap in per mille (0 = none) and its draw weight.

var id := &""
var stat := 0
var name_key := &""
var desc_key := &""
## Common, rare, epic.
var amounts := PackedInt32Array([0, 0, 0])
var cap := 0
var weight := 0
