class_name BuildSlots
extends RefCounted
## The build model (v0.6.0 MX2; owner B7, B8, docs/design/MODIFIER_ENGINE.md "The build"; SIM_CONTRACTS §5c).
## The build is the starting weapon (with its Skill, the dash and Vent), one utility pick (Blink or Aegis, on the
## utility button, outside the slots), up to SLOTS modifier slots, and unlimited stat cards (no slot).
## - A modifier card takes a slot: one of the six weapon-modifier abilities (AbilityTable.is_modifier: Bomb Lobber,
##   Drone Buddy, Orbit Blades, Arc Field, Frost Nova, Flame Trail), or an item that changes attacks (is_slot_item:
##   it names modifiers, or it is an ability's mod). The other items (engines, dash, guard, heat) take no slot.
## - World.mod_slots holds the modifier cards in pick order (Offers codes), the layer order Modifiers compiles in. It
##   is kept by sync() after every change of what is held: the cards already listed stay in place, a newly held one
##   is appended, one no longer held leaves.
## - Taking a modifier you hold levels it up (an ability, levels 1..5) and uses no slot. A new one goes in the next
##   slot; with the six full it needs a swap: the player picks the held modifier it replaces (it takes that slot, so
##   the layer order keeps its place) or skips. The pick panel, the shop and the other grants (an event's card, a
##   floor pickup) all go through take(); a grant without a panel of its own opens the swap choice by itself
##   (World.swap_*: the world waits like an altar's pick).
## Every function here is deterministic and draws no randomness.

const SLOTS := 6
## Where a pending swap came from (World.swap_source): the altar or chest choice (skip returns to its cards), the shop
## (skip returns to the shop), or a grant with no panel (an event, a pickup: skip leaves the card).
enum Source { NONE, REWARD, SHOP, GRANT }


# --- What a card is ------------------------------------------------------------------------------------------
## An item that takes a modifier slot: it changes attacks (it names modifiers) or it is an ability's mod.
static func is_slot_item(t: ItemTable) -> bool:
	return not t.modifiers.is_empty() or t.requires_ability >= 0


