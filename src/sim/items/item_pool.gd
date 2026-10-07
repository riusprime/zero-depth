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
			weights.append(rare_weight if w.item_tables[idx].rarity == ItemTable.RARE else 1)
		var k := w.rng_loot.pick_weighted(weights)
		if k < 0:
			break
		out.append(left[k])
		left.remove_at(k)
	return out


## The item indices that may still be drawn, ascending.
static func available(w: World) -> PackedInt32Array:
	var left := PackedInt32Array()
	for idx in w.item_tables.size():
		if (
			not w.items_owned.has(idx)
			and not w.pickups.item.has(idx)
			and not w.rewards.offer.has(idx)
			and _usable(w, idx)
		):
			left.append(idx)
	return left


## The item works with the player's utility (v0.3.0 E: Bulwark needs the guard) and weapon (v0.3.0 L15: a Gun run
## is never offered blade items, nor a Blade run bolt items).
static func _usable(w: World, idx: int) -> bool:
	var it := w.item_tables[idx]
	var need := it.requires_utility
	if need >= 0 and need != w.player.utility:
		return false
	return it.requires_weapon == 0 or (it.requires_weapon & w.player.weapons) != 0
