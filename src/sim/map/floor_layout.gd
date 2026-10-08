class_name FloorLayout
extends RefCounted
## One generated floor (FloorGenerator.generate). Plain data in sim metres; angles in 1/4096 turns.
## Rooms sit on a grid of cells (the floor's drawn cell size plus the walls between cells). Room 0 is the start
## hall; the others are numbered in the order they were attached. Walls have thickness (v0.3.0 L1): each room
## side is inset from its grid line by its own drawn half, so a partition is as thick as the two halves beside it.

## Interior templates (room_template). Each is scaled to the room's size by RoomInterior.
enum Template { OPEN, SCATTER, PILLARS, CENTRE, CROSS, LINES, BUNKERS, COLONNADE, DIAGONALS }

## The portal gate: 2.4 m wide, standing against a wall of the portal room.
const GATE_WIDTH := 2.4
## Half-depth of the gate's footprint (pillars) along its facing.
const GATE_HALF_DEPTH := 0.4
## Side of the square kept clear in front of the gate.
const GATE_FRONT := 3.0

## How many templates there are, and their names (for tools and evidence).
const TEMPLATE_COUNT := 9
const TEMPLATE_NAMES: Array[String] = [
	"open", "scatter", "pillars", "centre", "cross", "lines", "bunkers", "colonnade", "diagonals"
]

var seed_value := 0
## The grid's extent in cells (the bounding box of every room).
var cols := 0
var rows := 0
## This floor's drawn cell size (FloorParams.cell_size_min..max).
var cell_size := Vector2.ZERO
## Distance between grid lines (a cell plus the mean wall thickness), and where grid line (0, 0) lies.
var cell_pitch := Vector2.ZERO
var grid_origin := Vector2.ZERO
## Every wall: the outer walls and partitions first, then the interior pieces (from index slab_first).
var walls: Array[Obb] = []
var slab_first := 0
## Room interiors (wall face to wall face).
var rooms: Array[Rect2] = []
## Each room side's wall half: room_halves[room * 4 + side] (side 0 +X, 1 +Y, 2 -X, 3 -Y) is how far that face
## lies inside its grid line. An outer side's wall reaches as far again outside the grid line.
var room_halves := PackedFloat64Array()
## Each room's footprint on the cell grid: position = its first cell, size = its cells (e.g. 3 x 1).
var room_cells: Array[Rect2i] = []
## Each room's interior template (Template).
var room_template := PackedInt32Array()
## Doorway i joins rooms door_rooms[i].x < door_rooms[i].y. Its centre lies on the wall's centre line, and
## door_angles[i] is the direction from room x to room y (0 = +X, 1024 = +Y, 2048 = -X, 3072 = -Y).
var door_rooms: Array[Vector2i] = []
## The doorway's centre is the middle of its passage through the wall, halfway between the two wall faces.
var door_centers := PackedVector2Array()
var door_angles := PackedInt32Array()
## The doorway's width (along the wall) and depth (through it: the wall's thickness there).
var door_widths := PackedFloat64Array()
var door_depths := PackedFloat64Array()
var start_room := 0
var portal_room := 0
var start_pos := Vector2.ZERO
## The centre of the gate's footprint; the gate faces portal_angle (into the room).
var portal_pos := Vector2.ZERO
var portal_angle := 0
## Item spots: 1 in a 1 x 1 room, 1-2 in bigger rooms, none in the start hall. Grouped by room in room order;
## item_rooms[i] is spot i's room.
var item_spots := PackedVector2Array()
var item_rooms := PackedInt32Array()
## Open spots per room (index = room).
var spawn_points: Array[PackedVector2Array] = []
## Doorway hops from the start room, per room.
var hops := PackedInt32Array()
## A box around the whole floor, centred on the origin: the grid's outer lines grown by the thickest outer half.
var bounds := Rect2()
## The boss room (v0.3.0 B; BossRoomBuilder.attach, -1 before it runs). It opens off boss_host_room (the farthest
## room) through one doorway: its centre on the wall line, boss_door_angle the direction from the host into the boss
## room, its width, and the collider that seals it once you are inside. The boss appears at boss_spawn.
var boss_room := -1
var boss_host_room := -1
var boss_door_center := Vector2.ZERO
var boss_door_angle := 0
var boss_door_width := 0.0
var boss_door_wall: Obb
## The boss door's index in the doorway arrays, and the boss room's cells in metres (grid line to grid line).
var boss_door_index := -1
var boss_cells_rect := Rect2()
var boss_spawn := Vector2.ZERO
## The shop (v0.5.0 SH; ShopPlacement.pick, -1 before it runs): its room, the terminal's centre and its facing.
var shop_room := -1
var shop_pos := Vector2.ZERO
var shop_angle := 0
## The floor's footprint, for drawing ground: each room's cells (interior, walls and doorways up to its grid
## lines), then the outer half of each outer wall.
var ground: Array[Rect2] = []


func room_count() -> int:
	return rooms.size()


## The room whose interior contains p, or -1 (inside a wall or a doorway, or outside).
func room_of(p: Vector2) -> int:
	for i in rooms.size():
		if rooms[i].has_point(p):
			return i
	return -1


## Rooms joined to room by a doorway, ascending.
func neighbours(room: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for d in door_rooms:
		if d.x == room and not out.has(d.y):
			out.append(d.y)
		elif d.y == room and not out.has(d.x):
			out.append(d.x)
	out.sort()
	return out


## How many grid cells a room covers.
func room_cell_count(room: int) -> int:
	return room_cells[room].size.x * room_cells[room].size.y


## The open passage of doorway i through the wall, from one room's face to the other's.
func door_rect(i: int) -> Rect2:
	var c := door_centers[i]
	var h := Vector2(door_depths[i], door_widths[i]) * 0.5
	if door_angles[i] % 2048 == 1024:
		h = Vector2(h.y, h.x)
	return Rect2(c - h, h * 2.0)


## The unit direction the gate faces (into the portal room).
func portal_facing() -> Vector2:
	return Kin.dir(portal_angle)


## The clear GATE_FRONT square directly in front of the gate (axis-aligned: the gate faces a grid axis).
func portal_front() -> Rect2:
	var c := portal_pos + portal_facing() * (GATE_HALF_DEPTH + GATE_FRONT * 0.5)
	var h := GATE_FRONT * 0.5
	return Rect2(c - Vector2(h, h), Vector2(GATE_FRONT, GATE_FRONT))


## The middle of the clear area in front of the gate: where the player walks into it from.
func portal_front_point() -> Vector2:
	return portal_front().get_center()


## How far p is past the boss door's wall line, into the boss room (negative before it; 0 without a boss room).
func boss_door_depth(p: Vector2) -> float:
	if boss_room < 0:
		return 0.0
	return (p - boss_door_center).dot(Kin.dir(boss_door_angle))


## A point `m` metres into the boss room past the boss door's inner face (negative m: back toward the host).
func boss_door_inside(m: float) -> Vector2:
	var half := door_depths[boss_door_index] * 0.5 if boss_door_index >= 0 else 0.0
	return boss_door_center + Kin.dir(boss_door_angle) * (half + m)


## A point `m` metres into the host room before the boss door's outer (host) face.
func boss_door_outside(m: float) -> Vector2:
	var half := door_depths[boss_door_index] * 0.5 if boss_door_index >= 0 else 0.0
	return boss_door_center - Kin.dir(boss_door_angle) * (half + m)
