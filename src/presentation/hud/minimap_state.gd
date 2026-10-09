class_name MinimapState
extends RefCounted
## What the minimap knows (PLAN v0.3.0 MM, owner L30): which rooms of this floor you have entered, the room you are
## in, and a revision that grows whenever something the map draws changes (a room found, a reward taken, the
## portal opening, the boss door sealing). Presentation-side: it reads WorldReader each tick and never writes the
## sim. The start hall is known from the floor's first tick; a new floor (another layout) starts it over.

## Rooms entered, one byte per room (index = room).
var discovered := PackedByteArray()
## The room the player stands in, or the last one they stood in while crossing a doorway (-1 before any).
var current := -1
## Grows on every change the map has to redraw for.
var revision := 0
## v0.4.0 SV: rooms already entered on a resumed floor (one byte per room), taken when the floor is first read.
var preset := PackedByteArray()

var _floor_key := ""
var _rewards_key := ""
var _portal_open := false
var _door_sealed := false


## Reads the world. True when the map's picture changed (beyond the player's own position and facing).
func update(reader: WorldReader) -> bool:
	if not reader.has_floor():
		if _floor_key != "":
			_reset(0)
			_floor_key = ""
			return _bump()
		return false
	var key := "%d:%d:%d" % [reader.seed_value(), reader.floor_index(), reader.floor_room_count()]
	var changed := false
	if key != _floor_key:
		_floor_key = key
		_reset(reader.floor_room_count())
		if preset.size() == discovered.size():
			discovered = preset
		preset = PackedByteArray()
		var start := reader.floor_start_room()
		if start >= 0:
			discovered[start] = 1
			current = start
		changed = true
	var room := reader.floor_room_of(reader.player_pos())
	if room >= 0 and room != current:
		current = room
		changed = true
	if room >= 0 and discovered[room] == 0:
		discovered[room] = 1
		changed = true
	var rewards := _rewards_signature(reader)
	if rewards != _rewards_key:
		_rewards_key = rewards
		changed = true
	if reader.portal_active() != _portal_open or reader.boss_door_sealed() != _door_sealed:
		_portal_open = reader.portal_active()
		_door_sealed = reader.boss_door_sealed()
		changed = true
	return _bump() if changed else false


func is_discovered(room: int) -> bool:
	return room >= 0 and room < discovered.size() and discovered[room] == 1


func discovered_count() -> int:
	return discovered.count(1)


## Door i leads from a room you know into one you don't: the map draws it as an open stub (unexplored space).
func door_to_unknown(reader: WorldReader, i: int) -> bool:
	var d := reader.floor_door_rooms(i)
	return is_discovered(d.x) != is_discovered(d.y)


## Door i is drawn at all: at least one of its rooms is known.
func door_known(reader: WorldReader, i: int) -> bool:
	var d := reader.floor_door_rooms(i)
	return is_discovered(d.x) or is_discovered(d.y)


## Indices of doorways that lead into rooms you haven't entered yet.
func unknown_doors(reader: WorldReader) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in reader.floor_door_count():
		if door_to_unknown(reader, i):
			out.append(i)
	return out


## The rewards the map shows: those standing in rooms you know, as reward indices.
func visible_rewards(reader: WorldReader) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in reader.reward_count():
		if is_discovered(reader.floor_room_of(reader.reward_pos(i))):
			out.append(i)
	return out


func _reset(rooms: int) -> void:
	discovered = PackedByteArray()
	discovered.resize(rooms)
	current = -1
	_rewards_key = ""
	_portal_open = false
	_door_sealed = false


func _bump() -> bool:
	revision += 1
	return true


## Ids and affordability of every reward still standing (a taken one leaves the store; a chest turns affordable).
func _rewards_signature(reader: WorldReader) -> String:
	var parts := PackedStringArray()
	for i in reader.reward_count():
		parts.append(
			(
				"%d%s%s"
				% [
					reader.reward_id(i),
					"+" if reader.reward_affordable(i) else "-",
					"L" if reader.reward_locked(i) else ""  # v0.5.5 AR: a locked reward unlocks on the clear
				]
			)
		)
	var a := reader.arenas()  # v0.5.5 AR: an arena sealing or clearing redraws its mark
	parts.append("a%d/%d" % [a["sealed"], (a["cleared"] as PackedInt32Array).size()])
	return ",".join(parts)
