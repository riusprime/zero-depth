class_name ShardDropStore
extends RefCounted
## Kill shards lying on the floor (v0.10.5 O7b, owner P6; ShardDrops), as parallel arrays in drop order: a sequence
## number (this store's own count, not an entity id, so ids stay as before), where it lies and the shards it holds.
## World hashes it only once a drop was ever made (touched).

const INT_FIELDS: Array[StringName] = [&"seqs", &"amounts"]
const FLOAT_FIELDS: Array[StringName] = [&"pos_x", &"pos_y"]

var seqs := PackedInt32Array()
var amounts := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var next_seq := 1
var touched := false


func size() -> int:
	return seqs.size()


func add(at: Vector2, amount: int) -> void:
	touched = true
	seqs.append(next_seq)
	next_seq += 1
	amounts.append(amount)
	pos_x.append(at.x)
	pos_y.append(at.y)


func pos(k: int) -> Vector2:
	return Vector2(pos_x[k], pos_y[k])


func total() -> int:
	var n := 0
	for a in amounts:
		n += a
	return n


func remove_at(k: int) -> void:
	seqs.remove_at(k)
	amounts.remove_at(k)
	pos_x.remove_at(k)
	pos_y.remove_at(k)


func hash_into(h: StateHasher) -> void:
	h.add_int(next_seq)
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
