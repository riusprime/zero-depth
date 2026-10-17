class_name Offers
extends RefCounted
## What an altar or chest offers (v0.4.0 BS, owner F8, F9, F13). A card is one int code, so the reward store, the
## PICKUP event and the hash need no new shape:
## - 0..ABILITY_BASE-1: a mod (the v0.3.0 items; the item index, as before);
## - ABILITY_BASE + i: ability i (a new one into a free slot, or a level-up of one you own);
## - STAT_BASE + stat x 10 + rarity: a stat card;
## - CURSE_BASE + c (v0.6.0 CU, owner S6): trade-off curse c, a cursed chest's cursed card (Curses.on_offer_rolled).
## Rolling (once per reward, on its first open, from the loot stream only): a free altar's first card is a new
## ability while a slot is free and one can be offered; every other card picks its type by the source's weights
## (RewardTable: [ability, stat, mod] for altars and chests), then an ability card uniformly among those that can
## apply (new or level-up), a stat by its card weight (v0.5.0 CP; uniform before) among stats under their cap at a
## rarity by the source's rarity weights
## (chests roll more rare and epic), a mod as the items always were (rare items weigh rare_weight). No card repeats
## in one offer (a stat card counts by stat). A world without abilities and stat cards (the v0.3.0 scenarios and
## tests) rolls items only, exactly as before.

const ABILITY_BASE := 1000
const STAT_BASE := 2000
const CURSE_BASE := 3000
const MOD := 0
const ABILITY := 1
const STAT := 2
const CURSE := 3
## A stat card's rarity: epic (v0.5.0 RT's epic altar offers only these).
const EPIC := 2
## v0.5.5 AR (X1b): the boss-only legendary rarity (BossReward's altar offers only legendary cards).
const LEGENDARY := 3
## v0.8.0 N7 (owner O61): a chest rolls this many cards (one, dealt with no choice: Rewards.deal); altars keep the
## data's offer_size.
const CHEST_CARDS := 1


static func enabled(w: World) -> bool:
	return not w.ability_tables.is_empty() or not w.stat_tables.is_empty()


static func type_of(code: int) -> int:
	if code >= CURSE_BASE:
		return CURSE
	if code >= STAT_BASE:
		return STAT
	if code >= ABILITY_BASE:
		return ABILITY
	return MOD


static func ability_code(idx: int) -> int:
	return ABILITY_BASE + idx


static func stat_code(stat: int, rarity: int) -> int:
	return STAT_BASE + stat * 10 + rarity


## v0.6.0 CU: the card for trade-off curse c.
static func curse_code(c: int) -> int:
	return CURSE_BASE + c


static func curse_of(code: int) -> int:
	return code - CURSE_BASE


static func ability_of(code: int) -> int:
	return code - ABILITY_BASE


static func stat_of(code: int) -> int:
	return (code - STAT_BASE) / 10


static func rarity_of(code: int) -> int:
	return (code - STAT_BASE) % 10


## Rolls reward i's offer (Rewards.interact, on its first open).
static func roll(w: World, i: int) -> PackedInt32Array:
	if Routes.is_epic_altar(w, i):
		return roll_epic(w)  # v0.5.0 RT
	if BossReward.is_legendary(w, i):
		return roll_legendary(w)  # v0.5.5 AR
	if w.rewards.kind[i] == RewardStore.Kind.CHEST:
		return draw(w, true, CHEST_CARDS)  # v0.8.0 N7
	return draw(w, false, w.reward_table.offer_size)


