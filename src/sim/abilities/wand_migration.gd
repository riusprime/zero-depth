class_name WandMigration
extends RefCounted
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards": "Old saves load: each held card maps to its new
## card, in pick order. A card without a match is refunded as shards"; SIM_CONTRACTS §8h): a build that still holds a
## retired v0.6 card (an old save's carry or snapshot) is rewritten once, when it loads:
## - the build's cards are read in wand order (World.mod_slots: a v0.6 save's pick order), then any held retired card
##   not in a slot (abilities in slot order, then items in pickup order);
## - a retired card becomes its row's card for the run's weapon (WandTable.migrate_*: data/wand/migration.tres) in
##   the same place in the wand; a target already held, or met twice, levels up instead (WAND.md rule 6): the levels
##   add (an ability its level, a legendary card CardLevels.MAX_LEVEL, any other card 1), at most MAX_LEVEL;
## - a card without a match (an empty target, or one not in the data yet) is refunded as shards: what the shop's
##   salvage pays for it on this floor (ShopTable.sell_price by its rarity for an item; ability_refund_per_level × its
##   level for an ability; Shop.sell_list's numbers).
## A world without the wand table (a lab) or without rows changes nothing. Deterministic, idempotent (a migrated
## build holds no retired card), no randomness (EI-05).


## Rewrites `w`'s build (class doc). Returns the shards refunded (0 when nothing was retired).
static func run(w: World) -> int:
	var t := w.wand_table
	if t == null or t.migrate_ids.is_empty():
		return 0
	var order := _cards(w)
	var any := false
	for code in order:
		any = any or _row(w, code) >= 0
	if not any:
		return 0
	var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	var out := PackedInt32Array()
	var gained := {}  # target item index -> levels it gains
	var refund := 0
	var gone := PackedInt32Array()
	for code in order:
		var row := _row(w, code)
		if row < 0:
			if not out.has(code):
				out.append(code)
			continue
		gone.append(code)
		var target := _item(w, t.migrate_gun[row] if gun else t.migrate_blade[row])
		if target < 0:
			refund += refund_of(w, code)
			continue
		gained[target] = int(gained.get(target, 0)) + _levels(w, code)
		if not out.has(target):
			out.append(target)
	for code in gone:
		_drop(w, code)
	for target: int in gained:
		var held := w.items_owned.has(target)
		var base := CardLevels.level(w, target) if held else 0
		if not held:
			CardLevels.reset(w, target)
			w.add_item(target)
		CardLevels.set_level(w, target, mini(CardLevels.MAX_LEVEL, base + int(gained[target])))
	var keep := PackedInt32Array()
	for code in out:
		if BuildSlots.held(w, code) and BuildSlots.is_modifier(w, code):
			keep.append(code)
	w.mod_slots = keep
	BuildSlots.sync(w)
	Modifiers.invalidate(w)
	w.shards += refund
	return refund


## The row of the migration table that retires card `code` (an Offers code: an item or an ability), or -1.
static func _row(w: World, code: int) -> int:
	var id := &""
	match Offers.type_of(code):
		Offers.MOD:
			if code < 0 or code >= w.item_tables.size():
				return -1
			id = w.item_tables[code].id
		Offers.ABILITY:
			var a := Offers.ability_of(code)
			if a < 0 or a >= w.ability_tables.size():
				return -1
			id = w.ability_tables[a].id
		_:
			return -1
	return w.wand_table.migrate_ids.find(id)


## Every card of the build in wand order, then held cards outside the slots (abilities, then items).
static func _cards(w: World) -> PackedInt32Array:
	var out := w.mod_slots.duplicate()
	for idx in w.ability_owned:
		var c := Offers.ability_code(idx)
		if not out.has(c):
			out.append(c)
	for idx in w.items_owned:
		if not out.has(idx):
			out.append(idx)
	return out


## The item index of `id`, or -1 (no id, or not in the data: a pending target).
static func _item(w: World, id: StringName) -> int:
	if String(id).is_empty():
		return -1
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


## The levels card `code` carries over: an ability its level, a legendary item the top level, any other item 1.
static func _levels(w: World, code: int) -> int:
	if Offers.type_of(code) == Offers.ABILITY:
		return maxi(1, Abilities.level_of(w, Offers.ability_of(code)))
	if w.item_tables[code].rarity == ItemTable.LEGENDARY:
		return CardLevels.MAX_LEVEL
	return 1


## The shards a card without a match refunds: the shop's salvage price for it on this floor (Shop.sell_list).
static func refund_of(w: World, code: int) -> int:
	var st := w.shop_table if w.shop_table != null else ShopTable.new()
	if Offers.type_of(code) == Offers.ABILITY:
		return st.ability_refund_per_level * maxi(1, Abilities.level_of(w, Offers.ability_of(code)))
	return st.sell_price(Shop.rarity(w, code), w.floor_index)


## Card `code` leaves the build: an ability with its slot state (Abilities.remove_slot), an item with its combos.
static func _drop(w: World, code: int) -> void:
	if Offers.type_of(code) == Offers.ABILITY:
		var s := w.ability_owned.find(Offers.ability_of(code))
		if s >= 0:
			Abilities.remove_slot(w, s)
	elif w.items_owned.has(code):
		Shop.remove_item(w, code)
		CardLevels.reset(w, code)
