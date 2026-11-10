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
	&"ability_owned",  # The slots, their levels and the stat cards
	&"ability_levels",
	&"stat_values",
	&"curses_owned",  # Curses and the threat peak
	&"threat_peak",
	&"stat_cards",  # The stat cards taken, so the shop can sell one back
	&"mod_slots",  # The six modifier slots in pick order (the layer order)
	&"card_levels",  # The wand cards' levels
	&"stat_rules",  # The rules stat_values follow (a carry without it is from before SG)
	&"events_seen",  # The events placed this run (a carry without it: none)
	&"constellations",  # The held Constellations (a carry without it: none)
	&"starbound",  # The Starbound picks (a carry without it: none)
	&"spell_slots",  # The spells held and their levels (a carry without them: none)
	&"spell_levels",
	&"relics",  # The relics held and their uses this run (a carry without it, or none held: none)
]
const HP := &"hp"
## A new loop's Constellation offer (RunState.finish_floor writes it: World.constellation_offer).
const OFFER := &"constellation_offer"
## The shards the portal left behind, written to the next floor's World.shards_left_behind
## (the arrival card says so).
const LEFT := &"shards_left_behind"


## The carry out of a finished floor. only shard_carry_permille of the unspent
## shards carry (rounded down; 1000 = all, the default for callers without a run table).
static func take(w: World, heal_permille: int, shard_carry_permille: int = 1000) -> Dictionary:
	var out := {}
	for field in FIELDS:
		if field == &"relics" and w.relics.is_empty():
			continue  # No relic held, no key (a carry as before)
		if field in w:
			out[field] = _copy(w.get(field))
	if out.has(&"shards"):
		var kept := int(out[&"shards"]) * clampi(shard_carry_permille, 0, 1000) / 1000
		out[LEFT] = int(out[&"shards"]) - kept
		out[&"shards"] = kept
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
	# The slots follow what the carry holds; a carry from before MX2 (no slots) migrates into the slot
	# model (BuildSlots.migrate: the first six modifiers in a fixed order stay).
	# The abilities' tables come after the carry (Main, the labs), so the migration runs in Abilities.start_floor.
	if not carry.has(&"mod_slots"):
		w.migrate_slots = true
	# A carry from before SG compounded damage and attack speed; the stat tables come after the carry too,
	# so Abilities.start_floor rebuilds them (Stats.migrate_rules).
	if carry.has(&"stat_values") and not carry.has(&"stat_rules"):
		w.stat_rules = 0
	Modifiers.invalidate(w)  # The cards' levels came after the items
	Gamble.after_carry(w)  # the shrine's max HP wins, before the HP is clamped to max
	if carry.has(HP):
		w.actors.hp[0] = clampi(int(carry[HP]), 1, w.actors.max_hp[0])


## The max HP the floors cleared before run floor `f` add (counted across
## loops; the final arena stays on its loop's last floor), at most the table's cap (0: none).
static func floor_hp_bonus(t: RunTable, f: int) -> int:
	var b := t.max_hp_per_floor * maxi(0, f - 1)
	return mini(b, t.max_hp_floor_cap) if t.max_hp_floor_cap > 0 else b


## The growth the run's current floor arrived with (0 on the run's first floor and in the final arena).
static func hp_grown(run: RunState) -> int:
	if run.final_fight:
		return 0
	var f := run.run_floor()
	return floor_hp_bonus(run.table, f) - floor_hp_bonus(run.table, f - 1)


## The floors' max HP bonus goes `from` -> `to` between floors: the carry's HP rises by what the max HP
## gains (through the max HP stat of `w`, the finished floor, as the next floor's max HP will be), so it arrives filled.
static func grow(w: World, carry: Dictionary, from: int, to: int) -> void:
	if to <= from or not carry.has(HP):
		return
	var keep := w.floor_hp_bonus
	w.floor_hp_bonus = from
	var was := Stats.max_hp(w)
	w.floor_hp_bonus = to
	carry[HP] = int(carry[HP]) + Stats.max_hp(w) - was
	w.floor_hp_bonus = keep


static func _copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return v.duplicate()
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return v.duplicate()
	return v