## Up to `size` cards by an altar's (`chest` false) or a chest's rules (v0.5.0 SH: the shop's stock draws as a chest).
static func draw(w: World, chest: bool, size: int) -> PackedInt32Array:
	var t := w.reward_table
	var rare := t.rare_weight_chest if chest else t.rare_weight_altar
	if not enabled(w):
		return ItemPool.draw_weighted(w, size, rare)
	var weights := t.chest_card_weights if chest else t.altar_card_weights
	var rarity := t.chest_rarity_weights if chest else t.altar_rarity_weights
	var epic := t.epic_permille_chest if chest else t.epic_permille_altar  # v0.8.0 RR
	var legend := t.legendary_permille_chest if chest else t.legendary_permille_altar
	var out := PackedInt32Array()
	if not chest:
		var fresh := _abilities(w, out, true)
		if not fresh.is_empty():
			out.append(ability_code(fresh[w.rng_loot.range_int(0, fresh.size() - 1)]))
	var guard := 0
	while out.size() < size and guard < 16:
		guard += 1
		# Indexed by card type (MOD, ABILITY, STAT); the data's weights are [ability, stat, mod].
		var pools := [_mods(w, out, rare, epic, legend), _abilities(w, out, false), _stats(w, out)]
		var wts := PackedInt32Array()
		for k in 3:
			var weight: int = weights[(k + 2) % 3]
			wts.append(weight if not (pools[k] as PackedInt32Array).is_empty() else 0)
		var kind := pick(w.rng_loot, wts)
		if kind < 0:
			break
		var pool: PackedInt32Array = pools[kind]
		match kind:
			ABILITY:
				out.append(ability_code(pool[w.rng_loot.range_int(0, pool.size() - 1)]))
			STAT:
				var sw := PackedInt32Array()  # v0.5.0 CP: by the cards' weights
				for st in pool:
					sw.append(w.stat_tables[st].weight)
				var s := pool[w.rng_loot.pick_weighted(sw)]
				out.append(stat_code(s, pick(w.rng_loot, rarity)))
			MOD:
				var mw := PackedInt32Array()
				for idx in pool:  # v0.8.0 BL (B5): the weapon's own ×1.5; v0.8.0 RR: by tier
					mw.append(ItemPool.card_weight(w, idx, rare, epic, legend))
				out.append(pool[w.rng_loot.pick_weighted(mw)])
	return out


## v0.5.0 RT: a Deep floor's epic altar: up to offer_size cards, each an epic stat card (a stat under its cap, by
## its card weight) or a level-up of an ability you own, never a curse; drawn from the loot stream, no repeats. The
## type is picked by the altar's [ability, stat] weights among the pools left. A world without abilities and stat
## cards offers rare-weighted mods.
static func roll_epic(w: World) -> PackedInt32Array:
	var t := w.reward_table
	if not enabled(w):
		return ItemPool.draw_weighted(w, t.offer_size, t.rare_weight_chest)
	var out := PackedInt32Array()
	var guard := 0
	while out.size() < t.offer_size and guard < 16:
		guard += 1
		var ups := PackedInt32Array()
		for idx in _abilities(w, out, false):
			if Abilities.owned(w, idx):
				ups.append(idx)
		var stats := _stats(w, out)
		var wts := PackedInt32Array(
			[
				t.altar_card_weights[0] if not ups.is_empty() else 0,
				t.altar_card_weights[1] if not stats.is_empty() else 0
			]
		)
		var kind := pick(w.rng_loot, wts)
		if kind < 0:
			break
		if kind == 0:
			out.append(ability_code(ups[w.rng_loot.range_int(0, ups.size() - 1)]))
		else:
			var sw := PackedInt32Array()
			for st in stats:
				sw.append(w.stat_tables[st].weight)
			out.append(stat_code(stats[w.rng_loot.pick_weighted(sw)], EPIC))
	return out


