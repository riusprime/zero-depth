class_name StressState
extends RefCounted
## v0.9.5 SM (Stress Mark; StressMarks): the weak sides on enemies. One entry per enemy that was ever marked, by
## actor id: `mask` (bit s set: side s is marked; sides 0 up, 1 right, 2 down, 3 left on the screen) and four cooldown
## ticks (`cd`, the tick a side may be marked again; a non-boss enemy uses its slot 0). `rng` is the named stream
## `combat:stress`. World.stress is null until a hero first holds the card. Hashed and snapshotted when it exists.

var ids := PackedInt32Array()
var mask := PackedInt32Array()
var cd := PackedInt32Array()
var rng: RngStream


func entry(id: int) -> int:
	return ids.find(id)


func add(id: int) -> int:
	ids.append(id)
	mask.append(0)
	for _k in 4:
		cd.append(0)
	return ids.size() - 1


func remove_at(e: int) -> void:
	ids.remove_at(e)
	mask.remove_at(e)
	for _k in 4:
		cd.remove_at(e * 4)


func clear() -> void:
	ids.clear()
	mask.clear()
	cd.clear()


func hash_into(h: StateHasher) -> void:
	h.add_int(rng.state if rng != null else 0)
	h.add_ints(ids)
	h.add_ints(mask)
	h.add_ints(cd)
