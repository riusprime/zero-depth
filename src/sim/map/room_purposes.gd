class_name RoomPurposes
extends RefCounted
## Large rooms with a purpose (v0.11.0 O15, PLAN P1; owner Q26 (a), Q-O15a "all three", Q-O15b "authored templates
## with seeded variation"; docs/roadmap/v0.11.0/G2_ROOMS.md). Like the shop's room (ShopRoom.furnish), after the
## floor's room kinds are marked, a share of its large combat rooms is refurnished from a purpose template
## (RoomPurposeTable: a camp round a fire, a collapsed hall, a quarry):
## - Rooms (candidates): 3 x 3 cells and up, never the start hall, the portal room, the boss room or its host, the
##   shop's room, the Overrun room, an arena, a Lockdown or a room in `taken` (the shrine's). The events and the curse
##   room keep out of the purpose rooms (Events.place).
## - The draw: per room its own stream (`map:purpose:<room>`, never `map`, so the rest of the floor is unchanged):
##   whether it takes a purpose (FloorParams.purpose_permille), which (by weight among those whose biomes hold the
##   floor's and whose min_cells the room meets), then the template's variation (draw()) and the first mirror tried.
## - The mirror (either axis): tried from the drawn one, the first that drops the fewest groups wins (a focal group
##   costs FOCAL_COST, any other 1; a far_wall template whose focal wall faces the camera costs NEAR_COST more). A
##   group is dropped whole when a solid of it would leave the room, stand in a doorway's box (its width plus
##   DOOR_SIDE_M each side, DOOR_DEPTH_M deep) or come within ITEM_CLEAR_M of an item spot. No mirror keeps every
##   focal group: the room keeps its interior.
## - The room's flow: its open floor at the enemies' clearance stays one region holding every doorway's approach and
##   every item spot (FloorReach); where it would not, every non-focal group with a solid next to the floor cut off
##   is dropped, until it does (when only focal groups are next to it, or under MIN_KEPT_PERMILLE of the groups would
##   stand, the room keeps its interior).
## - The result: the room's old interior pieces leave f.walls (their drawn pieces leave layout_props); the template's
##   solids join f.walls (piece_tags / piece_heights: drawn by the dresser as a designed room's blockers), its drawn
##   pieces join layout_props; room_layout and room_purpose hold the purpose's id; the room's spawn points keep only
##   those clear of the new pieces and on its one region.
## Pure sim code: integer draws, centimetres, angles in 1/4096 turns, no trig.

const STREAM := "map:purpose"
const DOOR_SIDE_M := 1.0
const DOOR_DEPTH_M := 3.4
const ITEM_CLEAR_M := 1.6
const FOCAL_COST := 1000
const NEAR_COST := 100
## The least share (per mille) of the chosen mirror's groups with a solid that must still stand after the flow check;
## fewer, and the room keeps its interior (too little of the template would stand to read as its purpose).
const MIN_KEPT_PERMILLE := 700
const _DOOR_APPROACH := 1.0
const _INSET := 0.05


## A room of `cells` is large: 3 cells or more each way.
static func large(cells: Vector2i) -> bool:
	return mini(cells.x, cells.y) >= 3