## v0.5.5 AR (X1b): the boss's legendary altar: up to the tier's offer_size cards from its own pool (LegendaryTable),
## each a legendary stat card (a pool stat under its cap, by its card weight) or a pool mod still in the item pool;
## the type by the tier's [stat, mod] weights among the pools left; loot stream, no repeats. v0.6.5 WN5b: with the
## tier's wand_level, every wand card of the run's pool is a pool mod too, taken at that level (BossReward.on_pick).
## v0.8.0 RR (owner O33; docs/roadmap/v0.8.0/evidence/RARITY.md): first one draw (range 0..999) against the tier's
## Legendary chance for this loop (LegendaryTable.chance): under it, the first card is a Legendary card (rarity
## LEGENDARY, uniform among those still in the pool; one more draw). A Legendary card is never a pool mod otherwise.
static func roll_legendary(w: World) -> PackedInt32Array:
	var t := w.legendary_table
	var out := PackedInt32Array()
	if t == null:
		return out
	var chance := t.chance(w.loop)
	if chance > 0 and (chance >= 1000 or w.rng_loot.range_int(0, 999) < chance):
		var legends := legendary_cards(w)
		if not legends.is_empty():
			out.append(legends[w.rng_loot.range_int(0, legends.size() - 1)])
	var guard := 0
	while out.size() < t.offer_size and guard < 16:
		guard += 1
		var stats := PackedInt32Array()
		for s in _stats(w, out):
			if t.stats.has(s) and w.stat_tables[s].amounts.size() > LEGENDARY:
				stats.append(s)
		var mods := PackedInt32Array()
		for idx in ItemPool.available(w, true):  # v0.6.0 MX4: the tier's legendary modifiers too
			var wand := t.wand_level > 0 and CardLevels.is_card(w, idx)  # v0.6.5 WN5b: level-5 versions
			var legend := w.item_tables[idx].rarity == ItemTable.LEGENDARY  # v0.8.0 RR: by the chance only
			if (t.mods.has(idx) or wand) and not legend and not out.has(idx):
				mods.append(idx)
		var wts := PackedInt32Array(
			[
				t.weights[0] if not stats.is_empty() else 0,
				t.weights[1] if not mods.is_empty() else 0
			]
		)
		var kind := pick(w.rng_loot, wts)
		if kind < 0:
			break
		if kind == 0:
			var sw := PackedInt32Array()
			for st in stats:
				sw.append(w.stat_tables[st].weight)  # _stats already leaves out a weight under 1
			out.append(stat_code(stats[w.rng_loot.pick_weighted(sw)], LEGENDARY))
		else:
			out.append(mods[w.rng_loot.range_int(0, mods.size() - 1)])
	return out


