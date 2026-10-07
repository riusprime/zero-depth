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
## Rooms on the floor, the hall included, inclusive range.
var rooms_min := 10
var rooms_max := 12
## Room footprints (cells) for every room after the hall, and their draw weights (few 3 x 3).
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
]
var footprint_weights := PackedInt32Array([30, 14, 14, 8, 8, 10, 5, 5, 3])
## The whole floor fits in this many cells either way (keeps the floor compact and the nav grid bounded).
var max_span := 8
## Random placements tried for each room after the hall before giving up on the floor's room count.
var place_attempts := 400
## Wall thickness (v0.3.0 L1). Each room side draws a half from this range: the wall material from its face out to
## its grid line. A partition is the two rooms' halves (0.6-3.0 m thick); an outer wall is twice its room's half
## (0.6-3.0 m), half inside the grid line and half outside.
var wall_half_min := 0.3
var wall_half_max := 1.5
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
## Scattered-slab template: slabs per cell, inclusive range, capped; their shape. Angles are multiples of 512.
var scatter_per_cell_min := 1
var scatter_per_cell_max := 2
var scatter_cap := 10
var slab_half_thickness := 0.25
var slab_half_len_min := 1.2
var slab_half_len_max := 2.0
## Free space every interior piece keeps from every other wall and piece, so no narrow pocket forms behind it.
var slab_gap := 2.2
## Random placements tried per scattered slab before that slab is dropped.
var slab_attempts := 30
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


static func defaults() -> FloorParams:
	return FloorParams.new()
