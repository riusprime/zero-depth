class_name GateClearance
extends RefCounted
## Where a gate stands from the wall
## it backs onto and the zone kept clear round it, for FloorGenerator, BossRoomBuilder and Routes.


## The kept-clear zone of a gate at `pos` facing `angle` on floor `f` (the gate's, or the Deep gate's: Routes.zone):
## from the wall face (the gap behind the oval included), its sides, and its clear front plus a margin.
static func zone(f: FloorLayout, pos: Vector2, angle: int) -> Rect2:
	var n := Kin.dir(angle)
	var t := Vector2(-n.y, n.x)
	var back := wall_offset(f)
	var face := pos - n * back
	var half_w := FloorLayout.GATE_WIDTH * 0.5 + zone_side(f)
	var depth := back + FloorLayout.GATE_HALF_DEPTH + FloorLayout.GATE_FRONT + 1.0
	return Rect2(face + t * half_w, Vector2.ZERO).expand(face - t * half_w + n * depth)


## How far a gate's centre stands out from the wall it backs onto: GATE_WALL_CLEAR.
static func wall_offset(_f: FloorLayout) -> float:
	return FloorLayout.GATE_WALL_CLEAR


## How far a gate's zone reaches past its GATE_WIDTH sides.
static func zone_side(_f: FloorLayout) -> float:
	return FloorLayout.GATE_ZONE_HALF_W - FloorLayout.GATE_WIDTH * 0.5


## Whether room rect `room` keeps the oval of a gate at `pos` facing `angle` clear of its walls.
static func oval_fits(_f: FloorLayout, room: Rect2, pos: Vector2, angle: int) -> bool:
	return room.encloses(FloorLayout.oval_clear_rect(pos, angle))
