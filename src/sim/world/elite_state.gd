class_name EliteState
extends RefCounted
## v0.9.0 EL (Elites; ELITES.md E0): the floor's elites (World.elites; null on a floor that never had one). Created by
## Elites.setup when the floor has elite rooms, or by the first elite spawned (an Elite Lockdown, the Chaos shrine,
## the dev panel). Hashed whenever it exists. Its numbers are World.elite_rules (content).

## The floor's elite rooms (marked when the floor was built: Elites.setup) and the archetype each holds
## (ActorStore.Kind), and 1 once its elite arrived (it never comes again).
var rooms := PackedInt32Array()
var room_kinds := PackedInt32Array()
var room_spawned := PackedInt32Array()
## The elites alive (actor ids, in arrival order), their kinds, where each came from (Source), and the tick from which
## each may hurt by contact again.
var ids := PackedInt32Array()
var kinds := PackedInt32Array()
var sources := PackedInt32Array()
var contact_tick := PackedInt32Array()
## 1 while the first pack after a room's elite arrived is still to come (it arrives one smaller: ELITES.md E0).
var escort_pending := 0
## For the views: the last arrival (tick, actor id, where), and the last kill (tick, where, 1 if its card dropped).
var arrive_tick := -1
var arrive_id := -1
var arrive_pos := Vector2.ZERO
var kill_tick := -1
var kill_pos := Vector2.ZERO
var kill_dropped := 0
## Elites that ever arrived on this floor.
var arrived := 0


func size() -> int:
	return ids.size()


func add(id: int, kind: int, source: int) -> void:
	ids.append(id)
	kinds.append(kind)
	sources.append(source)
	contact_tick.append(0)


func remove_at(k: int) -> void:
	ids.remove_at(k)
	kinds.remove_at(k)
	sources.remove_at(k)
	contact_tick.remove_at(k)


func hash_into(h: StateHasher) -> void:
	for a in [rooms, room_kinds, room_spawned, ids, kinds, sources, contact_tick]:
		h.add_ints(a)
	for v in [escort_pending, arrive_tick, arrive_id, kill_tick, kill_dropped, arrived]:
		h.add_int(v)
	for q in [arrive_pos, kill_pos]:
		h.add_f32(q.x)
		h.add_f32(q.y)
