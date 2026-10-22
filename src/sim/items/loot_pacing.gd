class_name LootPacing
extends RefCounted
## v0.8.0 FL (owner O91, "floor-paced loot"; docs/roadmap/v0.8.0/BALANCE_PASS.md "FL"): the one pacing rule every card
## source draws through (World.loot_pacing, LootPacingTable; null = no pacing, the draws as before FL).
## - The stage: floor 1, 2, 3 of the first loop, and DEEP for a Deep floor or any floor of a later loop.
## - A wand card's draw weight × its category's multiplier for the stage (ItemPool.card_weight, and the events' and
##   cores' own weights): every altar, chest, shop restock and reroll, event and core draw.
## - The level ceiling: a held wand card at the stage's ceiling isn't offered as a duplicate (CardLevels.can_take, so
##   ItemPool.available, Shop.can_apply, the events' block and the core's drop re-check all refuse it). Higher
##   duplicates come on later floors; the boss's upgrade reaches the next stage's ceiling (Offers.roll_legendary).
## - The guarantee (Offers.roll): the floor's first `guaranteed_altars` regular altars each show at least one card
##   compatible with the wand (compatible()); if none does, one card is replaced by one that does (loot stream).
## - The jackpot (Offers.roll): per regular offer (an altar's or a chest's) one draw against jackpot_permille; on a hit
##   one card is replaced by a jackpot card (a held wand card at the ceiling, which it lifts one level past it, or a
##   mutation), recorded in World.loot_jackpots so the pick card says "Jackpot".
## Dev and debug grants never come through here. Deterministic: draws only from w.rng_loot, only with a table.

## The stages, the index of every per-stage array of LootPacingTable.
enum Stage { FLOOR_1, FLOOR_2, FLOOR_3, DEEP }
## ItemTable.loot_category (ItemDefinition.LOOT_CATEGORIES, in that order). Stat cards are their own category (an
## Offers STAT code, not an item) and keep their weights.
enum Category { OTHER, FORM, ELEMENT, ADVANCED, TRIGGER, MUTATION }


## The stage of the floor `w` is on: DEEP on a Deep floor or a later loop, else its floor (3 and past it: FLOOR_3).
static func stage(w: World) -> int:
	if w.loop > 1 or Routes.is_deep(w):
		return Stage.DEEP
	return clampi(w.floor_index - 1, Stage.FLOOR_1, Stage.FLOOR_3)


## The stage of the floor after this one (floor 3's next is the next loop: DEEP).
static func next_stage(w: World) -> int:
	return mini(stage(w) + 1, Stage.DEEP)


## Item `idx`'s pacing category (OTHER for an ability or stat code, or an item without one).
static func category(w: World, idx: int) -> int:
	if idx < 0 or idx >= w.item_tables.size():
		return Category.OTHER
	return w.item_tables[idx].loot_category


## Item `idx`'s draw-weight multiplier now, per mille (1000 without a table or for OTHER).
static func weight_permille(w: World, idx: int) -> int:
	var t := w.loot_pacing
	var cat := category(w, idx)
	if t == null or cat == Category.OTHER:
		return 1000
	return t.weights[stage(w)][cat - 1]


## `base` × item `idx`'s multiplier (integer math, rounded down).
static func weigh(w: World, idx: int, base: int) -> int:
	var m := weight_permille(w, idx)
	return base if m == 1000 else base * m / 1000


## The highest level a held wand card is offered up to now (CardLevels.MAX_LEVEL without a table).
static func ceiling(w: World) -> int:
	return _ceiling_at(w, stage(w))


## The next stage's ceiling (the boss's upgrade).
static func next_ceiling(w: World) -> int:
	return _ceiling_at(w, next_stage(w))


static func _ceiling_at(w: World, s: int) -> int:
	var t := w.loot_pacing
	if t == null:
		return CardLevels.MAX_LEVEL
	return clampi(t.ceilings[s], 1, CardLevels.MAX_LEVEL)


## Item `idx` is a modifier compatible with the wand: a usable wand card that changes the attack you have (a form, an
## element or an advanced card; never a trigger nor a mutation) and that would act where it lands (a new card at the
## wand's end, a held one where it sits): not past the third trigger, and not a card that does nothing right of a
## trigger (WandTable.after_trigger_dead) once a trigger is left of it.
static func compatible(w: World, idx: int) -> bool:
	if Offers.type_of(idx) != Offers.MOD or not CardLevels.is_card(w, idx):
		return false
	var cat := category(w, idx)
	if cat != Category.FORM and cat != Category.ELEMENT and cat != Category.ADVANCED:
		return false
	if not ItemPool.usable(w, idx):
		return false
	var at := w.mod_slots.find(idx)
	if at < 0:
		at = w.mod_slots.size()
	var cuts := 0
	for k in at:
		if Wand.trigger_of(w, w.mod_slots[k]) >= 0:
			cuts += 1
	if cuts > WandCompile.MAX_DEPTH:
		return false
	return cuts == 0 or not Wand.dead_after_trigger(w, w.item_tables[idx].id)


