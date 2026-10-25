class_name GateClearance
extends RefCounted
## v0.9.0 PT (owner: "there should be an space between the wall and the portals"): where a gate stands from the wall
## it backs onto and the zone kept clear round it, for FloorGenerator, BossRoomBuilder and Routes. A floor built
## under floor rules 1-9 (FloorLayout.legacy_gate) keeps the placement it was saved with.


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


## How far a gate's centre stands out from the wall it backs onto: GATE_WALL_CLEAR, or (legacy_gate) the old frame's
## half depth, against the wall.
static func wall_offset(f: FloorLayout) -> float:
	return FloorLayout.GATE_HALF_DEPTH if f.legacy_gate else FloorLayout.GATE_WALL_CLEAR


## How far a gate's zone reaches past its GATE_WIDTH sides.
static func zone_side(f: FloorLayout) -> float:
	if f.legacy_gate:
		return FloorLayout.LEGACY_ZONE_SIDE
	return FloorLayout.GATE_ZONE_HALF_W - FloorLayout.GATE_WIDTH * 0.5


## Whether room rect `room` keeps the oval of a gate at `pos` facing `angle` clear of its walls (always, on a
## legacy_gate floor: it had no oval).
static func oval_fits(f: FloorLayout, room: Rect2, pos: Vector2, angle: int) -> bool:
	return f.legacy_gate or room.encloses(FloorLayout.oval_clear_rect(pos, angle))