## The rooms that may take a purpose, ascending.
static func candidates(
	f: FloorLayout, taken: PackedInt32Array = PackedInt32Array()
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := mini(f.room_cells.size(), mini(f.spawn_points.size(), f.room_layout.size()))
	for room in n:
		if not large(f.room_cells[room].size):
			continue
		if (
			room
			in [
				f.start_room,
				f.portal_room,
				f.boss_room,
				f.boss_host_room,
				f.shop_room,
				f.overrun_room
			]
		):
			continue
		if f.arena_rooms.has(room) or f.lockdown_rooms.has(room) or taken.has(room):
			continue
		out.append(room)
	return out


## Lays the purposes of floor `f` in biome `biome` from `tables` (see the class notes). Returns the rooms furnished.
static func lay(
	f: FloorLayout,
	p: FloorParams,
	tables: Array,
	biome: StringName,
	taken: PackedInt32Array = PackedInt32Array()
) -> PackedInt32Array:
	f.room_purpose.clear()
	for room in f.room_count():
		f.room_purpose.append(&"")
	var out := PackedInt32Array()
	if p.purpose_permille <= 0:
		return out
	var fits: Array = []
	for t: RoomPurposeTable in tables:
		if t.biomes.has(biome) and t.palettes.has(biome):
			fits.append(t)
	if fits.is_empty():
		return out
	for room in candidates(f, taken):
		var rng := RngStream.derive(f.seed_value, "%s:%d" % [STREAM, room])
		if not rng.chance_permille(p.purpose_permille):
			continue
		var list: Array = []
		var w := PackedInt32Array()
		for t: RoomPurposeTable in fits:
			if t.fits(f.room_cells[room].size):
				list.append(t)
				w.append(maxi(1, t.weight))
		if list.is_empty():
			continue
		var t: RoomPurposeTable = list[rng.pick_weighted(w)]
		if furnish(f, p, room, t, biome, rng):
			out.append(room)
	return out


## The template's parts in its frame for a room of half-size `half` (m, long side first), with the variation drawn from
## `rng`: [[token, centre (m), angle (1/4096), height scale, group index, the authored centre (m), the authored angle]],
## the groups and parts left out by their choice, chance or side not listed. Every group and part draws the same
## number of values whether it is laid or not.
static func draw(t: RoomPurposeTable, half: Vector2, rng: RngStream) -> Array:
	var picks := PackedInt32Array()
	for weights in t.choices:
		picks.append(rng.pick_weighted(weights))
	var out: Array = []
	for gi in t.groups.size():
		var g: RoomPurposeTable.Group = t.groups[gi]
		var keep := rng.chance_permille(g.chance_permille)
		var shift := Vector2(
			rng.range_int(-t.shift_cm, t.shift_cm), rng.range_int(-t.shift_cm, t.shift_cm)
		)
		var side := rng.range_int(1, 2)
		if g.choice >= 0 and not g.options.has(picks[g.choice]):
			keep = false
		var base := (
			Vector2(half.x * g.anchor.x / 1000.0, half.y * g.anchor.y / 1000.0)
			+ Vector2(g.offset) / 100.0
		)
		for part: RoomPurposeTable.Part in g.parts:
			var on := rng.chance_permille(part.chance_permille)
			var turn := rng.range_int(-t.turn, t.turn)
			var spread := rng.range_int(-part.spread_permille, part.spread_permille)
			if not keep or not on or (part.side != 0 and part.side != side):
				continue
			var authored := base + Vector2(part.at) / 100.0
			var scale := part.height_permille * (1000 + spread) / 1000
			out.append(
				[
					part.token,
					_cm(authored + shift / 100.0),
					posmod(part.angle + turn, SimTick.ANGLE_UNITS),
					scale / 1000.0,
					gi,
					authored,
					part.angle
				]
			)
	return out


## A frame point (m from the room's centre) and angle in room interior r at `mirror` (bit 0 flips the frame's x, bit
## 1 its y; a room taller than wide takes the frame's x along its y): [centre: Vector2, angle (1/4096)].
static func to_room(q: Vector2, angle: int, r: Rect2, mirror: int) -> Array:
	var a := angle
	if mirror & 1:
		q.x = -q.x
		a = 2048 - a
	if mirror & 2:
		q.y = -q.y
		a = -a
	if r.size.y > r.size.x:
		q = Vector2(q.y, q.x)
		a = 1024 - a
	return [_cm(r.get_center() + q), posmod(a, SimTick.ANGLE_UNITS)]


## True when the frame's +y (a far_wall template's focal wall) ends on a far side of room interior r at `mirror`: the
## iso camera looks toward the sim's -x and +y (IsoRig.YAW_DEG 45, SimPlane: 3D -z is the sim's +y).
static func far(r: Rect2, mirror: int) -> bool:
	var d := Vector2(0.0, -1.0 if mirror & 2 else 1.0)
	if r.size.y > r.size.x:
		d = Vector2(d.y, d.x)
	return d.y - d.x > 0.0


## The drawn parts laid in room `room` at `mirror`: {"groups": {group index: {"solids": Array[Obb], "tags":
## Array[StringName], "heights": Array of float (m; 0 the kit's own), "props": layout_props rows}} for the groups
## kept, "cost": the drops' cost}.
static func place(
	f: FloorLayout,
	room: int,
	t: RoomPurposeTable,
	biome: StringName,
	drawn: Array,
	mirror: int,
	boxes: Array[Rect2],
	items: PackedVector2Array
) -> Dictionary:
	var pal: Dictionary = t.palettes.get(biome, {})
	var r := f.rooms[room]
	var inner := r.grow(-_INSET)
	var by_group := {}
	var bad := {}
	for d: Array in drawn:
		var piece: RoomPurposeTable.Piece = pal.get(d[0])
		if piece == null:
			continue
		var gi: int = d[4]
		var at: Array = to_room(d[1], d[2], r, mirror)
		if not by_group.has(gi):
			var solids: Array[Obb] = []
			var tags: Array[StringName] = []
			by_group[gi] = {"solids": solids, "tags": tags, "heights": [], "props": []}
		var e: Dictionary = by_group[gi]
		var h: float = roundi(piece.height * float(d[3])) / 100.0
		if piece.solid:
			var o := Obb.make(at[0], Vector2(piece.size) / 200.0, at[1])
			var b := o.bounds()
			if not inner.encloses(b) or _in_boxes(b, boxes) or _near_items(b, items):
				bad[gi] = true
			(e["solids"] as Array[Obb]).append(o)
			(e["tags"] as Array[StringName]).append(piece.piece)
			(e["heights"] as Array).append(h)
		elif r.has_point(at[0]) and not _point_in_boxes(at[0], boxes):
			var row: Array = [piece.piece, at[0], at[1], Vector2(piece.size) / 100.0, h, ""]
			if piece.lift > 0:
				row.append(piece.lift / 100.0)  # layout_props' 7th field: resting this high
			(e["props"] as Array).append(row)
	var cost := 0
	for gi: int in bad:
		cost += FOCAL_COST if (t.groups[gi] as RoomPurposeTable.Group).focal else 1
		by_group.erase(gi)
	if t.far_wall and not far(r, mirror):
		cost += NEAR_COST
	return {"groups": by_group, "cost": cost}


## Furnishes room `room` with purpose `t` (see the class notes), its variation drawn from `rng`. True when it did.
static func furnish(
	f: FloorLayout,
	p: FloorParams,
	room: int,
	t: RoomPurposeTable,
	biome: StringName,
	rng: RngStream
) -> bool:
	var r := f.rooms[room]
	var half := Vector2(maxf(r.size.x, r.size.y), minf(r.size.x, r.size.y)) * 0.5
	var drawn := draw(t, half, rng)
	var start := rng.range_int(0, 3)
	var boxes := door_boxes(f, room)
	var items := items_in(f, room)
	var best := {}
	var best_cost := -1
	var best_m := start
	for k in 4:
		var m := (start + k) % 4
		var placed := place(f, room, t, biome, drawn, m, boxes, items)
		if best_cost < 0 or int(placed["cost"]) < best_cost:
			best = placed
			best_cost = placed["cost"]
			best_m = m
	if best_cost >= FOCAL_COST:
		return false
	var groups: Dictionary = best["groups"]
	var order: Array = groups.keys()
	order.sort()
	var inside := r.grow(0.01)
	var removed := {}
	var base: Array[Obb] = []
	var near := r.grow(1.0)
	for i in f.walls.size():
		var w := f.walls[i]
		if i >= f.slab_first and inside.encloses(w.bounds()):
			removed[FloorLayout.piece_key(w)] = true
		elif w.bounds().intersects(near):
			base.append(w)
	var must := f.door_approaches(room, _DOOR_APPROACH)
	must.append_array(items)
	while true:
		var stray := _stray(r, _with(base, groups, order), p.nav_clearance, must)
		if stray.is_empty():
			break
		var reach_m := p.nav_clearance + FloorReach.CELL
		var kept: Array = []
		for gi: int in order:
			var cut := false
			if not (t.groups[gi] as RoomPurposeTable.Group).focal:
				for o: Obb in groups[gi]["solids"]:
					var b := o.bounds().grow(reach_m)
					for q in stray:
						cut = cut or b.has_point(q)
			if not cut:
				kept.append(gi)
		if kept.size() == order.size():
			return false  # nothing of the purpose cuts the floor off (or only a focal group): keep the interior
		order = kept
	if (
		_solid_groups(groups, order) * 1000
		< _solid_groups(groups, groups.keys()) * MIN_KEPT_PERMILLE
	):
		return false  # too little of the template stands to read as its purpose: keep the interior
	_commit(f, p, room, t, best_m, removed, base, groups, order)
	return true


## The open floor cut off from the main region (the one holding the room's first must point) at `clearance`: the
## stray cells' centres and the must points outside it. Empty when the room is one region holding every must point.
static func _stray(
	r: Rect2, walls: Array[Obb], clearance: float, must: PackedVector2Array
) -> PackedVector2Array:
	var reach := FloorReach.new()
	reach.build(r, walls, clearance)
	var main := reach.region_at(must[0]) if not must.is_empty() else 0
	var out := PackedVector2Array()
	for q in must:
		if reach.region_at(q) != main or main < 0:
			out.append(q)
	if reach.region_count <= 1 and out.is_empty():
		return out
	for y in reach.size.y:
		for x in reach.size.x:
			var k := reach.region[y * reach.size.x + x]
			if k >= 0 and k != main:
				out.append(reach.center(Vector2i(x, y)))
	return out


static func _solid_groups(groups: Dictionary, order: Array) -> int:
	var n := 0
	for gi: int in order:
		n += 0 if (groups[gi]["solids"] as Array).is_empty() else 1
	return n


static func _with(base: Array[Obb], groups: Dictionary, order: Array) -> Array[Obb]:
	var out: Array[Obb] = base.duplicate()
	for gi: int in order:
		out.append_array(groups[gi]["solids"])
	return out


static func _commit(
	f: FloorLayout,
	p: FloorParams,
	room: int,
	t: RoomPurposeTable,
	mirror: int,
	removed: Dictionary,
	base: Array[Obb],
	groups: Dictionary,
	order: Array
) -> void:
	var r := f.rooms[room]
	var walls: Array[Obb] = []
	for i in f.walls.size():
		var key := FloorLayout.piece_key(f.walls[i])
		if i >= f.slab_first and removed.has(key):
			f.piece_tags.erase(key)
			f.piece_heights.erase(key)
			continue
		walls.append(f.walls[i])
	var props: Array = []
	for prop: Array in f.layout_props:
		if not r.has_point(prop[1]):
			props.append(prop)
	var added: Array[Obb] = []
	for gi: int in order:
		var e: Dictionary = groups[gi]
		var solids: Array[Obb] = e["solids"]
		for k in solids.size():
			var key := FloorLayout.piece_key(solids[k])
			f.piece_tags[key] = e["tags"][k]
			f.piece_heights[key] = e["heights"][k]
			added.append(solids[k])
		props.append_array(e["props"])
	walls.append_array(added)
	f.walls = walls
	f.layout_props = props
	f.room_layout[room] = t.id
	f.room_turn[room] = 0
	f.room_mirror[room] = mirror
	f.room_purpose[room] = t.id
	var all: Array[Obb] = base.duplicate()
	all.append_array(added)
	var reach := FloorReach.new()
	reach.build(r, all, p.nav_clearance)
	var spots := PackedVector2Array()
	for q in f.spawn_points[room]:
		if _clear_of(q, p.spawn_clearance, all) and reach.region_at(q) == 0:
			spots.append(q)
	f.spawn_points[room] = spots


## The boxes in front of a room's doorways a purpose keeps free: the doorway's width plus DOOR_SIDE_M each side,
## DOOR_DEPTH_M deep from the wall face (G2_ROOMS.md).
static func door_boxes(f: FloorLayout, room: int) -> Array[Rect2]:
	var q := FloorParams.new()
	q.layout_door_side = DOOR_SIDE_M
	q.layout_door_depth = DOOR_DEPTH_M
	return FloorGenerator.door_boxes(f, q, room)


## The room's item spots.
static func items_in(f: FloorLayout, room: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in f.item_spots.size():
		if f.item_rooms[i] == room:
			out.append(f.item_spots[i])
	return out


static func _in_boxes(b: Rect2, boxes: Array[Rect2]) -> bool:
	for box in boxes:
		if b.intersects(box):
			return true
	return false


static func _point_in_boxes(q: Vector2, boxes: Array[Rect2]) -> bool:
	for box in boxes:
		if box.has_point(q):
			return true
	return false


static func _near_items(b: Rect2, items: PackedVector2Array) -> bool:
	var grown := b.grow(ITEM_CLEAR_M)
	for q in items:
		if grown.has_point(q):
			return true
	return false


static func _clear_of(q: Vector2, radius: float, walls: Array[Obb]) -> bool:
	for w in walls:
		if Collide.circle_vs_obb(q, radius, w) != Vector2.ZERO:
			return false
	return true


static func _cm(v: Vector2) -> Vector2:
	return Vector2(roundi(v.x * 100.0) / 100.0, roundi(v.y * 100.0) / 100.0)
