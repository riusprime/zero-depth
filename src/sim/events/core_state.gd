class_name CoreState
extends RefCounted
## v0.6.0 CU core theft (World.cores; CoreTheft): the cores elites and bosses carry, their stagger and steal window,
## and the free drops on the floor. Per floor (not carried); hashed once touched.

## Drop kinds: a stolen elite core, a stolen boss core (legendary), Marked's rare card.
enum Drop { CORE, BOSS_CORE, ELITE_CARD }

## Carriers, parallel arrays in the order they got their core: actor id, the card held (an Offers code), 1 for a
## boss, an elite's stagger meter (direct damage since its last stagger), its stagger ticks left (an elite's own; a
## boss's stagger is BossStore's) and the steal window's ticks left (0 = shut).
var ids := PackedInt32Array()
var card := PackedInt32Array()
var boss := PackedInt32Array()
var meter := PackedInt32Array()
var stagger_t := PackedInt32Array()
var window_t := PackedInt32Array()
## The drops still on the floor: reward id and Drop kind.
var drop_ids := PackedInt32Array()
var drop_kind := PackedInt32Array()
## For the views: the last window opened (tick, actor id) and the last steal (tick, card); -1 = none yet.
var window_tick := -1
var window_id := -1
var steal_tick := -1
var steal_card := -1


func size() -> int:
	return ids.size()


func add(id: int, p_card: int, p_boss: bool) -> void:
	ids.append(id)
	card.append(p_card)
	boss.append(1 if p_boss else 0)
	meter.append(0)
	stagger_t.append(0)
	window_t.append(0)


func remove_at(k: int) -> void:
	ids.remove_at(k)
	card.remove_at(k)
	boss.remove_at(k)
	meter.remove_at(k)
	stagger_t.remove_at(k)
	window_t.remove_at(k)


func touched() -> bool:
	return not ids.is_empty() or not drop_ids.is_empty() or window_tick != -1 or steal_tick != -1


func hash_into(h: StateHasher) -> void:
	for a in [ids, card, boss, meter, stagger_t, window_t, drop_ids, drop_kind]:
		h.add_ints(a)
	for v in [window_tick, window_id, steal_tick, steal_card]:
		h.add_int(v)
