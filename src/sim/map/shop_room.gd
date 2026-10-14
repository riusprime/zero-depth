class_name ShopRoom
extends RefCounted
## The shop room per biome (v0.8.0 SR, owner O13: "this shop room that is gonna be designed in a way for each biome
## that will have like its own vendor … in a tent shop"). After ShopPlacement has picked the floor's shop room (its
## rule unchanged, so the room, the arenas and the routes stay where they were), furnish() replaces that room's
## interior with the biome's ShopRoomTable: a tent stall whose counter faces the room's first doorway, the vendor's
## place behind it, and the dressing groups round it. No draw: every choice is a pure function of the floor, so the
## same seed gives the same shop room.
## - The frame: a quarter turn of the room (RoomLayouts) whose -y points from the room's centre toward its first
##   doorway's approach (the axis it is farthest along; ties go to x). Never mirrored.
## - The stall: at the first of its spots where it fits. A stall within the slab gap of a side or the back is pushed
##   flush to it first. It fits when its footprint passes a designed group's checks (FloorGenerator.vignette_fits:
##   doorways, flush or the slab gap, the room one region) and no doorway's box, the approach box in front of the
##   counter (clipped to the room) keeps its depth across the counter's width, every item spot of the room keeps the
##   item clearance from it and stays out of the walk-up lane (the approach as wide as the counter), and the room
##   stays one region holding every doorway's approach, every item spot and the counter's front
##   (ShopPlacement.FRONT_M) at the enemies' clearance.
## - The dressing: each group kept whole or dropped whole by the same checks, and never in the approach box.
## - The result: the room's old interior pieces leave f.walls (their drawn pieces leave layout_props); the dressing's
##   kit solids join f.walls (drawn by the dresser, restyled by the biome), its shop_* solids and the stall go to
##   f.shop_solids (the world adds them as walls; ShopStallView draws them); shop_pos is the counter's centre and
##   shop_angle its facing; the room's spawn points keep only those clear of the new pieces and the approach.
## furnish() returns false and changes nothing when no spot fits (the room keeps its interior and the terminal).
## Pure sim code: centimetres, quarter turns, no trig.

## The frame's -y as a sim angle (the stall's front before the turn).
const FRONT_ANGLE := 3072
## Spawn points closer than this to the counter's centre are dropped (as Shop.SPAWN_CLEAR_M).
const SPAWN_CLEAR_M := 1.6
## The room must stay one region holding a point this much beyond the counter's front (ShopPlacement.FRONT_M), so the
## walkability grid's cells there are open whatever their alignment.
const FRONT_SLACK_M := 0.6
const _DOOR_APPROACH := 1.0


## The quarter turn whose frame -y points from the room's centre toward its first doorway's approach.
static func turn_toward(f: FloorLayout, room: int) -> int:
	var approaches := f.door_approaches(room, _DOOR_APPROACH)
	if approaches.is_empty():
		return 0
	var d := approaches[0] - f.rooms[room].get_center()
	if absf(d.x) >= absf(d.y):
		return 1 if d.x > 0.0 else 3
	return 2 if d.y > 0.0 else 0


## The stall's facing (1/4096) at quarter turn `turn`.
static func facing(turn: int) -> int:
	return RoomLayouts.angle_in_room(FRONT_ANGLE, turn, false)


## Furnishes room `room` of `f` with shop room `t` (see the class notes). True when the stall stood.
static func furnish(f: FloorLayout, p: FloorParams, room: int, t: ShopRoomTable) -> bool:
	if t == null or room < 0 or f.door_approaches(room, _DOOR_APPROACH).is_empty():
		return false
	var r := f.rooms[room]
	var turn := turn_toward(f, room)
	var inside := r.grow(0.01)
	var kept: Array[Obb] = []
	var removed: Array[Obb] = []
	for i in f.walls.size():
		var w := f.walls[i]
		if i >= f.slab_first and inside.encloses(w.bounds()):
			removed.append(w)
		else:
			kept.append(w)
	var near := r.grow(1.0)
	var base: Array[Obb] = []
	for w in kept:
		if w.bounds().intersects(near):
			base.append(w)
	var ctx := {
		"f": f,
		"p": p,
		"room": room,
		"turn": turn,
		"structural": base.size(),
		"boxes": FloorGenerator.door_boxes(f, p, room),
		"items": _items_in(f, room),
		"approaches": f.door_approaches(room, _DOOR_APPROACH),
	}
	var stall := _place_stall(ctx, t, base)
	if stall.is_empty():
		return false
	var walls: Array[Obb] = base.duplicate()
	var stall_solids: Array[Obb] = stall["solids"]
	walls.append_array(stall_solids)
	var kit: Array[Obb] = []
	var out := {
		"kit": kit,
		"shop_solids": stall_solids.duplicate(),
		"tags": {},
		"heights": {},
		"layout_props": [],
		"shop_props": _shop_props_of(stall["placed"], turn),
	}
	for g in t.layout.groups:
		_add_group(ctx, stall, g, walls, out)
	_commit(f, p, room, t, turn, removed, stall, out)
	return true