## v0.8.0 RR: the Legendary cards (ItemTable.LEGENDARY) still in the item pool, ascending (the boss's chance slot).
static func legendary_cards(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for idx in ItemPool.available(w, true):
		if w.item_tables[idx].rarity == ItemTable.LEGENDARY:
			out.append(idx)
	return out


## A weighted pick that allows zero weights (RngStream.pick_weighted refuses them): an index with a positive weight,
## or -1 when none has one. One draw from `rng`, only when some weight is positive.
static func pick(rng: RngStream, weights: PackedInt32Array) -> int:
	var idx := PackedInt32Array()
	var positive := PackedInt32Array()
	for k in weights.size():
		if weights[k] > 0:
			idx.append(k)
			positive.append(weights[k])
	if positive.is_empty():
		return -1
	return idx[rng.pick_weighted(positive)]


## Ability indices a card could apply to now, not already in `out`; `fresh_only`: new abilities only.
static func _abilities(w: World, out: PackedInt32Array, fresh_only: bool) -> PackedInt32Array:
	var left := PackedInt32Array()
	for idx in w.ability_tables.size():
		if out.has(ability_code(idx)) or not Abilities.can_take(w, idx):
			continue
		if fresh_only and Abilities.owned(w, idx):
			continue
		left.append(idx)
	return left


## Stats with a card table, under their cap, not already offered in `out`.
static func _stats(w: World, out: PackedInt32Array) -> PackedInt32Array:
	var left := PackedInt32Array()
	for s in w.stat_tables.size():
		var t := w.stat_tables[s]
		if t == null or t.weight <= 0 or Stats.at_cap(w, s):
			continue
		var taken := false
		for c in out:
			taken = taken or (type_of(c) == STAT and stat_of(c) == s)
		if not taken:
			left.append(s)
	return left


## Mods still in the item pool (ItemPool.available), not already in `out`. v0.8.0 RR: with the source's weights, a
## legendary one too while its weight is above 0, and never a card whose weight is 0 (pick_weighted refuses it).
static func _mods(
	w: World, out: PackedInt32Array, rare: int = 1, epic: int = -1, legend: int = 0
) -> PackedInt32Array:
	var left := PackedInt32Array()
	for idx in ItemPool.available(w, legend > 0):
		if not out.has(idx) and ItemPool.card_weight(w, idx, rare, epic, legend) > 0:
			left.append(idx)
	return left


## Takes card `code` (Rewards.choose, Shop.buy, an event's card, v0.6.0 CU a stolen core or a curse card).
## v0.6.0 MX2: through BuildSlots.take; a new
## modifier with the six slots full replaces slot `replace`, and without one it opens the swap choice by itself
## (BuildSlots.Source.GRANT: the world waits for the answer; a skip leaves the card).
static func apply(w: World, code: int, replace: int = -1) -> void:
	if BuildSlots.needs_swap(w, code) and replace < 0:
		BuildSlots.open_swap(w, code, BuildSlots.Source.GRANT, -1)
		return
	BuildSlots.take(w, code, replace)


## What the pick panel shows for card `code` (WorldReader.card_info): its type, id, name and description keys,
## rarity (0 common, 1 rare, 2 epic, 3 legendary), the amount in per mille (stats), and for an ability its level
## after the pick
## (1 = new).
static func info(w: World, code: int) -> Dictionary:
	match type_of(code):
		ABILITY:
			var idx := ability_of(code)
			var t := w.ability_tables[idx]
			return {
				"type": ABILITY,
				"id": t.id,
				"kind": t.kind,
				"name_key": t.name_key,
				"desc_key": t.desc_key,
				"rarity": 1 if t.rare else 0,
				"level": mini(Abilities.level_of(w, idx) + 1, AbilityTable.MAX_LEVEL),
				"amount": 0,
				"modifier": t.is_modifier(),  # v0.6.0 MX2: it takes a modifier slot
			}
		STAT:
			var st := w.stat_tables[stat_of(code)]
			return {
				"type": STAT,
				"id": st.id,
				"kind": st.stat,
				"name_key": st.name_key,
				"desc_key": st.desc_key,
				"rarity": rarity_of(code),
				"level": 0,
				"amount": st.amounts[rarity_of(code)],
				# v0.5.0 CP: a rule card's second number
				"side": st.side[rarity_of(code)] if rarity_of(code) < st.side.size() else 0,
			}
		CURSE:  # v0.6.0 CU: a trade-off curse card, rare-level: its face is the upside (the panel adds the drawback)
			var ct := w.ev.curses[curse_of(code)]
			return {
				"type": CURSE,
				"id": ct.id,
				"kind": ct.up_effect,
				"name_key": ct.name_key,
				"desc_key": ct.up_desc_key,
				"rarity": 1,
				"level": 0,
				"amount": ct.up_amount,
				"curse": curse_of(code),
			}
	var it := w.item_tables[code]
	var rarity := it.tier()  # v0.6.0 MX4: a legendary modifier; v0.8.0 RR: the four tiers in order
	var face := item_keys(w, it)  # v0.6.5 WN5a: T4's face per weapon
	return {
		"modifier": BuildSlots.is_slot_item(it),  # v0.6.0 MX2: it takes a modifier slot
		"type": MOD,
		"id": it.id,
		"kind": it.kind,
		"name_key": face[0],
		"desc_key": face[1],
		"rarity": rarity,
		"level": 0,
		"amount": 0,
		"wand": CardLevels.is_card(w, code),  # v0.6.5 WN5b: a wand card (the legendary tier's level-5 version)
	}


## v0.6.5 WN5a (WAND.md T4): item `it`'s name and description keys for this run: its Gun face on a Gun run when it
## has one (On Crit), else its own (On Finisher). Pure.
static func item_keys(w: World, it: ItemTable) -> Array[StringName]:
	if it.name_key_gun != &"" and PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w):
		return [it.name_key_gun, it.desc_key_gun]
	return [it.name_key, it.desc_key]
