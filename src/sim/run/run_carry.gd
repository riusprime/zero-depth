class_name RunCarry
extends RefCounted
## What a run keeps from one floor to the next (v0.3.0 PLAN "Run (B)"), in one place: the player's HP (healed by the
## run's heal share, capped at max) and every World field named in FIELDS that the world has. Workstreams that add
## run-long state to World (shards, combos, engine stacks) append its field name to FIELDS; a name the world lacks
## is skipped, so the list may run ahead of the code. Values are copied, never shared between worlds.

const FIELDS: Array[StringName] = [
	&"items_owned",
	&"combos_owned",
	&"guard_charges",
	&"shards",
	&"gamble_stacks",
	&"regen_bonus_permille",
	&"ability_owned",  # v0.4.0 BS: the slots, their levels and the stat cards
	&"ability_levels",
	&"stat_values",
	&"stat_cards",  # v0.5.0 SH: the stat cards taken, so the shop can sell one back
]
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


## Applies a carry to a fresh world (before its loot is drawn, so a floor never offers what you already hold). The
## items go through World.set_items_owned (modifiers and combos follow, no unlock events); the combos owned keep
## their unlock order. Call it after World.set_item_tables and World.set_combo_tables (FloorScenario does).
static func apply(w: World, carry: Dictionary) -> void:
	if carry.has(&"items_owned"):
		w.set_items_owned(carry[&"items_owned"])
	for field: StringName in carry:
		if field == HP or field == &"items_owned":
			continue
		if field in w:
			w.set(field, _copy(carry[field]))
	Gamble.after_carry(w)  # the shrine's max HP wins, before the HP is clamped to max
	if carry.has(HP):
		w.actors.hp[0] = clampi(int(carry[HP]), 1, w.actors.max_hp[0])


static func _copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return v.duplicate()
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return v.duplicate()
	return v