## Card `code` (Offers code) is a modifier card.
static func is_modifier(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return code >= 0 and code < w.item_tables.size() and is_slot_item(w.item_tables[code])
		Offers.ABILITY:
			var idx := Offers.ability_of(code)
			return idx < w.ability_tables.size() and w.ability_tables[idx].is_modifier()
	return false


## The player holds card `code` now.
static func held(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return w.items_owned.has(code)
		Offers.ABILITY:
			return Abilities.owned(w, Offers.ability_of(code))
	return false


static func count(w: World) -> int:
	return w.mod_slots.size()


static func full(w: World) -> bool:
	return w.mod_slots.size() >= SLOTS


## The level of slot `s`'s card: its ability's level, 1 for an item.
static func level_at(w: World, s: int) -> int:
	var code := w.mod_slots[s]
	if Offers.type_of(code) == Offers.ABILITY:
		return Abilities.level_of(w, Offers.ability_of(code))
	return 1


## Taking `code` now needs a swap: a modifier you don't hold, with every slot full.
static func needs_swap(w: World, code: int) -> bool:
	return is_modifier(w, code) and not held(w, code) and full(w)


# --- Keeping the slots ------------------------------------------------------------------------------------------
## mod_slots after a change of what is held: the listed cards still held, in place; then the held modifier cards not
## listed yet (abilities in World.ability_owned order, then items in pickup order). Never caps (migrate does).
static func sync(w: World) -> void:
	var out := PackedInt32Array()
	for c in w.mod_slots:
		if _maybe_modifier(w, c) and held(w, c) and not out.has(c):
			out.append(c)
	for idx in w.ability_owned:
		var c := Offers.ability_code(idx)
		if is_modifier(w, c) and not out.has(c):
			out.append(c)
	for idx in w.items_owned:
		if is_modifier(w, idx) and not out.has(idx):
			out.append(idx)
	if out != w.mod_slots:
		w.mod_slots = out
		Modifiers.invalidate(w)


## A listed card stays while its table isn't loaded yet (the carry comes before the abilities' tables).
static func _maybe_modifier(w: World, code: int) -> bool:
	if Offers.type_of(code) == Offers.ABILITY and Offers.ability_of(code) >= w.ability_tables.size():
		return true
	if Offers.type_of(code) == Offers.MOD and code >= w.item_tables.size():
		return true
	return is_modifier(w, code)


## A build from before MX2 (a v0.5 save's carry or snapshot, four ability slots and any number of attack items):
## sync, then the slots past SLOTS leave the build, last first (so the first SLOTS in sync's order stay: the
## abilities in their slot order, then the items in pickup order). Deterministic; idempotent.
static func migrate(w: World) -> void:
	sync(w)
	while w.mod_slots.size() > SLOTS:
		drop(w, w.mod_slots.size() - 1)


## Slot `s`'s card leaves the build: an item goes with its combos (Shop.remove_item), an ability with its level and
## its floor state (Abilities.remove).
static func drop(w: World, s: int) -> void:
	if s < 0 or s >= w.mod_slots.size():
		return
	var code := w.mod_slots[s]
	if Offers.type_of(code) == Offers.ABILITY:
		var slot := w.ability_owned.find(Offers.ability_of(code))
		if slot >= 0:
			Abilities.remove_slot(w, slot)
	elif w.items_owned.has(code):
		Shop.remove_item(w, code)
	sync(w)


## Takes card `code` (the one way a card enters the build: Offers.apply). A modifier you don't hold with the six
## slots full replaces slot `replace` (its card leaves; the new one takes its place in the order); without a valid
## `replace` nothing changes and false comes back. Everything else (a level-up, the weapon, the utility, an item
## without a slot, a stat card) applies as before.
static func take(w: World, code: int, replace: int = -1) -> bool:
	if needs_swap(w, code):
		if replace < 0 or replace >= w.mod_slots.size():
			return false
		drop(w, replace)
		_apply(w, code)
		var n := w.mod_slots.find(code)
		if n >= 0 and n != replace and replace <= w.mod_slots.size() - 1:
			w.mod_slots.remove_at(n)
			w.mod_slots.insert(replace, code)
			Modifiers.invalidate(w)
		return true
	_apply(w, code)
	return true


static func _apply(w: World, code: int) -> void:
	match Offers.type_of(code):
		Offers.MOD:
			w.add_item(code)
		Offers.ABILITY:
			Abilities.grant(w, Offers.ability_of(code))
		Offers.STAT:
			Stats.add_card(w, Offers.stat_of(code), Offers.rarity_of(code))
	sync(w)


# --- The swap choice ------------------------------------------------------------------------------------------
## Opens the swap choice for `code` from `source` (its offer index there: `ref`).
static func open_swap(w: World, code: int, source: int, ref: int) -> void:
	w.swap_code = code
	w.swap_source = source
	w.swap_ref = ref


static func close_swap(w: World) -> void:
	w.swap_code = -1
	w.swap_source = Source.NONE
	w.swap_ref = -1


static func swapping(w: World) -> bool:
	return w.swap_code >= 0


## The swap answer in `frame`: the slot to replace (0..SLOTS-1, a held one), -1 to skip (PICK_SWAP_SKIP or
## PICK_CANCEL), -2 for no answer yet.
static func swap_answer(w: World, frame: InputFrame) -> int:
	var v := frame.pick
	if v == InputFrame.PICK_SWAP_SKIP or v == InputFrame.PICK_CANCEL:
		return -1
	var s := v - InputFrame.PICK_SWAP_BASE
	if s >= 0 and s < SLOTS and s < w.mod_slots.size():
		return s
	return -2


## World.step while a GRANT swap waits (no panel of its own): a slot answer swaps the card in, a skip leaves it.
## Nothing pressed during the choice fires afterwards.
static func choose_grant(w: World, frame: InputFrame) -> void:
	var s := swap_answer(w, frame)
	if s == -2:
		return
	var code := w.swap_code
	close_swap(w)
	if s >= 0:
		take(w, code, s)
	for k in w.input_buffer.size():
		w.input_buffer[k] = 0


# --- Hash and reads -------------------------------------------------------------------------------------------
static func touched(w: World) -> bool:
	return not w.mod_slots.is_empty() or w.swap_code >= 0


static func hash_into(w: World, h: StateHasher) -> void:
	if not touched(w):
		return
	h.add_ints(w.mod_slots)
	for v in [w.swap_code, w.swap_source, w.swap_ref]:
		h.add_int(v)


## Per slot (in slot order): the card code, its id, name key, type (Offers.MOD / ABILITY), level, family (the card
## frame's, CardFrames.FAMILY_OF); and the slot count (WorldReader.build).
static func read(w: World) -> Dictionary:
	var slots: Array[Dictionary] = []
	for s in w.mod_slots.size():
		var code := w.mod_slots[s]
		var info := Offers.info(w, code)
		slots.append(
			{
				"code": code,
				"id": info["id"],
				"name_key": info["name_key"],
				"type": info["type"],
				"level": level_at(w, s),
			}
		)
	return {
		"slots": slots,
		"max": SLOTS,
		"swap_code": w.swap_code,
		"swap_source": w.swap_source,
	}
