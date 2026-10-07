class_name FloorParams
extends RefCounted
## Starting values for one generated floor (v0.2.0 PLAN, "Floor"). Lengths in sim metres; the generator draws
## lengths in whole centimetres from the `map` stream.

var cols := 3
var rows := 3
## Interior size of one room (wall face to wall face).
var room_size := Vector2(14.0, 12.0)
## Half-thickness of every outer and partition wall.
var wall_half := 0.4
## Width of a doorway gap.
var door_width := 2.6
## How far a doorway may slide from the middle of its wall, either way.
var door_jitter := 2.0
## Extra doorways beyond the spanning tree, inclusive range.
var extra_links_min := 1
var extra_links_max := 2
## Interior slabs per room, inclusive range, and their shape. Angles are multiples of 512.
var slabs_min := 0
var slabs_max := 3
var slab_half_thickness := 0.25
var slab_half_len_min := 1.2
var slab_half_len_max := 2.0
## Free space every slab keeps from every other wall and slab, so no narrow pocket forms behind it.
var slab_gap := 2.2
## Random placements tried per slab before that slab is dropped.
var slab_attempts := 30
## Spawn points per room, inclusive range.
var spawn_min := 6
var spawn_max := 10
## Clearance (circle radius) every item spot / spawn point keeps from every wall.
var item_clearance := 1.0
var spawn_clearance := 0.9
## Minimum spacing between spawn points of one room.
var spawn_spacing := 1.6
## The clearance of the connectivity flood (an enemy's NavField clearance; the player, 0.35 m, is smaller).
var nav_clearance := 0.6
## No slab within this radius of the start position.
var start_clear_radius := 3.5
## No slab within this radius of a doorway centre (on the wall line).
var door_clear_radius := 3.0


static func defaults() -> FloorParams:
	return FloorParams.new()
