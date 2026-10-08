class_name ShopPlacement
extends RefCounted
## Where the floor's shop stands (v0.5.0 SH, ROADMAP "Shops"): one terminal per floor, in a side room. A pass of its
## own after FloorGenerator.generate and BossRoomBuilder.attach, so the rest of the floor is unchanged and other
## room features pick their rooms in their own functions.
## - Rooms: never the start hall, the boss room or the room before the boss door (its host). Dead ends (one
##   doorway) come first, in an order drawn from the `shop_room` stream (never `map`); then every other room.
## - Spot: the room's centre, then its spawn points nearest the centre first: inside the room and clear of every wall
##   by CLEAR_M, ITEM_GAP_M from the room's item spots, DOOR_GAP_M from its doorways' approaches, and with the
##   terminal's footprint as a wall the room's open floor stays one region that holds every doorway approach, every
##   item spot and the terminal's front (at the enemies' clearance, stricter than the player's).
## - Facing: toward the room's first doorway, so you walk up to its screen.
## The first room with a spot wins. Pure sim code: integer draws, no trig.

## The terminal's footprint: a square of this half side, turned to its facing (Shop.collider).
const FOOTPRINT_HALF_M := 0.5
const CLEAR_M := 1.3
const ITEM_GAP_M := 3.0
const DOOR_GAP_M := 2.5
## The terminal's front: where you stand to use it.
const FRONT_M := 1.2
const _DOOR_APPROACH := 1.0


## Sets f.shop_room, f.shop_pos and f.shop_angle. Returns the room, or -1 when no room has a spot (the property test
## proves this never happens over 1,000 seeds).
static func pick(f: FloorLayout, params: FloorParams = null) -> int:
	var p := params if params != null else FloorParams.defaults()
	f.shop_room = -1
	var dead := PackedInt32Array()
	var other := PackedInt32Array()
	for room in f.room_count():
		if not allowed(f, room):
			continue
		if f.neighbours(room).size() == 1:
			dead.append(room)
		else:
			other.append(room)
	var rng := RngStream.derive(f.seed_value, "shop_room")
	for k in range(dead.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := dead[k]
		dead[k] = dead[j]
		dead[j] = swap
	dead.append_array(other)
	for room in dead:
		if _place_in(f, p, room):
			return room
	return -1


## A room the shop may stand in.
static func allowed(f: FloorLayout, room: int) -> bool:
	return (
		room != f.start_room
		and room != f.boss_room
		and room != f.boss_host_room
		and room < f.hops.size()
		and f.hops[room] > 0
	)


## Where the player stands to use the terminal.
static func front(f: FloorLayout) -> Vector2:
	return f.shop_pos + Kin.dir(f.shop_angle) * FRONT_M


## The terminal's footprint as a wall.
static func collider(at: Vector2, angle: int) -> Obb:
	return Obb.make(at, Vector2(FOOTPRINT_HALF_M, FOOTPRINT_HALF_M), angle)


static func _place_in(f: FloorLayout, p: FloorParams, room: int) -> bool:
	var r := f.rooms[room]
	var approaches := door_approaches(f, room)
	if approaches.is_empty():
		return false
	var centre := r.get_center()
	var spots := PackedVector2Array([centre])
	var pts := f.spawn_points[room] if room < f.spawn_points.size() else PackedVector2Array()
	var order := Array(pts)
	order.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			var da := Kin.length(a - centre)
			var db := Kin.length(b - centre)
			return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y)))
	)
	for q: Vector2 in order:
		spots.append(q)
	var walls := _room_walls(f, room)
	for q in spots:
		if not _spot_ok(f, room, q, walls, approaches):
			continue
		var angle := Kin.angle_of(approaches[0] - q)
		var with: Array[Obb] = walls.duplicate()
		with.append(collider(q, angle))
		var must := approaches.duplicate()
		must.append(q + Kin.dir(angle) * FRONT_M)
		for i in f.item_spots.size():
			if f.item_rooms[i] == room:
				must.append(f.item_spots[i])
		if _whole(r, with, p.nav_clearance, must):
			f.shop_room = room
			f.shop_pos = q
			f.shop_angle = angle
			return true
	return false


static func _spot_ok(
	f: FloorLayout, room: int, q: Vector2, walls: Array[Obb], approaches: PackedVector2Array
) -> bool:
	if not f.rooms[room].grow(-CLEAR_M).has_point(q):
		return false
	for o in walls:
		if Collide.circle_vs_obb(q, CLEAR_M, o) != Vector2.ZERO:
			return false
	for i in f.item_spots.size():
		if Kin.length(f.item_spots[i] - q) < ITEM_GAP_M:
			return false
	for a in approaches:
		if Kin.length(a - q) < DOOR_GAP_M:
			return false
	return true


## The room's open floor at `clearance` is one region holding every point in `must`.
static func _whole(r: Rect2, walls: Array[Obb], clearance: float, must: PackedVector2Array) -> bool:
	var reach := FloorReach.new()
	reach.build(r, walls, clearance)
	if reach.region_count != 1:
		return false
	for q in must:
		if reach.region_at(q) != 0:
			return false
	return true


## The walls that can touch a room.
static func _room_walls(f: FloorLayout, room: int) -> Array[Obb]:
	var near := f.rooms[room].grow(1.0)
	var out: Array[Obb] = []
	for o in f.walls:
		if o.bounds().intersects(near):
			out.append(o)
	return out


## The room's doorways as points just inside it (door order).
static func door_approaches(f: FloorLayout, room: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for d in f.door_rooms.size():
		var into := 0
		if f.door_rooms[d].x == room:
			into = -1  # the doorway points from x to y: into x is backwards
		elif f.door_rooms[d].y == room:
			into = 1
		else:
			continue
		var step := Kin.dir(f.door_angles[d]) * float(into)
		out.append(f.door_centers[d] + step * (f.door_depths[d] * 0.5 + _DOOR_APPROACH))
	return out
