class_name CurseRoom
extends RefCounted
## The curse room as a room type of its own (v0.8.0 N19, owner O80: "The curse room should be a fixed unique small
## room in every biome like the store … the room should have crystals and ambiented like a dark pact room"). Like the
## shop's room (ShopRoom.furnish), the room Events.curse_site picked is emptied and given one fixed layout, the same in
## every biome (CurseRoomView dresses it dark; only the biome's ground shows):
## - its old interior goes (every interior piece inside it leaves f.walls, its drawn pieces leave layout_props and its
##   designed layout is replaced by LAYOUT_ID);
## - the curse altar stands at its spot (Events.curse_spot: the room's centre whenever it is clear), its footprint a
##   wall (ALTAR_HALF_M), with a clear walk-up all round;
## - crystal clusters stand in the room's corners and along its sides (CRYSTAL_SPOTS, CRYSTAL_HALF_M), each kept only
##   when it leaves every doorway's box clear, keeps the item clearance from the room's item spots, keeps
##   CRYSTAL_ALTAR_GAP_M from the altar and the room's open floor one region holding every doorway approach, every
##   item spot and the altar's front (at the enemies' clearance, as ShopRoom);
## - no enemy spawns inside it (its spawn points are dropped).
## No draw: a pure function of the layout and the altar's spot, so the same seed gives the same room. Pure sim code.

const LAYOUT_ID := &"curse_room"
## The altar's footprint (a square of this half side; the model is 1.4 m across, CurseRoomView).
const ALTAR_HALF_M := 0.55
## A crystal cluster's footprint (half side) and how far it stands in from the walls it hugs.
const CRYSTAL_HALF_M := 0.45
const CRYSTAL_INSET_M := 0.12
## No crystal this close to the altar's centre (the walk-up stays open).
const CRYSTAL_ALTAR_GAP_M := 2.6
## Where the crystals may stand, as fractions of the room (0 a side's wall, 1000 the other's): the four corners, then
## the middle of each side, then the thirds of the long sides.
const CRYSTAL_SPOTS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1000, 0),
	Vector2i(0, 1000),
	Vector2i(1000, 1000),
	Vector2i(500, 0),
	Vector2i(500, 1000),
	Vector2i(0, 500),
	Vector2i(1000, 500),
	Vector2i(250, 0),
	Vector2i(750, 1000),
]
## The altar's walk-up is checked open this far out from its centre (its half side, the enemies' clearance and a cell
## of slack, as ShopRoom.FRONT_SLACK_M: the walkability grid's cells there are open whatever their alignment).
const FRONT_M := 1.8
const _DOOR_APPROACH := 1.0


## Furnishes room `room` of `f` as the curse room with the altar at `at` (Events.place, N19 rules). Returns the solids
## to add as walls (the altar's footprint first, then each crystal's), also kept in f.curse_solids.
static func furnish(f: FloorLayout, room: int, at: Vector2, p: FloorParams = null) -> Array[Obb]:
	var params := p if p != null else FloorParams.defaults()
	var r := f.rooms[room]
	var inside := r.grow(0.01)
	var walls: Array[Obb] = []
	for i in f.walls.size():
		var w := f.walls[i]
		if i >= f.slab_first and inside.encloses(w.bounds()):
			f.piece_tags.erase(FloorLayout.piece_key(w))
			f.piece_heights.erase(FloorLayout.piece_key(w))
			continue
		walls.append(w)
	f.walls = walls
	var props: Array = []
	for prop: Array in f.layout_props:
		if not r.has_point(prop[1]):
			props.append(prop)
	f.layout_props = props
	if room < f.room_layout.size():
		f.room_layout[room] = LAYOUT_ID
		f.room_turn[room] = 0
		f.room_mirror[room] = 0
	var solids: Array[Obb] = [Obb.make(at, Vector2(ALTAR_HALF_M, ALTAR_HALF_M), 0)]
	var base: Array[Obb] = f.room_walls(room)
	base.append(solids[0])
	var must := f.door_approaches(room, _DOOR_APPROACH)
	must.append(front(f, room, at))
	var items := PackedVector2Array()
	for i in f.item_spots.size():
		if f.item_rooms[i] == room:
			items.append(f.item_spots[i])
	must.append_array(items)
	var boxes := FloorGenerator.door_boxes(f, params, room)
	for q in crystal_spots(r):
		var o := Obb.make(q, Vector2(CRYSTAL_HALF_M, CRYSTAL_HALF_M), 0)
		if not _crystal_ok(o, at, boxes, items, params):
			continue
		var trial: Array[Obb] = base.duplicate()
		trial.append(o)
		if FloorReach.whole(r, trial, params.nav_clearance, must):
			base.append(o)
			solids.append(o)
	f.curse_room = room
	f.curse_solids = solids
	if room < f.spawn_points.size():
		f.spawn_points[room] = PackedVector2Array()
	return solids


## The crystal spots of room interior `r` (CRYSTAL_SPOTS), each a cluster's centre hugging the walls.
static func crystal_spots(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pad := CRYSTAL_HALF_M + CRYSTAL_INSET_M
	var inner := r.grow(-pad)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return out
	for s in CRYSTAL_SPOTS:
		out.append(
			Vector2(
				inner.position.x + inner.size.x * s.x / 1000.0,
				inner.position.y + inner.size.y * s.y / 1000.0
			)
		)
	return out


## Where you stand to touch the altar at `at`: FRONT_M from it toward the room's first doorway (along the axis it is
## farthest along), or toward +y when the room has none.
static func front(f: FloorLayout, room: int, at: Vector2) -> Vector2:
	var approaches := f.door_approaches(room, _DOOR_APPROACH)
	if approaches.is_empty():
		return at + Vector2(0, FRONT_M)
	var d := approaches[0] - at
	if absf(d.x) >= absf(d.y):
		return at + Vector2(FRONT_M if d.x > 0.0 else -FRONT_M, 0)
	return at + Vector2(0, FRONT_M if d.y > 0.0 else -FRONT_M)


static func _crystal_ok(
	o: Obb, at: Vector2, boxes: Array[Rect2], items: PackedVector2Array, p: FloorParams
) -> bool:
	if Kin.length(o.center - at) < CRYSTAL_ALTAR_GAP_M:
		return false
	var b := o.bounds()
	for box in boxes:
		if b.intersects(box):
			return false
	for q in items:
		if Collide.circle_vs_obb(q, p.item_clearance, o) != Vector2.ZERO:
			return false
	return true
