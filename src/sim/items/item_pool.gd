class_name ItemPool
extends RefCounted
## Which items a floor offers: no duplicates on one floor (v0.2.0 PLAN). Draws use the loot stream only.
## v0.3.0 E: an item held in an altar's or chest's rolled offer is out of the pool until that offer is taken, and
## an item that needs another utility (ItemTable.requires_utility) or weapon (requires_weapon) is never drawn.


## Up to `count` item indices, drawn without replacement from the items neither owned, nor lying on the floor,
## nor held in a reward's offer. Fewer when the pool runs out. The candidates are in ascending index order, so the
## same seed and state give the same draws.
static func draw(w: World, count: int) -> PackedInt32Array:
	var left := available(w)
	var out := PackedInt32Array()
	while out.size() < count and not left.is_empty():
		var k := w.rng_loot.range_int(0, left.size() - 1)
		out.append(left[k])
		left.remove_at(k)
	return out


## Like draw, but a rare item weighs `rare_weight` against a common one's 1 (v0.3.0 E: chests roll more rares).
static func draw_weighted(w: World, count: int, rare_weight: int) -> PackedInt32Array:
	var left := available(w)
	var out := PackedInt32Array()
	while out.size() < count and not left.is_empty():
		var weights := PackedInt32Array()
		for idx in left:
			weights.append(card_weight(w, idx, rare_weight))
		var k := Offers.pick(w.rng_loot, weights)
		if k < 0:
			break
		out.append(left[k])
		left.remove_at(k)
	return out


## v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md B5): item `idx`'s weight in a mod draw: `rare_weight` for a rare one
## (1 for a common one), × RewardTable.own_weapon_card_permille when it is a wand card of the run's own weapon
## (requires_weapon: the Blade's cards on a Blade run), × 1000 otherwise (a shared card, a trigger, a passive).
## v0.8.0 RR (owner O33): an epic one weighs `epic_permille` / 1000 and a legendary one `legendary_permille` / 1000 of
## a common one (the same integers as before for common and rare cards: base per mille × own / 1000). A world without
## those weights (the v0.3.0 draw) weighs an epic card as a rare one. v0.8.0 FL: then × the floor stage's multiplier
## for the card's category (LootPacing.weigh; × 1 in a world without a pacing table).
static func card_weight(
	w: World, idx: int, rare_weight: int, epic_permille: int = -1, legendary_permille: int = 0
) -> int:
	var it := w.item_tables[idx]
	var base := 1000
	match it.rarity:
		ItemTable.RARE:
			base = rare_weight * 1000
		ItemTable.EPIC:
			base = epic_permille if epic_permille >= 0 else rare_weight * 1000
		ItemTable.LEGENDARY:
			base = legendary_permille
	var own := it.requires_weapon != 0 and CardLevels.is_card(w, idx)
	var out := base * (w.reward_table.own_weapon_card_permille if own else 1000) / 1000
	if it.offer_weight_permille != 1000:  # v0.8.0 RM: a mutation's low weight (the others' integers unchanged)
		out = out * it.offer_weight_permille / 1000
	return LootPacing.weigh(w, idx, out)  # v0.8.0 FL: × the floor stage's multiplier for its category


## The item indices that may still be drawn, ascending. v0.6.0 MX4: a legendary item only with `legendary` (the
## boss's tier and a boss's core; v0.8.0 RR: an altar's, a chest's and the shop's draw at their legendary weight,
## Offers.draw; events and elites never draw one). v0.8.0 FL: a held wand card only below the floor's level ceiling
## (LootPacing.ceiling), or below `ceiling` when given (the boss's upgrade, a jackpot).
static func available(w: World, legendary: bool = false, ceiling: int = -1) -> PackedInt32Array:
	var left := PackedInt32Array()
	for idx in w.item_tables.size():
		if (
			(legendary or w.item_tables[idx].rarity != ItemTable.LEGENDARY)
			and CardLevels.can_take(w, idx, ceiling)  # v0.6.5 WN3: a held wand card below its ceiling too
			and not w.pickups.item.has(idx)
			and not w.rewards.offer.has(idx)
			and not w.ev.roll_card.has(idx)  # v0.5.0 EV: a mod an event panel shows
			and not w.shop.offer.has(idx)  # v0.5.0 SH: a mod in the shop's stock
			and not w.cores.card.has(idx)  # v0.6.0 CU: a mod an elite's or boss's core holds
			and usable(w, idx)
		):
			left.append(idx)
	return left


## The item works with the player's utility (v0.3.0 E: Bulwark needs the guard) and weapon (v0.3.0 L15: a Gun run
## is never offered blade items, nor a Blade run bolt items), and a heat item only in a world with heat (L18).
## v0.5.0 CP: an ability mod only while the player owns its ability. v0.6.5 WN5b: never a retired v0.6 card.
static func usable(w: World, idx: int) -> bool:
	var it := w.item_tables[idx]
	# v0.6.5 WN5a: the wand's trigger cards (WAND.md T1–T4) are offered in both weapons' runs.
	if it.retired:
		return false  # v0.6.5 WN5b: a retired v0.6 card (WAND.md; data/wand/migration.tres)
	if it.requires_heat and w.heat == null:
		return false
	var need := it.requires_utility
	if need >= 0 and need != Abilities.utility(w):  # v0.4.0: the utility comes from an ability
		return false
	if it.requires_ability >= 0 and Abilities.owned_of_kind(w, it.requires_ability) == null:
		return false  # v0.5.0 CP: an ability mod only while you own the ability
	return it.requires_weapon == 0 or (it.requires_weapon & w.player.weapons) != 0
