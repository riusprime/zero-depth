class_name IcePatches
extends RefCounted
## v0.7.5 NB1: lays a floor's ice patches (Frozen Shore) and says when the hero stands on one. A pure function of the
## layout, the walls and the floor seed, drawn from the `map:ice` sub-stream (derived from World.seed_value like
## `map:event`), so no other draw moves and a resumed floor lays the same patches.
##
## Rules (starting values in BiomeSurface):
## - never in the start hall, the boss room, the portal's room or the shop's room (fights with the boss and the
##   floor's first steps stay on firm ground);
## - each other room gets patches with chance room_share_permille, patches_min..patches_max of them;
## - a patch is an axis-aligned rectangle, its sides size_min..size_max in 0.5 m steps, inside the room inset by
##   clearance_m, clear (by clearance_m) of every doorway, wall, item spot, the start and the gates; up to
##   ATTEMPTS tries each, then it is skipped (never forced).

const ATTEMPTS := 8
const STREAM := "map:ice"


## v0.7.5 NB2: a surface's own sub-stream, `map:<kind>` (ice: STREAM, unchanged; Starfall's starglow:
## `map:starglow`), so two surfaces never share draws and neither moves any other stream.
static func stream_of(kind: StringName) -> String:
	return STREAM if kind == &"ice" else "map:" + String(kind)


## Places `field`'s patches on `w`'s floor and sets World.ice. No floor or no field: nothing happens.
static func place(w: World, field: IceField) -> void:
	if field == null or w.floor_layout == null:
		return
	lay(w.floor_layout, w.walls, w.seed_value, field)
	w.ice = field


## Fills `field.rects` for a floor: its layout, every wall and cover box (the gates' footprints included) and its
## seed. A pure function: the same inputs give the same patches.
static func lay(layout: FloorLayout, walls: Array[Obb], seed_value: int, field: IceField) -> void:
	field.rects.clear()
	var rng := RngStream.derive(seed_value, stream_of(field.kind))
	var keep: Array[Vector2] = [layout.start_pos, layout.portal_pos]
	if layout.has_deep_portal:
		keep.append(layout.deep_portal_pos)
	if layout.shop_room >= 0:
		keep.append(layout.shop_pos)
	for p in layout.item_spots:
		keep.append(p)
	var blocked: Array[Rect2] = []
	for i in layout.door_centers.size():
		blocked.append(layout.door_rect(i))
	for o in walls:
		blocked.append(o.bounds())
	var skip := [layout.start_room, layout.boss_room, layout.portal_room, layout.shop_room]
	for r in layout.rooms.size():
		# Every room draws, so whether one room is skipped never shifts another room's patches.
		var chosen := rng.chance_permille(field.room_share_permille)
		var count := rng.range_int(field.patches_min, field.patches_max)
		if r in skip or not chosen:
			continue
		var room := layout.rooms[r].grow(-field.clearance_m)
		for k in count:
			for attempt in ATTEMPTS:
				var rect := _draw(rng, room, field)
				if rect.size == Vector2.ZERO:
					break
				if _fits(rect, field, blocked, keep):
					field.rects.append(rect)
					break


## A patch inside `room`, or an empty rect when the room is too small for the smallest patch.
static func _draw(rng: RngStream, room: Rect2, field: IceField) -> Rect2:
	var lo := field.size_min_dm / 5
	var hi := field.size_max_dm / 5
	var sx := mini(rng.range_int(lo, hi), int(room.size.x * 2.0))
	var sy := mini(rng.range_int(lo, hi), int(room.size.y * 2.0))
	if sx < lo or sy < lo:
		return Rect2()
	var size := Vector2(sx, sy) * 0.5
	var free_x := int((room.size.x - size.x) * 2.0)
	var free_y := int((room.size.y - size.y) * 2.0)
	var at := room.position + Vector2(rng.range_int(0, free_x), rng.range_int(0, free_y)) * 0.5
	return Rect2(at, size)


static func _fits(
	rect: Rect2, field: IceField, blocked: Array[Rect2], keep: Array[Vector2]
) -> bool:
	var grown := rect.grow(field.clearance_m)
	for b in blocked:
		if grown.intersects(b):
			return false
	for p in keep:
		if grown.has_point(p):
			return false
	for other in field.rects:
		if grown.intersects(other):
			return false
	return true


## True when the hero stands on ice this tick.
static func on_ice(w: World) -> bool:
	return w.ice != null and w.ice.covers(w.player_pos())
