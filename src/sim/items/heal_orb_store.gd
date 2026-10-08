class_name HealOrbStore
extends RefCounted
## Heal orbs lying on the floor (v0.4.0 TU, owner D8; HealOrbs), as parallel arrays in drop order: id and where it
## lies. World hashes it only once an orb was ever dropped (touched), so worlds without kills hash as before.

const INT_FIELDS: Array[StringName] = [&"ids"]
const FLOAT_FIELDS: Array[StringName] = [&"pos_x", &"pos_y"]

var ids := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var touched := false


func size() -> int:
	return ids.size()


func add(id: int, at: Vector2) -> void:
	touched = true
	ids.append(id)
	pos_x.append(at.x)
	pos_y.append(at.y)


func pos(k: int) -> Vector2:
	return Vector2(pos_x[k], pos_y[k])


func remove_at(k: int) -> void:
	ids.remove_at(k)
	pos_x.remove_at(k)
	pos_y.remove_at(k)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
