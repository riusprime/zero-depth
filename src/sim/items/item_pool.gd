class_name ItemPool
extends RefCounted
## Which items a floor offers: no duplicates on one floor (v0.2.0 PLAN). Draws use the loot stream only.


## Up to `count` item indices, drawn without replacement from the items neither owned nor already lying on the
## floor. Fewer when the pool runs out. The candidates are in ascending index order, so the same seed and state
## give the same draws.
static func draw(w: World, count: int) -> PackedInt32Array:
	var left := PackedInt32Array()
	for idx in w.item_tables.size():
		if not w.items_owned.has(idx) and not w.pickups.item.has(idx):
			left.append(idx)
	var out := PackedInt32Array()
	while out.size() < count and not left.is_empty():
		var k := w.rng_loot.range_int(0, left.size() - 1)
		out.append(left[k])
		left.remove_at(k)
	return out
