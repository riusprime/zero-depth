class_name RoomLayouts
extends RefCounted
## Designed rooms on a floor (v0.8.0 RT, owner O12: "3 hand-designed layouts per room size … turned and mirrored, so
## every floor differs"). FloorGenerator asks for a room's layout by its cells (the long side first, key()), draws one
## from the `map` stream by weight, then a turn and a mirror; place_group() maps a layout group into the room in
## metres. A layout is authored in its own frame: x along the room's long side, the room's corner at (0, 0); a group's
## anchor is a fraction of the room, its pieces keep their metres. Turns are quarter turns on the sim plane
## ((x, y) -> (-y, x) is +1024), so every piece stays axis-aligned; a mirror flips the frame's x before the turn.
## Pure sim code: integer draws, centimetres, no trig.

## A piece may stick out of the room by this much (float noise of the room's edges) before its group is invalid;
## a piece inside that is pulled in to FLUSH_INSET from the edge (as RoomThemes: touching, no slit).
const EDGE_TOLERANCE := 0.02
const FLUSH_INSET := 0.001
## A drawn piece counts as standing on a solid when its centre is within this of the solid's footprint (as
## RoomLayoutDefinition.OVERHANG).
const OVERHANG := 0.05


## The table key for a room of `cells`: its long side first.
static func key(cells: Vector2i) -> Vector2i:
	return Vector2i(maxi(cells.x, cells.y), mini(cells.x, cells.y))


## The quarter turns a room of `cells` may take a layout at: any for a square room; for a long room the two that put
## the layout's long side (its x) along the room's long side.
static func turns_for(cells: Vector2i) -> PackedInt32Array:
	if cells.x == cells.y:
		return PackedInt32Array([0, 1, 2, 3])
	if cells.x > cells.y:
		return PackedInt32Array([0, 2])
	return PackedInt32Array([1, 3])


## Draws [layout index, turn, mirror (0/1)] for a room of `cells` from `list` (the tables of its key), in that order
## from the map stream.
static func draw(rng: RngStream, list: Array, cells: Vector2i) -> PackedInt32Array:
	var w := PackedInt32Array()
	for t: RoomLayoutTable in list:
		w.append(maxi(1, t.weight))
	var pick := rng.pick_weighted(w)
	var turns := turns_for(cells)
	var turn := turns[rng.range_int(0, turns.size() - 1)]
	var mirror := rng.range_int(0, 1)
	return PackedInt32Array([pick, turn, mirror])


## The layout frame's size for room interior r at `turn`: x is the side the layout's x runs along.
static func frame_size(r: Rect2, turn: int) -> Vector2:
	return r.size if turn % 2 == 0 else Vector2(r.size.y, r.size.x)


## A point of the layout frame (metres from its corner) in the room.
static func to_room(q: Vector2, r: Rect2, turn: int) -> Vector2:
	var s := frame_size(r, turn)
	match turn & 3:
		1:
			return r.position + Vector2(s.y - q.y, q.x)
		2:
			return r.position + Vector2(s.x - q.x, s.y - q.y)
		3:
			return r.position + Vector2(q.y, s.x - q.x)
	return r.position + q


## A layout angle (1/4096) in the room.
static func angle_in_room(angle: int, turn: int, mirror: bool) -> int:
	var a := (2048 - angle) if mirror else angle
	return (a + turn * 1024) & 4095


## The group's anchor in the layout frame for room interior r (mirrored when `mirror`).
static func anchor_of(g: RoomLayoutTable.Group, r: Rect2, turn: int, mirror: bool) -> Vector2:
	var s := frame_size(r, turn)
	var a := Vector2(s.x * g.anchor.x / 1000.0, s.y * g.anchor.y / 1000.0)
	if mirror:
		a.x = s.x - a.x
	return a


## A piece's centre in the layout frame.
static func _frame_point(anchor: Vector2, p: RoomLayoutTable.Piece, mirror: bool) -> Vector2:
	var d := Vector2(p.at) / 100.0
	if mirror:
		d.x = -d.x
	return anchor + d


static func _cm(metres: float) -> float:
	return roundi(metres * 100.0) / 100.0


## Group g of a layout placed in room interior r: {"ok": false} when a solid piece would leave the room, else
## {"ok": true, "solids": Array[Obb] (axis-aligned), "solid_tags": Array[StringName], "solid_heights":
## PackedFloat64Array (m; 0 = the kit's own), "props": [[piece, centre: Vector2, angle, size: Vector2 (m), height (m),
## the index into "solids" it stands on or -1]]}. Drawn-only pieces outside the room are left out.
static func place_group(g: RoomLayoutTable.Group, r: Rect2, turn: int, mirror: bool) -> Dictionary:
	var anchor := anchor_of(g, r, turn, mirror)
	var solids: Array[Obb] = []
	var tags: Array[StringName] = []
	var heights := PackedFloat64Array()
	var frames: Array[Rect2] = []  # each solid in the layout frame (to find what a drawn piece stands on)
	for p in g.pieces:
		if not p.solid:
			continue
		var c := _frame_point(anchor, p, mirror)
		var h := Vector2(p.size) / 200.0
		var a := to_room(c - h, r, turn)
		var b := to_room(c + h, r, turn)
		var lo := Vector2(_cm(minf(a.x, b.x)), _cm(minf(a.y, b.y)))
		var hi := Vector2(_cm(maxf(a.x, b.x)), _cm(maxf(a.y, b.y)))
		var t := EDGE_TOLERANCE
		if (
			lo.x < r.position.x - t
			or lo.y < r.position.y - t
			or hi.x > r.end.x + t
			or hi.y > r.end.y + t
		):
			return {"ok": false}
		lo = lo.max(r.position + Vector2(FLUSH_INSET, FLUSH_INSET))
		hi = hi.min(r.end - Vector2(FLUSH_INSET, FLUSH_INSET))
		solids.append(Obb.make((lo + hi) * 0.5, (hi - lo) * 0.5, 0))
		tags.append(p.piece)
		heights.append(p.height / 100.0)
		frames.append(Rect2(c - h, h * 2.0))
	var props: Array = []
	for p in g.pieces:
		if p.solid:
			continue
		var c := _frame_point(anchor, p, mirror)
		var at := to_room(c, r, turn)
		if not r.has_point(at):
			continue
		var on := -1
		for k in frames.size():
			if frames[k].grow(OVERHANG).has_point(c):
				on = k
				break
		props.append(
			[
				p.piece,
				at,
				angle_in_room(p.angle, turn, mirror),
				Vector2(p.size) / 100.0,
				p.height / 100.0,
				on
			]
		)
	return {
		"ok": true, "solids": solids, "solid_tags": tags, "solid_heights": heights, "props": props
	}
