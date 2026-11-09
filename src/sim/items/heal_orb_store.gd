class_name HealOrbStore
extends RefCounted
## Heal orbs lying on the floor (v0.4.0 TU, owner D8; HealOrbs), as parallel arrays in drop order: id and where it
## lies. v0.11.0 F3: and the earning state: the meter's points and the tick the pickup cooldown ends. World hashes it
## only once used (touched: a kill earned points, or an orb lay), so worlds without kills hash as before.

const INT_FIELDS: Array[StringName] = [&"ids"]
const FLOAT_FIELDS: Array[StringName] = [&"pos_x", &"pos_y"]

var ids := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
## v0.11.0 F3: the points earned toward the next orb.
var meter := 0
## v0.11.0 F3: no orb and no points before this World.tick (a pickup sets it).
var ready_tick := 0
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
	h.add_int(meter)
	h.add_int(ready_tick)
