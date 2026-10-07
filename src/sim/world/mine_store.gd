class_name MineStore
extends RefCounted
## Mines on the floor (v0.4.0 EN; Mines), as parallel arrays in drop order: id, the Mine Layer that dropped it, where
## it lies, its circle's radius, its damage, ticks left while idle, and its fuse (-1 idle, else ticks since it armed,
## out of fuse_total). World hashes it only once a mine was ever dropped (touched), so worlds without Mine Layers hash
## as before.

const INT_FIELDS: Array[StringName] = [&"ids", &"owner", &"damage", &"life", &"fuse", &"fuse_total"]
const FLOAT_FIELDS: Array[StringName] = [&"pos_x", &"pos_y", &"radius"]

var ids := PackedInt32Array()
var owner := PackedInt32Array()
var damage := PackedInt32Array()
var life := PackedInt32Array()
var fuse := PackedInt32Array()
var fuse_total := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var radius := PackedFloat32Array()
var touched := false


func size() -> int:
	return ids.size()


func add(
	id: int, owner_id: int, at: Vector2, r: float, p_damage: int, p_life: int, p_fuse: int
) -> void:
	touched = true
	ids.append(id)
	owner.append(owner_id)
	damage.append(p_damage)
	life.append(p_life)
	fuse.append(-1)
	fuse_total.append(p_fuse)
	pos_x.append(at.x)
	pos_y.append(at.y)
	radius.append(r)


func pos(k: int) -> Vector2:
	return Vector2(pos_x[k], pos_y[k])


## Removes the entries at the given ascending indices, keeping order.
func remove_sorted(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	var keep := PackedInt32Array()
	var j := 0
	for k in ids.size():
		if j < indices.size() and indices[j] == k:
			j += 1
		else:
			keep.append(k)
	for f in INT_FIELDS:
		set(f, ProjectileStore._pick_i(get(f), keep))
	for f in FLOAT_FIELDS:
		set(f, ProjectileStore._pick_f(get(f), keep))


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
