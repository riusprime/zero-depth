class_name PickupStore
extends RefCounted
## Item pickups lying on the floor (pedestals), as parallel arrays in ascending id order. Hashed.

var ids := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
## Index into World.item_tables.
var item := PackedInt32Array()


func size() -> int:
	return ids.size()


func add(id: int, p: Vector2, item_index: int) -> void:
	ids.append(id)
	pos_x.append(p.x)
	pos_y.append(p.y)
	item.append(item_index)


func pos(i: int) -> Vector2:
	return Vector2(pos_x[i], pos_y[i])


func remove_at(i: int) -> void:
	ids.remove_at(i)
	pos_x.remove_at(i)
	pos_y.remove_at(i)
	item.remove_at(i)


func hash_into(h: StateHasher) -> void:
	h.add_ints(ids)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)
	h.add_ints(item)
