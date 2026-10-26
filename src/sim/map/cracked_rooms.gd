class_name CrackedRooms
extends RefCounted
## v0.9.0 DX (owner W §4 C: "Certain walls, statues, or props contain subtle visual clues indicating that they can be
## destroyed. Breaking them reveals hidden spaces"; Q23: the Skill breaks them, the hidden room unseen until then): the
## floor's cracked wall, chosen after the floor, its rooms' kinds, the timed door and the rune puzzle are set
## (Breakables.setup), from the rooms already generated, so the floor's walls and draws stay as they were:
## - on chance_permille of the floors (a draw from the `map:cracked_wall` sub-stream of the floor seed), one dead-end
##   room (one doorway, to one room) becomes the hidden room behind a cracked wall, by TimedDoorRooms' rules (never the
##   start hall, the boss room, its host, the portal room, the Overrun room, the shop's room, the curse room, an arena
##   or a room in `taken`); never the timed door's or the rune puzzle's room or host, and its host is never one of
##   those either;
## - its one doorway is filled by the cracked wall section (TimedDoorRooms.door_wall's footprint) instead of open;
## - a dead end is never on the way anywhere (the property test: every other room stays reachable without it).
## Pure sim code: the doorway graph.

const STREAM := "map:cracked_wall"


## Marks `f`'s cracked wall (FloorLayout.crack_*). Returns the hidden room, or -1.
static func mark(f: FloorLayout, chance_permille: int, taken: PackedInt32Array) -> int:
	clear(f)
	var rng := RngStream.derive(f.seed_value, STREAM)
	if not rng.chance_permille(chance_permille):
		return -1
	var busy := PackedInt32Array([f.timed_room, f.timed_host, f.rune_room, f.rune_host])
	busy.append_array(f.timed_switch_rooms)  # v0.9.5 TS
	var cands := PackedInt32Array()
	for room in TimedDoorRooms.candidates(f, taken):
		if not room in busy and not RuneRooms.host_of(f, room) in busy:
			cands.append(room)
	if cands.is_empty():
		return -1
	var room := cands[rng.range_int(0, cands.size() - 1)]
	f.crack_room = room
	f.crack_host = RuneRooms.host_of(f, room)
	f.crack_door = TimedDoorRooms.only_door(f, room)
	f.crack_wall = TimedDoorRooms.door_wall(f, f.crack_door)
	return room


## No cracked wall (the fields' defaults).
static func clear(f: FloorLayout) -> void:
	f.crack_room = -1
	f.crack_host = -1
	f.crack_door = -1
	f.crack_wall = null
