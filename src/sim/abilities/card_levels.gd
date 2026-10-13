class_name CardLevels
extends RefCounted
## v0.6.5 WN3 (docs/design/WAND.md rule 6: "A duplicate levels up. Taking a card you already hold makes it stronger
## (levels 1–5) and uses no new slot"): the levels of the wand's cards (World.card_levels, by item index). A wand card
## is an item tagged `wand` (ItemTable.tags): the Gun pool G1–G16 (WN3), and the other pools as they ship. While you
## hold one below MAX_LEVEL it stays in the offers (altars, chests, the shop, events, cores), and taking it again
## raises its level instead of taking a slot. Its modifiers compile at that level (ModifierTable.at: each op's
## per_level, Modifiers.build_modifiers). Deterministic; no randomness.

const MAX_LEVEL := 5
const TAG := "wand"


## Item `idx` is a wand card (it levels up).
static func is_card(w: World, idx: int) -> bool:
	return idx >= 0 and idx < w.item_tables.size() and w.item_tables[idx].tags.has(TAG)


## The level of item `idx` (1 for an item that never levelled, and for one not held).
static func level(w: World, idx: int) -> int:
	if idx < 0 or idx >= w.card_levels.size() or not w.items_owned.has(idx):
		return 1
	return maxi(1, w.card_levels[idx])


## Taking item `idx` now would do something: it isn't held, or it is a wand card below MAX_LEVEL.
static func can_take(w: World, idx: int) -> bool:
	if not w.items_owned.has(idx):
		return true
	return is_card(w, idx) and level(w, idx) < MAX_LEVEL


## A held wand card taken again: one level up (at most MAX_LEVEL); the build compiles again. False if `idx` isn't a
## held wand card below MAX_LEVEL.
static func level_up(w: World, idx: int) -> bool:
	if not w.items_owned.has(idx) or not is_card(w, idx) or level(w, idx) >= MAX_LEVEL:
		return false
	_store(w, idx, level(w, idx) + 1)
	Modifiers.invalidate(w)
	return true


## Sets held wand card `idx` to `lvl` (1..MAX_LEVEL; the dev panel's TEST HELPER and the labs). False if `idx` isn't a
## held wand card.
static func set_level(w: World, idx: int, lvl: int) -> bool:
	if not w.items_owned.has(idx) or not is_card(w, idx):
		return false
	_store(w, idx, clampi(lvl, 1, MAX_LEVEL))
	Modifiers.invalidate(w)
	return true


## Item `idx` enters the build fresh (or leaves it): back to level 1.
static func reset(w: World, idx: int) -> void:
	if idx >= 0 and idx < w.card_levels.size() and w.card_levels[idx] > 1:
		w.card_levels[idx] = 0
		Modifiers.invalidate(w)


static func _store(w: World, idx: int, v: int) -> void:
	if w.card_levels.size() <= idx:
		w.card_levels.resize(maxi(idx + 1, w.item_tables.size()))  # a packed resize fills with 0
	w.card_levels[idx] = v


## Hashed once a card levelled (BuildSlots.hash_into).
static func hash_into(w: World, h: StateHasher) -> void:
	if not w.card_levels.is_empty():
		h.add_ints(w.card_levels)
