class_name SpellTable
extends RefCounted
## One spell's compiled numbers (ContentCompiler.compile_spells from SpellDefinition). Per-level lists
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
## A lasting spell's pulse, a delay (ticks); Blood Thorns' inner edge (m); the extra enemies passed through.
var period_ticks := 30
var delay_ticks := 0
var inner_m := 0.0
var pierce := 0
## The Lv 5 extra's damage, length (ticks) and radius (m).
var bonus_damage := 0
var bonus_ticks := 0
var bonus_radius_m := 0.0
## O11 Leech: per level, the most HP a cast heals; the damage for each 1 HP. Toxic Cloud's Lv 5 slow (per mille).
var heal_cap := PackedInt32Array()
var heal_per_damage := 25
var slow_permille := 1000


## Level `lv`'s entry of a per-level list (clamped to its ends; `fallback` when empty).
static func at_i(list: PackedInt32Array, lv: int, fallback: int = 0) -> int:
	if list.is_empty():
		return fallback
	return list[clampi(lv - 1, 0, list.size() - 1)]


static func at_f(list: PackedFloat32Array, lv: int, fallback: float = 0.0) -> float:
	if list.is_empty():
		return fallback
	return list[clampi(lv - 1, 0, list.size() - 1)]
