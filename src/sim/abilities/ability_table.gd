class_name AbilityTable
extends RefCounted
## One ability's compiled numbers (v0.4.0 BS; ContentCompiler.compile_abilities from AbilityDefinition): ticks,
## metres and per mille. The per-level arrays hold one entry per level (index 0 = L1). See AbilityDefinition for
## what each kind reads.

## Mirrors AbilityDefinition.Kind (appended, never renumbered).
enum Kind { COMBO_SWORD, PULSE_GUN, BOMB_LOBBER, DRONE_BUDDY, ORBIT_BLADES, BLINK, AEGIS }
enum Binding { NONE, PRIMARY, UTILITY }

const MAX_LEVEL := 5

var id := &""
var kind := Kind.BOMB_LOBBER
var auto := true
var button := Binding.NONE
var rare := false
var name_key := &""
var desc_key := &""
## The PlayerTable.WEAPON_* bit whose slot 1 this is (0 = an ability card).
var start_weapon := 0
var tags := PackedStringArray()
var cooldown_ticks := 0
var damage := 0
var range_m := 0.0
var radius_m := 0.0
## Metres per tick.
var speed := 0.0
var period_ticks := 0
var duration_ticks := 0
var hit_ticks := 0
var level_damage := PackedInt32Array([1000, 1000, 1000, 1000, 1000])
var level_count := PackedInt32Array([1, 1, 1, 1, 1])
var level_radius := PackedInt32Array([1000, 1000, 1000, 1000, 1000])
var level_rate := PackedInt32Array([1000, 1000, 1000, 1000, 1000])
var level_cooldown := PackedInt32Array([0, 0, 0, 0, 0])
var level_extra := PackedInt32Array([0, 0, 0, 0, 0])


## Level `level` (1-based, clamped) as an array index.
static func at(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL) - 1


func damage_permille(level: int) -> int:
	return level_damage[at(level)]


func count(level: int) -> int:
	return level_count[at(level)]


func radius_permille(level: int) -> int:
	return level_radius[at(level)]


func rate_permille(level: int) -> int:
	return level_rate[at(level)]


func cooldown_at(level: int) -> int:
	return level_cooldown[at(level)]


func extra(level: int) -> int:
	return level_extra[at(level)]


func is_utility() -> bool:
	return button == Binding.UTILITY
