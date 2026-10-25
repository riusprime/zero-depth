class_name AffinityState
extends RefCounted
## v0.9.0 RB (AFFINITIES.md): the run's rune affinity on this floor (World.affinity; null for None, so a run without
## one hashes and snapshots as before RB). Hashed whenever it exists.

## The numbers (content, kept by the snapshot as loadout).
var table: AffinityTable
## A5 Guardian: the wards left on this floor (refilled when the next floor is built) and the tick the last one broke
## (-1: none yet).
var ward := 0
var ward_tick := -1
## A2 Storm: the tick the current dash began and the enemies (actor ids) it has shocked.
var dash_tick := -1
var dash_shocked := PackedInt32Array()
## Counts the presentation and the tests read: the dash shocks given and the poison jumps made on this floor.
var shocks := 0
var jumps := 0


func hash_into(h: StateHasher) -> void:
	for v in [ward, ward_tick, dash_tick, shocks, jumps]:
		h.add_int(v)
	h.add_ints(dash_shocked)
