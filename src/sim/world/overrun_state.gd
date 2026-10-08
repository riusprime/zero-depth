class_name OverrunState
extends RefCounted
## The Overrun room's per-floor state (v0.4.0 AB; World.overrun, Overrun). Hashed once touched (the player entered).

## The player stands in the Overrun room now; entered it at least once (the tick of the first entry, -1 = never).
var inside := false
var enter_tick := -1
## Overrun enemies killed, and the shards their kills paid (the clear pays them again).
var kills := 0
var shards_in := 0
## The tick the room was cleared (-1 = not yet), the reward altar it left (-1 = none) and the bonus shards paid.
var clear_tick := -1
var reward_id := -1
var bonus := 0
## Overrun enemies alive (actor ids, ascending as they arrived): more HP and damage.
var boosted := PackedInt32Array()


func touched() -> bool:
	return enter_tick != -1 or not boosted.is_empty()


func cleared() -> bool:
	return clear_tick >= 0


func hash_into(h: StateHasher) -> void:
	for v in [1 if inside else 0, enter_tick, kills, shards_in, clear_tick, reward_id, bonus]:
		h.add_int(v)
	h.add_ints(boosted)
