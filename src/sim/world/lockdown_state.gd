class_name LockdownState
extends RefCounted
## v0.9.0 LK (owner Q21; Lockdowns): the floor's Lockdowns in play (World.lockdown; null on a floor without any).
## Hashed whenever it exists.

## The numbers (content, kept by the snapshot as loadout).
var table: LockdownTable
## The Lockdown room sealed now (-1 = none), its kind (LockdownTable.Kind) and the tick it sealed.
var room := -1
var kind := -1
var sealed_tick := -1
## The encounter: formations this sealing has, how many have spawned, the tick the next one spawns (-1 = one is being
## fought, or none is due), and the first formation's shape (Lockdowns.Formation; each next one turns to the next).
var waves := 0
var wave := 0
var next_wave_tick := -1
var formation := -1
## The encounter's enemies (actor ids) this sealing, alive or not.
var members := PackedInt32Array()
## v0.9.0 CF: the members still waiting to come in (the room holds only so many at once: ClosedFights), in order:
## their enemy kinds (an elite's as -1 - its kind) and spots.
var later_kinds := PackedInt32Array()
var later_pos := PackedVector2Array()
## The stuck-enemy safety: the enemies (ids) unreachable now and for how many ticks in a row; how many were pulled
## back on this floor, and the tick of the last pull.
var stuck_ids := PackedInt32Array()
var stuck_ticks := PackedInt32Array()
var pulled := 0
var pull_tick := -1
## The Lockdowns opened on this floor, in order (an opened one stays open), the tick of the last, and those the cap
## opened (90 s) rather than a clear.
var cleared := PackedInt32Array()
var clear_tick := -1
var forced := PackedInt32Array()
## The bars standing in the sealed room's doorways (World.walls holds them while sealed).
var barriers: Array[Obb] = []
## The sealed room's own stream (`combat:lockdown:k`, derived at the seal): the formation, the kinds. Null while
## nothing is sealed.
var rng: RngStream
## Hazard Lockdowns: the strikes marked on the ground (where, and the tick each lands), the tick the next is marked,
## and the last one that landed (where, when, 1 if it hurt the hero).
var strike_pos := PackedVector2Array()
var strike_tick := PackedInt32Array()
var next_strike_tick := -1
var landed_pos := Vector2.ZERO
var landed_tick := -1
var landed_hit := 0
## Each opened Lockdown's reward (a free altar's id), in clear order.
var reward_ids := PackedInt32Array()


func sealed() -> bool:
	return room >= 0


func hash_into(h: StateHasher) -> void:
	for v in [room, kind, sealed_tick, waves, wave, next_wave_tick, formation, pulled, pull_tick]:
		h.add_int(v)
	for v in [clear_tick, next_strike_tick, landed_tick, landed_hit]:
		h.add_int(v)
	for a in [members, stuck_ids, stuck_ticks, cleared, forced, strike_tick, reward_ids]:
		h.add_ints(a)
	for q in strike_pos:
		h.add_f32(q.x)
		h.add_f32(q.y)
	h.add_f32(landed_pos.x)
	h.add_f32(landed_pos.y)
	h.add_int(barriers.size())
	for o in barriers:
		h.add_f32(o.center.x)
		h.add_f32(o.center.y)
	h.add_int(rng.state if rng != null else 0)
	if not later_kinds.is_empty():  # v0.9.0 CF: hashed only while members wait (a fight before CF hashes as it did)
		h.add_ints(later_kinds)
		for q in later_pos:
			h.add_f32(q.x)
			h.add_f32(q.y)
