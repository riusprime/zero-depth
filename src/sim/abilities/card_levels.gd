class_name CardLevels
extends RefCounted
## v0.6.5 WN4 (docs/design/WAND.md rule 6, owner G1 "Approve all": "A duplicate levels up. Taking a card you already
## hold makes it stronger (levels 1–5) and uses no new slot"): the levels of the wand's item cards. An ability
## modifier keeps its own level (Abilities); an item card's is World.item_levels[its item index] (0 or 1 = level 1),
## run-long (RunCarry) and hashed with the slots (BuildSlots.hash_into).
##
## A card levels only when its ItemTable.max_level is above 1 (the pool cards, ItemDefinition.max_level). While a held
## card is below its top level it stays in the offers (ItemPool), and taking it again (BuildSlots.take) raises its
## level in the slot it holds: the compile then reads its ModifierTable at that level (ModifierTable.at_level: every op
## grown by its per_level). Deterministic; no randomness.


## Item card `code`'s level now (1 when it doesn't level or isn't held).
static func level_of(w: World, code: int) -> int:
	if code < 0 or code >= w.item_levels.size():
		return 1
	return maxi(1, w.item_levels[code])


## The highest level item card `code` reaches (1 for a card that never levels).
static func max_of(w: World, code: int) -> int:
	if code < 0 or code >= w.item_tables.size():
		return 1
	return maxi(1, w.item_tables[code].max_level)


## The player holds item card `code` and it can still level up.
static func can_level(w: World, code: int) -> bool:
	return w.items_owned.has(code) and level_of(w, code) < max_of(w, code)


## Item card `code` (held) goes up one level; the specs compile again on their next read.
static func level_up(w: World, code: int) -> void:
	if not can_level(w, code):
		return
	if w.item_levels.size() <= code:
		w.item_levels.resize(code + 1)
	w.item_levels[code] = level_of(w, code) + 1
	Modifiers.invalidate(w)


## Item card `code` left the build: a later pick starts it at level 1 again.
static func forget(w: World, code: int) -> void:
	if code >= 0 and code < w.item_levels.size() and w.item_levels[code] != 0:
		w.item_levels[code] = 0
		Modifiers.invalidate(w)


## Hashed once a card levelled (worlds without, the kernel goldens among them, hash as before).
static func hash_into(w: World, h: StateHasher) -> void:
	for v in w.item_levels:
		if v > 1:
			h.add_ints(w.item_levels)
			return
