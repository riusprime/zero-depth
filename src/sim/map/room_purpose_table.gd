class_name RoomPurposeTable
extends RefCounted
## A large room's purpose, compiled (v0.11.0 O15; RoomPurposeDefinition, RunContentCompiler.compile_room_purposes):
## whole centimetres, per mille and angles in 1/4096 turns, the groups' yaws already applied to their parts. In the
## template's frame: x along the room's long side, the room's centre (0, 0). RoomPurposes draws and lays it.


## A group: its anchor (per mille of the half-size) plus offset (cm), whether it is focal, the choice (an index into
## `choices`, -1 none) and the options that keep it, its chance and its parts.
class Group:
	var anchor := Vector2i.ZERO
	var offset := Vector2i.ZERO
	var focal := false
	var choice := -1
	var options := PackedInt32Array()
	var chance_permille := 1000
	var parts: Array = []  # of Part


## A part: its token, centre (cm from the group's anchor, turned with the group), angle (1/4096), height scale and
## spread (per mille), side (0 always, 1 or 2 one side of its group) and chance.
class Part:
	var token := &""
	var at := Vector2i.ZERO
	var angle := 0
	var height_permille := 1000
	var spread_permille := 0
	var side := 0
	var chance_permille := 1000


## A biome's piece for a token: the kit piece, its footprint (cm), its height (cm; 0 the kit's own), solid or drawn.
class Piece:
	var piece := &""
	var size := Vector2i(100, 100)
	var height := 0
	var solid := true
	## A drawn piece's base height (cm; a lintel on its stones), 0 on the ground.
	var lift := 0


var id := &""
## The least room (cells, long side first).
var min_cells := Vector2i(3, 3)
var weight := 1
var biomes: Array[StringName] = []
var far_wall := false
## The seeded shift per group (cm, each axis) and turn per part (1/4096), at most.
var shift_cm := 0
var turn := 0
## Per choice, its options' weights.
var choices: Array[PackedInt32Array] = []
var groups: Array = []  # of Group
## biome -> {token: Piece}.
var palettes := {}


## True when a room of `cells` (any way round) is at least min_cells.
func fits(cells: Vector2i) -> bool:
	var k := Vector2i(maxi(cells.x, cells.y), mini(cells.x, cells.y))
	return k.x >= min_cells.x and k.y >= min_cells.y