## The room's item spots.
static func _items_in(f: FloorLayout, room: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in f.item_spots.size():
		if f.item_rooms[i] == room:
			out.append(f.item_spots[i])
	return out


## The stall at its first spot that fits: {"solids": Array[Obb], "placed": the placed group, "counter": the counter's
## centre, "approach": the approach box (Rect2, the room's axes), "front": where you stand}, or {}.
static func _place_stall(ctx: Dictionary, t: ShopRoomTable, base: Array[Obb]) -> Dictionary:
	var f: FloorLayout = ctx["f"]
	var p: FloorParams = ctx["p"]
	var room: int = ctx["room"]
	var turn: int = ctx["turn"]
	var r := f.rooms[room]
	var s := RoomLayouts.frame_size(r, turn)
	var foot := _frame_foot(t.stall)
	var counter_face := foot.position.y
	for spot in t.stall_spots:
		var c := _snap(Vector2(s.x * spot.x / 1000.0, s.y * spot.y / 1000.0), foot, s, p.slab_gap)
		var placed := place_at(t.stall, c, r, turn)
		if not placed["ok"]:
			continue
		var solids: Array[Obb] = placed["solids"]
		var half_w := t.approach.x / 200.0
		var a0 := RoomLayouts.to_room(Vector2(c.x - half_w, c.y + counter_face), r, turn)
		var a1 := RoomLayouts.to_room(
			Vector2(c.x + half_w, c.y + counter_face - t.approach.y / 100.0), r, turn
		)
		var approach := Rect2(a0.min(a1), (a1 - a0).abs()).intersection(r)
		var counter_box := _counter_box(placed)
		if not _covers(approach, counter_box, t.approach.y / 100.0, turn):
			continue
		var counter := _counter_centre(placed)
		var front := counter + Kin.dir(facing(turn)) * (ShopPlacement.FRONT_M + FRONT_SLACK_M)
		# The walk-up lane (the approach as wide as the counter) holds no reward; the wider approach only keeps solids out.
		var lane := (
			Rect2(counter_box.position.x, approach.position.y, counter_box.size.x, approach.size.y)
			if turn % 2 == 0
			else Rect2(
				approach.position.x, counter_box.position.y, approach.size.x, counter_box.size.y
			)
		)
		if not _group_ok(ctx, base, solids, lane, front, false):
			continue
		return {
			"solids": solids,
			"placed": placed,
			"counter": counter,
			"approach": approach,
			"front": front
		}
	return {}


## A dressing group, kept whole or dropped whole.
static func _add_group(
	ctx: Dictionary, stall: Dictionary, g: RoomLayoutTable.Group, walls: Array[Obb], out: Dictionary
) -> void:
	var f: FloorLayout = ctx["f"]
	var turn: int = ctx["turn"]
	var placed := RoomLayouts.place_group(g, f.rooms[ctx["room"]], turn, false)
	if not placed["ok"]:
		return
	placed["sizes"] = _solid_sizes(g)
	var solids: Array[Obb] = placed["solids"]
	if (
		not solids.is_empty()
		and not _group_ok(ctx, walls, solids, stall["approach"], stall["front"], true)
	):
		return
	var keys := PackedStringArray()
	for k in solids.size():
		walls.append(solids[k])
		var piece: StringName = placed["solid_tags"][k]
		var key := FloorLayout.piece_key(solids[k])
		keys.append(key)
		if _is_shop(piece):
			out["shop_solids"].append(solids[k])
		else:
			out["kit"].append(solids[k])
			out["tags"][key] = piece
			out["heights"][key] = placed["solid_heights"][k]
	var boxes: Array[Rect2] = ctx["boxes"]
	for prop: Array in placed["props"]:
		var on: int = prop[5]
		if _is_shop(prop[0]):
			continue
		if on < 0 and (_in_any(prop[1], boxes) or (stall["approach"] as Rect2).has_point(prop[1])):
			continue
		out["layout_props"].append(
			[prop[0], prop[1], prop[2], prop[3], prop[4], keys[on] if on >= 0 else ""]
		)
	out["shop_props"].append_array(_shop_props_of(placed, turn))


## The checks a stall or a dressing group passes (the class notes). `dressing`: the group must also stay out of the
## approach box (the stall's own footprint borders it).
static func _group_ok(
	ctx: Dictionary,
	walls: Array[Obb],
	solids: Array[Obb],
	approach: Rect2,
	front: Vector2,
	dressing: bool
) -> bool:
	var f: FloorLayout = ctx["f"]
	var p: FloorParams = ctx["p"]
	var room: int = ctx["room"]
	var boxes: Array[Rect2] = ctx["boxes"]
	var items: PackedVector2Array = ctx["items"]
	for o in solids:
		var b := o.bounds()
		for box in boxes:
			if b.intersects(box):
				return false
		if dressing and b.intersects(approach):
			return false
		for q in items:
			if Collide.circle_vs_obb(q, p.item_clearance, o) != Vector2.ZERO:
				return false
	if not dressing:
		for q in items:
			if approach.has_point(q):
				return false
	if not FloorGenerator.vignette_fits(f, p, room, walls, ctx["structural"], solids):
		return false
	var trial: Array[Obb] = walls.duplicate()
	trial.append_array(solids)
	var must: PackedVector2Array = (ctx["approaches"] as PackedVector2Array).duplicate()
	must.append_array(items)
	must.append(front)
	return FloorReach.whole(f.rooms[room], trial, p.nav_clearance, must)


static func _commit(
	f: FloorLayout,
	p: FloorParams,
	room: int,
	t: ShopRoomTable,
	turn: int,
	removed: Array[Obb],
	stall: Dictionary,
	out: Dictionary
) -> void:
	var r := f.rooms[room]
	var gone := {}
	for w in removed:
		gone[FloorLayout.piece_key(w)] = true
		f.piece_tags.erase(FloorLayout.piece_key(w))
		f.piece_heights.erase(FloorLayout.piece_key(w))
	var walls: Array[Obb] = []
	for i in f.walls.size():
		if i < f.slab_first or not gone.has(FloorLayout.piece_key(f.walls[i])):
			walls.append(f.walls[i])
	walls.append_array(out["kit"])
	f.walls = walls
	var props: Array = []
	for prop: Array in f.layout_props:
		if not r.has_point(prop[1]):
			props.append(prop)
	props.append_array(out["layout_props"])
	f.layout_props = props
	for key: String in out["tags"]:
		f.piece_tags[key] = out["tags"][key]
		f.piece_heights[key] = out["heights"][key]
	if room < f.room_layout.size():
		f.room_layout[room] = t.id
		f.room_turn[room] = turn
		f.room_mirror[room] = 0
	f.shop_layout = t.id
	f.shop_solids = out["shop_solids"]
	f.shop_props = out["shop_props"]
	f.shop_pos = stall["counter"]
	f.shop_angle = facing(turn)
	if room < f.spawn_points.size():
		var all: Array[Obb] = f.room_walls(room)
		all.append_array(f.shop_solids)
		var approach: Rect2 = stall["approach"]
		var spots := PackedVector2Array()
		for q in f.spawn_points[room]:
			if (
				_clear_of(q, p.spawn_clearance, all)
				and not approach.has_point(q)
				and Kin.length(q - f.shop_pos) >= SPAWN_CLEAR_M
			):
				spots.append(q)
		f.spawn_points[room] = spots


## Group `g` placed with its anchor at frame point `anchor` (m) in room interior r at quarter turn `turn`, never
## mirrored: the same result as RoomLayouts.place_group.
static func place_at(g: RoomLayoutTable.Group, anchor: Vector2, r: Rect2, turn: int) -> Dictionary:
	var solids: Array[Obb] = []
	var tags: Array[StringName] = []
	var heights := PackedFloat64Array()
	var frames: Array[Rect2] = []
	for p in g.pieces:
		if not p.solid:
			continue
		var c := anchor + Vector2(p.at) / 100.0
		var h := Vector2(p.size) / 200.0
		var a := RoomLayouts.to_room(c - h, r, turn)
		var b := RoomLayouts.to_room(c + h, r, turn)
		var lo := Vector2(_cm(minf(a.x, b.x)), _cm(minf(a.y, b.y)))
		var hi := Vector2(_cm(maxf(a.x, b.x)), _cm(maxf(a.y, b.y)))
		var tol := RoomLayouts.EDGE_TOLERANCE
		if (
			lo.x < r.position.x - tol
			or lo.y < r.position.y - tol
			or hi.x > r.end.x + tol
			or hi.y > r.end.y + tol
		):
			return {"ok": false}
		var inset := Vector2(RoomLayouts.FLUSH_INSET, RoomLayouts.FLUSH_INSET)
		lo = lo.max(r.position + inset)
		hi = hi.min(r.end - inset)
		solids.append(Obb.make((lo + hi) * 0.5, (hi - lo) * 0.5, 0))
		tags.append(p.piece)
		heights.append(p.height / 100.0)
		frames.append(Rect2(c - h, h * 2.0))
	var props: Array = []
	for p in g.pieces:
		if p.solid:
			continue
		var c := anchor + Vector2(p.at) / 100.0
		var at := RoomLayouts.to_room(c, r, turn)
		if not r.has_point(at):
			continue
		var on := -1
		for k in frames.size():
			if frames[k].grow(RoomLayouts.OVERHANG).has_point(c):
				on = k
				break
		props.append(
			[
				p.piece,
				at,
				RoomLayouts.angle_in_room(p.angle, turn, false),
				Vector2(p.size) / 100.0,
				p.height / 100.0,
				on
			]
		)
	return {
		"ok": true,
		"solids": solids,
		"solid_tags": tags,
		"solid_heights": heights,
		"props": props,
		"sizes": _solid_sizes(g),
	}


## The stall's footprint in the frame, metres round its centre.
static func _frame_foot(g: RoomLayoutTable.Group) -> Rect2:
	var foot := Rect2()
	var first := true
	for p in g.pieces:
		if not p.solid:
			continue
		var box := Rect2(Vector2(p.at - p.size / 2) / 100.0, Vector2(p.size) / 100.0)
		foot = box if first else foot.merge(box)
		first = false
	return foot


## The stall's centre moved flush to a side or the back of the frame when it would stand closer than `gap` to it.
static func _snap(c: Vector2, foot: Rect2, s: Vector2, gap: float) -> Vector2:
	var left := c.x + foot.position.x
	var right := s.x - (c.x + foot.end.x)
	if left < gap and left <= right:
		c.x -= left
	elif right < gap:
		c.x += right
	var back := s.y - (c.y + foot.end.y)
	if back < gap:
		c.y += back
	return Vector2(_cm(c.x), _cm(c.y))


## True when the approach box (clipped to the room) keeps its full depth and spans the counter's whole width.
static func _covers(approach: Rect2, counter: Rect2, depth: float, turn: int) -> bool:
	if turn % 2 == 0:  # the depth runs along the room's y
		return (
			absf(approach.size.y - depth) < 0.02
			and approach.position.x <= counter.position.x + 0.01
			and approach.end.x >= counter.end.x - 0.01
		)
	return (
		absf(approach.size.x - depth) < 0.02
		and approach.position.y <= counter.position.y + 0.01
		and approach.end.y >= counter.end.y - 0.01
	)


## The counter's centre in the room (its blocker's centre, so the shop stands exactly on it).
static func _counter_centre(placed: Dictionary) -> Vector2:
	var tags: Array[StringName] = placed["solid_tags"]
	var solids: Array[Obb] = placed["solids"]
	for k in tags.size():
		if tags[k] == &"shop_counter":
			return solids[k].center
	return _counter_box(placed).get_center()


## The counter's footprint in the room.
static func _counter_box(placed: Dictionary) -> Rect2:
	var tags: Array[StringName] = placed["solid_tags"]
	var solids: Array[Obb] = placed["solids"]
	for k in tags.size():
		if tags[k] == &"shop_counter":
			return solids[k].bounds()
	return solids[0].bounds() if not solids.is_empty() else Rect2()


## The placed group's shop_* pieces as f.shop_props entries.
static func _shop_props_of(placed: Dictionary, turn: int) -> Array:
	var out: Array = []
	var tags: Array[StringName] = placed["solid_tags"]
	var solids: Array[Obb] = placed["solids"]
	var sizes: Array[Vector2] = placed["sizes"]
	var heights: PackedFloat64Array = placed["solid_heights"]
	for k in tags.size():
		if _is_shop(tags[k]):
			var along := RoomLayouts.angle_in_room(0, turn, false)  # the frame's +x, as a drawn piece's yaw 0
			out.append([tags[k], solids[k].center, along, sizes[k], heights[k], true, &"", -1.0])
	for prop: Array in placed["props"]:
		if _is_shop(prop[0]):
			var on: int = prop[5]
			var under: StringName = tags[on] if on >= 0 else &""
			var lift: float = heights[on] if on >= 0 else -1.0
			out.append([prop[0], prop[1], prop[2], prop[3], prop[4], false, under, lift])
	return out


## Each solid's size before the turn (m), in the group's solid order.
static func _solid_sizes(g: RoomLayoutTable.Group) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in g.pieces:
		if p.solid:
			out.append(Vector2(p.size) / 100.0)
	return out


static func _is_shop(piece: StringName) -> bool:
	return String(piece).begins_with("shop_")


static func _in_any(q: Vector2, boxes: Array[Rect2]) -> bool:
	for box in boxes:
		if box.has_point(q):
			return true
	return false


static func _clear_of(q: Vector2, radius: float, walls: Array[Obb]) -> bool:
	for w in walls:
		if Collide.circle_vs_obb(q, radius, w) != Vector2.ZERO:
			return false
	return true


static func _cm(metres: float) -> float:
	return roundi(metres * 100.0) / 100.0
