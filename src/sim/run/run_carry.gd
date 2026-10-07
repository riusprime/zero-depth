class_name RunCarry
extends RefCounted
## What a run keeps from one floor to the next (v0.3.0 PLAN "Run (B)"), in one place: the player's HP (healed by the
## run's heal share, capped at max) and every World field named in FIELDS that the world has. Workstreams that add
## run-long state to World (shards, combos, engine stacks) append its field name to FIELDS; a name the world lacks
## is skipped, so the list may run ahead of the code. Values are copied, never shared between worlds.

const FIELDS: Array[StringName] = [&"items_owned", &"shards"]
const HP := &"hp"


## The carry out of a finished floor.
static func take(w: World, heal_permille: int) -> Dictionary:
	var out := {}
	for field in FIELDS:
		if field in w:
			out[field] = _copy(w.get(field))
	var max_hp := w.actors.max_hp[0]
	out[HP] = mini(max_hp, w.actors.hp[0] + max_hp * heal_permille / 1000)
	return out


## Applies a carry to a fresh world (before its loot is drawn, so a floor never offers what you already hold).
static func apply(w: World, carry: Dictionary) -> void:
	for field: StringName in carry:
		if field == HP:
			w.actors.hp[0] = clampi(int(carry[HP]), 1, w.actors.max_hp[0])
		elif field in w:
			w.set(field, _copy(carry[field]))
	w.item_mods = ItemMods.build(w.item_tables, w.items_owned)


static func _copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return v.duplicate()
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return v.duplicate()
	return v
