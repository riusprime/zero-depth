class_name FloorParams
extends RefCounted
## Starting values for one generated floor (v0.2.0 PLAN L5, L14-L15). Lengths in sim metres; the generator draws
## lengths in whole centimetres from the `map` stream.

## Interior size of one grid cell (wall face to wall face). A room of w x h cells spans the walls between its
## cells, so its interior is w * pitch - 2 * wall_half wide (pitch = cell_size + 2 * wall_half).
var cell_size := Vector2(12.0, 10.0)
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
## Half-thickness of every outer and partition wall.
var wall_half := 0.4
## Width of a doorway gap.
var door_width := 2.6
## How far a doorway may slide from the middle of its cell edge, either way.
var door_jitter := 2.0
## Extra doorways beyond the tree (between rooms that already touch), inclusive range.
var extra_links_min := 1
var extra_links_max := 2
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
