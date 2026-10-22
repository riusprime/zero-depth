class_name HiddenRoom
extends RefCounted
## v0.9.0 TD (owner Q23: "hidden room should not appear or be visible until you open it"): which of the floor's drawn
## pieces belong only to the hidden room (WorldReader.hidden_room: the timed door's secret room until it first opens),
## so StageView leaves them out of sight until it opens (StageView.reveal_hidden). A piece is the hidden room's when it
## lies within its cells (grid line to grid line, grown by the thickest outer wall half) and touches no other room's
## interior: its own outer walls, its interior pieces and its ground; a partition it shares with a neighbour stays,
## as the neighbour's wall. Pure: reads only.

## How far past its grid lines the room's outer walls reach (FloorParams.wall_half_max, with a margin).
const OUTER_M := 2.6
## How close to another room's interior a piece may come and still be the hidden room's alone.
const TOUCH_M := 0.2


## Whether `rect` (a piece's bounds on the sim plane) is the hidden room's alone (false without one).
static func owns(reader: WorldReader, rect: Rect2) -> bool:
	var room := reader.hidden_room()
	if room < 0:
		return false
	if not reader.hidden_room_cells().grow(OUTER_M).encloses(rect):
		return false
	for r in reader.floor_room_count():
		if r != room and reader.floor_room(r).grow(TOUCH_M).intersects(rect):
			return false
	return true


## Moves the hidden room's ground out of `rects` (in place): a rect that is its alone whole, and the part of any other
## over its interior (the rest of that rect stays, cut in up to four). Returns the hidden rects.
static func split(reader: WorldReader, rects: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var room := reader.hidden_room()
	if room < 0:
		return out
	var inner := reader.floor_room(room)
	var keep: Array[Rect2] = []
	for r in rects:
		if owns(reader, r):
			out.append(r)
		elif r.intersects(inner):
			out.append(r.intersection(inner))
			keep.append_array(minus(r, inner))
		else:
			keep.append(r)
	rects.assign(keep)
	return out


## `r` without `cut` as up to four rects (below, above, left, right of it).
static func minus(r: Rect2, cut: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var c := r.intersection(cut)
	if c.size.x <= 0.0 or c.size.y <= 0.0:
		out.append(r)
		return out
	var parts: Array[Rect2] = [
		Rect2(r.position.x, r.position.y, r.size.x, c.position.y - r.position.y),
		Rect2(r.position.x, c.end.y, r.size.x, r.end.y - c.end.y),
		Rect2(r.position.x, c.position.y, c.position.x - r.position.x, c.size.y),
		Rect2(c.end.x, c.position.y, r.end.x - c.end.x, c.size.y),
	]
	for p in parts:
		if p.size.x > 0.001 and p.size.y > 0.001:
			out.append(p)
	return out


## The floor walls (indices into the reader's walls) that are the hidden room's alone, as a set.
static func walls(reader: WorldReader) -> Dictionary:
	var out := {}
	if reader.hidden_room() < 0:
		return out
	for i in reader.wall_count():
		if reader.wall_class(i) != 2 and owns(reader, reader.wall(i).bounds()):
			out[i] = true
	return out
