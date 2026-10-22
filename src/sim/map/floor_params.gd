class_name FloorParams
extends RefCounted
## Starting values for one generated floor (v0.2.0 PLAN L5, L14-L15; v0.3.0 PLAN L1-L2). Lengths in sim metres;
## the generator draws lengths in whole centimetres from the `map` stream.

## The cell size, drawn per floor (each axis) from this range. Grid lines lie cell_size + wall_half_min +
## wall_half_max apart, and each room side is inset from its grid line by its own drawn half, so a one-cell
## room's interior (wall face to wall face) averages cell_size and is within 1.2 m of it either way.
var cell_size_min := Vector2(11.0, 9.0)
var cell_size_max := Vector2(14.0, 11.0)
## The start hall: one big room of this many cells, with no partitions inside.
var hall_cells := Vector2i(3, 3)
## Rooms on the floor, the hall included (the boss room makes one more), inclusive range. v0.7.5 MG (owner N9, "up
## to 20 rooms"): 15-19 (was 10-12). The run's floors take these, and the footprints and max_span below, from
## data/map (MapDefinition, RunContentCompiler.compile_map); these defaults equal that file's starting values.
var rooms_min := 15
var rooms_max := 19
## Room footprints (cells) for every room after the hall, and their draw weights. v0.7.5 MG (N9, "bigger rooms …
## even bigger rooms"): more weight on the big footprints, and 4 x 3, 3 x 4 and the extra-large 4 x 4 (was 1 x 1 to
## 3 x 3 weighted 30, 14, 14, 8, 8, 10, 5, 5, 3).
var footprints: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(1, 2),
	Vector2i(3, 1),
	Vector2i(1, 3),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(4, 3),
	Vector2i(3, 4),
	Vector2i(4, 4),
]
var footprint_weights := PackedInt32Array([22, 14, 14, 8, 8, 12, 7, 7, 5, 2, 2, 2])
## The whole floor fits in this many cells either way (keeps the floor compact and the nav grid bounded). v0.7.5 MG:
## 11 (was 8), for the extra rooms.
var max_span := 11
## Random placements tried for each room after the hall before giving up on the floor's room count (v0.7.5 MG: 600,
## was 400).
var place_attempts := 600
## Wall thickness (v0.3.0 L1). Each room side draws a half from this range: the wall material from its face out to
## its grid line. A partition is the two rooms' halves (0.6-5.0 m thick); an outer wall is twice its room's half
## (0.6-5.0 m), half inside the grid line and half outside. Owner, 2026-10-07, "Thicker room walls": the blink stays
## 5 m and the thickest walls can't be crossed even from point-blank (starting value; was 1.5).
var wall_half_min := 0.3
var wall_half_max := 2.5
## Doorway width, drawn per doorway (v0.3.0 L2).
var door_width_min := 2.2
var door_width_max := 3.4
## A doorway keeps this far from the corners of both rooms it joins; within that it lies anywhere along the
## stretch of wall the two rooms share.
var door_corner_margin := 0.6
## Extra doorways beyond the tree (between rooms that already touch), inclusive range.
var extra_links_min := 1
var extra_links_max := 2
## Interior templates: the chance (permille) that a template is mirrored or turned a quarter turn where that
## changes it (v0.3.0 L2; RoomInterior).
var template_flip_permille := 500
## Scattered-slab template (a boss arena's, BossRoomBuilder): slabs per cell at most, capped; their shape. Angles
## are multiples of 512.
var scatter_per_cell_max := 2
var scatter_cap := 10
var slab_half_thickness := 0.25
var slab_half_len_min := 1.2
var slab_half_len_max := 2.0
## Free space every interior piece keeps from every other wall and piece, so no narrow pocket forms behind it.
var slab_gap := 2.2
## Spawn points per room: base + per_extra_cell * (cells - 1), inclusive range, capped.
var spawn_min := 5
var spawn_max := 8
var spawn_min_per_extra_cell := 3
var spawn_max_per_extra_cell := 4
var spawn_cap := 40
## Chance (permille) that a room bigger than 1 x 1 gets a second item spot: base + per_cell * cells, capped.
var item_two_base := 300
var item_two_per_cell := 100
var item_two_cap := 800
## Minimum distance between the two item spots of one room.
var item_spacing := 4.0
## Clearance (circle radius) every item spot / spawn point keeps from every wall.
var item_clearance := 1.0
var spawn_clearance := 0.9
## Minimum spacing between spawn points of one room.
var spawn_spacing := 1.6
## The clearance of the connectivity flood (an enemy's NavField clearance; the player, 0.35 m, is smaller).
var nav_clearance := 0.6
## No interior piece within this radius of the start position.
var start_clear_radius := 3.5
## No interior piece within this radius of a doorway centre (on the wall line).
var door_clear_radius := 3.0
## v0.8.0 RT (owner O12): the designed room layouts, RoomLayouts.key(cells) -> Array of RoomLayoutTable
## (RunContentCompiler.compile_room_layouts, data/room_layouts). Empty (the default, and a floor saved before RT:
## RunSaver.floor_tables): every room keeps its rule-built interior (RoomInterior + RoomThemes) and the generator makes
## no layout draw, so that floor comes out as it was. A room whose size has no layout keeps it too, as do the start
## hall and the portal room.
var room_layouts := {}
## v0.8.0 RT: a designed room keeps its pieces out of a box in front of each doorway: the doorway's width plus this
## either side, this deep into the room from the wall face.
var layout_door_side := 1.0
var layout_door_depth := 3.0


static func defaults() -> FloorParams:
	return FloorParams.new()


## v0.7.5 MG: v0.7.0's room numbers (10-12 rooms, footprints up to 3 x 3, span 8, 400 attempts), for a v0.7.0 floor
## resumed from a save made before v0.7.5 (RunState.v070_floor): its walls must come out as they were saved.
static func v070() -> FloorParams:
	var p := FloorParams.new()
	p.rooms_min = 10
	p.rooms_max = 12
	p.footprints = [
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
		Vector2i(3, 1),
		Vector2i(1, 3),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(2, 3),
		Vector2i(3, 3),
	]
	p.footprint_weights = PackedInt32Array([30, 14, 14, 8, 8, 10, 5, 5, 3])
	p.max_span = 8
	p.place_attempts = 400
	return p