## Offers.roll, a regular altar's fresh offer `out`: while the floor's guaranteed altars aren't used up (one is used
## by this roll), an offer without a compatible card gets one in place of one card (_slot), drawn from the item pool
## by the altar's weights. No draw when it already holds one, or when nothing compatible is left.
static func guarantee(w: World, out: PackedInt32Array) -> PackedInt32Array:
	var t := w.loot_pacing
	if t == null or out.is_empty() or w.loot_guaranteed >= t.guaranteed_altars[stage(w)]:
		return out
	w.loot_guaranteed += 1
	for c in out:
		if compatible(w, c):
			return out
	var rt := w.reward_table
	var cands := PackedInt32Array()
	var weights := PackedInt32Array()
	for idx in ItemPool.available(w):
		if out.has(idx) or not compatible(w, idx):
			continue
		var wt := ItemPool.card_weight(w, idx, rt.rare_weight_altar, rt.epic_permille_altar, 0)
		if wt > 0:
			cands.append(idx)
			weights.append(wt)
	if cands.is_empty():
		return out
	var picked := cands[w.rng_loot.pick_weighted(weights)]
	out[_slot(w, out)] = picked
	return out


## Offers.roll, reward i's (an altar's or a chest's) fresh offer `out`: one draw against jackpot_permille; on a hit,
## one card (_slot: never the only compatible one) becomes a jackpot card, uniformly among jackpot_pool, and the pair
## (reward id, card) joins World.loot_jackpots. A hit with an empty pool changes nothing.
static func jackpot(w: World, i: int, out: PackedInt32Array) -> PackedInt32Array:
	var t := w.loot_pacing
	if t == null or t.jackpot_permille <= 0 or out.is_empty():
		return out
	if w.rng_loot.range_int(0, 999) >= t.jackpot_permille:
		return out
	var pool := jackpot_pool(w, out)
	if pool.is_empty():
		return out
	var code := pool[w.rng_loot.range_int(0, pool.size() - 1)]
	out[_slot(w, out)] = code
	w.loot_jackpots.append(w.rewards.ids[i])
	w.loot_jackpots.append(code)
	return out


## The jackpot cards now, ascending: a held wand card exactly at the ceiling (and below CardLevels.MAX_LEVEL; taking
## it lifts it one past the ceiling), or a mutation still in the pool; never a card already in `out` or held in
## another offer (ItemPool.available's rules, the ceiling one level higher).
static func jackpot_pool(w: World, out: PackedInt32Array) -> PackedInt32Array:
	var cap := ceiling(w)
	var pool := PackedInt32Array()
	for idx in ItemPool.available(w, true, cap + 1):
		if out.has(idx):
			continue
		var held := w.items_owned.has(idx) and CardLevels.level(w, idx) == cap
		if held or category(w, idx) == Category.MUTATION:
			pool.append(idx)
	return pool


## Whether card `code` in reward `id`'s offer is a jackpot card (the pick card's "Jackpot").
static func is_jackpot(w: World, id: int, code: int) -> bool:
	for k in range(0, w.loot_jackpots.size() - 1, 2):
		if w.loot_jackpots[k] == id and w.loot_jackpots[k + 1] == code:
			return true
	return false


## The card of `out` a guarantee or a jackpot replaces: the last one that isn't the only compatible card, never an
## altar's leading fresh ability card (Offers.draw) while another card is there.
static func _slot(w: World, out: PackedInt32Array) -> int:
	var first := 1 if out.size() > 1 and Offers.type_of(out[0]) == Offers.ABILITY else 0
	var fits := 0
	for c in out:
		if compatible(w, c):
			fits += 1
	for k in range(out.size() - 1, first - 1, -1):
		if fits != 1 or not compatible(w, out[k]):
			return k
	return out.size() - 1


## Hashed once used (World.hash_into): the floor's guaranteed altars used and its jackpots.
static func hash_into(w: World, h: StateHasher) -> void:
	if w.loot_guaranteed != 0:
		h.add_int(w.loot_guaranteed)
	if not w.loot_jackpots.is_empty():
		h.add_ints(w.loot_jackpots)
