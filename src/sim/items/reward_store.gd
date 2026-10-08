class_name RewardStore
extends RefCounted
## Altars and chests on the floor (v0.3.0 E), as parallel arrays in ascending id order. Hashed.
## An altar is free; a chest costs `price` shards. Opening one rolls its offer once (OFFER_SLOTS item indices,
## -1 for an empty slot) and keeps it until a card is taken, so cancelling and reopening shows the same cards.

## v0.5.5 AR: LEGENDARY, the boss's free legendary altar (BossReward). Appended, never inserted: the kind is hashed.
enum Kind { ALTAR, CHEST, LEGENDARY }

const OFFER_SLOTS := 3

var ids := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var kind := PackedInt32Array()
## Shards to open (0 for an altar).
var price := PackedInt32Array()
## 1 once the offer was rolled.
var rolled := PackedInt32Array()
## OFFER_SLOTS item indices per reward (index into World.item_tables, -1 = empty), flattened.
var offer := PackedInt32Array()


func size() -> int:
	return ids.size()


func add(id: int, p: Vector2, p_kind: int, p_price: int) -> void:
	ids.append(id)
	pos_x.append(p.x)
	pos_y.append(p.y)
	kind.append(p_kind)
	price.append(p_price)
	rolled.append(0)
	for k in OFFER_SLOTS:
		offer.append(-1)


func pos(i: int) -> Vector2:
	return Vector2(pos_x[i], pos_y[i])


## The store index of reward `id`, or -1.
func index_of(id: int) -> int:
	return ids.find(id)


## Reward i's offered item indices (empty slots left out), in card order.
func offer_of(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in OFFER_SLOTS:
		var idx := offer[i * OFFER_SLOTS + k]
		if idx >= 0:
			out.append(idx)
	return out


func set_offer(i: int, items: PackedInt32Array) -> void:
	rolled[i] = 1
	for k in OFFER_SLOTS:
		offer[i * OFFER_SLOTS + k] = items[k] if k < items.size() else -1


func remove_at(i: int) -> void:
	ids.remove_at(i)
	pos_x.remove_at(i)
	pos_y.remove_at(i)
	kind.remove_at(i)
	price.remove_at(i)
	rolled.remove_at(i)
	for k in OFFER_SLOTS:
		offer.remove_at(i * OFFER_SLOTS)


func hash_into(h: StateHasher) -> void:
	h.add_ints(ids)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)
	h.add_ints(kind)
	h.add_ints(price)
	h.add_ints(rolled)
	h.add_ints(offer)
