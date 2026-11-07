class_name SpellTable
extends RefCounted
## v0.11.0 O10: one spell's compiled numbers (ContentCompiler.compile_spells from SpellDefinition). Per-level lists
## hold 5 entries (Lv 1 first); seconds as ticks, speed in m a tick. Read-only in play (loadout).

var id := &""
## Its index (SpellDefinition.SPELLS order; Spells.FROST_NOVA ..).
var spell := 0
var name_key := &""
var desc_key := &""
var level_keys: Array[StringName] = []
## Spells.ELEMENT_* (SpellDefinition.ELEMENTS order).
var element := 0
## The element card's item index (-1: not in this world's items: never offered).
var element_item := -1
## The rune affinity id that raises its weight (&"": none).
var affinity := &""
var weight := 0
var cooldown_ticks := 720
var reach_m := 10.0
var damage := PackedInt32Array()
var radius_m := PackedFloat32Array()
var ticks := PackedInt32Array()
var count := PackedInt32Array()
var push_m := 0.0
var jump_m := 0.0
var speed_m_tick := 0.0
var stacks := 1


## Level `lv`'s entry of a per-level list (clamped to its ends; `fallback` when empty).
static func at_i(list: PackedInt32Array, lv: int, fallback: int = 0) -> int:
	if list.is_empty():
		return fallback
	return list[clampi(lv - 1, 0, list.size() - 1)]


static func at_f(list: PackedFloat32Array, lv: int, fallback: float = 0.0) -> float:
	if list.is_empty():
		return fallback
	return list[clampi(lv - 1, 0, list.size() - 1)]
