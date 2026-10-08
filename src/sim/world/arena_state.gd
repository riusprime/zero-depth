class_name ArenaState
extends RefCounted
## The floor's sealed arenas in play (v0.5.5 AR; World.arenas, Arenas). Hashed once touched (an arena sealed).

## The arena room sealed now (-1 = none), and the tick it sealed.
var room := -1
var sealed_tick := -1
## Waves this sealing: how many it has, how many have spawned, the tick the next one spawns (-1 = a wave is being
## fought, or none is due).
var waves := 0
var wave := 0
var next_wave_tick := -1
## Enemies the waves of this sealing spawned so far.
var spawned := 0
## The arena rooms cleared on this floor, in clear order (a cleared arena stays open), and the tick of the last clear.
var cleared := PackedInt32Array()
var clear_tick := -1
## The barriers standing in the sealed arena's doorways (World.walls holds them while sealed).
var barriers: Array[Obb] = []
## The sealed room's own streams (SIM_CONTRACTS §5 per-room streams), derived from the run seed and the room at the
## seal: `combat:room:k` draws the wave count and the spots, `ai:room:k` the kinds. Null while nothing is sealed.
var rng_combat: RngStream
var rng_ai: RngStream


func touched() -> bool:
	return room != -1 or not cleared.is_empty()


func sealed() -> bool:
	return room >= 0


func hash_into(h: StateHasher) -> void:
	for v in [room, sealed_tick, waves, wave, next_wave_tick, spawned, clear_tick]:
		h.add_int(v)
	h.add_ints(cleared)
	h.add_int(barriers.size())
	for o in barriers:
		h.add_f32(o.center.x)
		h.add_f32(o.center.y)
	for s in [rng_combat, rng_ai]:
		h.add_int(s.state if s != null else 0)
