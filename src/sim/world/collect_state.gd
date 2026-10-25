class_name CollectState
extends RefCounted
## v0.9.0 CL (COLLECTIBLES.md; Collectibles): the collectibles this floor can hold (World.collect; null on a floor
## that holds none: every world before CL, goldens, sims, the Playground). One entry per collectible armed at setup
## (CollectibleBook.arm, app side: the ones the profile hasn't found whose source this floor has): its id (a
## CollectibleDefinition id), its source (Collectibles.Source) and the source's number (`param`: a final body's index,
## or the secrets a run must find), where its pickup lies once it showed (`pos`), the tick it showed and the tick the
## hero took it (-1 not yet). `marked_before`: the secrets behind rune markings the run's finished floors found.
## Hashed and snapshotted whenever it exists.

var ids := PackedStringArray()
var source := PackedInt32Array()
var param := PackedInt32Array()
var pos := PackedVector2Array()
var shown_tick := PackedInt32Array()
var taken_tick := PackedInt32Array()
var marked_before := 0


func size() -> int:
	return ids.size()


func add(id: StringName, p_source: int, p_param: int) -> void:
	ids.append(String(id))
	source.append(p_source)
	param.append(p_param)
	pos.append(Vector2.ZERO)
	shown_tick.append(-1)
	taken_tick.append(-1)


## Entries the hero has taken, as ids (in arming order).
func taken_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in ids.size():
		if taken_tick[k] >= 0:
			out.append(ids[k])
	return out


func hash_into(h: StateHasher) -> void:
	h.add_int(ids.size())
	for k in ids.size():
		h.add_string(ids[k])
		h.add_int(source[k])
		h.add_int(param[k])
		h.add_f32(pos[k].x)
		h.add_f32(pos[k].y)
		h.add_int(shown_tick[k])
		h.add_int(taken_tick[k])
	h.add_int(marked_before)
