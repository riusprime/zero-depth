class_name RoomLayoutTable
extends RefCounted
## A designed room interior, compiled (v0.8.0 RT; RoomLayoutDefinition, RunContentCompiler.compile_room_layouts):
## whole centimetres and angles in 1/4096 turns, in the layout's own frame (+x along the room's long side). RoomLayouts
## turns, mirrors and places it.


## One piece: a sim blocker (solid) or a drawn-only piece.
class Piece:
	extends RefCounted
	var piece := &""
	## Its centre from the group's anchor, and its footprint (before its angle), in cm.
	var at := Vector2i.ZERO
	var size := Vector2i(100, 100)
	## Its turn (1/4096; a solid's is 0), and its drawn height in cm (0: the kit's own).
	var angle := 0
	var height := 0
	var solid := false


## A cluster around an anchor (a fraction of the room, per mille of each side of the layout's frame).
class Group:
	extends RefCounted
	var anchor := Vector2i(500, 500)
	var pieces: Array[Piece] = []


var id := &""
## The room size it is drawn for (x >= y).
var cells := Vector2i(2, 2)
var weight := 1
var groups: Array[Group] = []
## Open lanes (per mille of the room in the layout's frame), for the tests' design checks.
var keep_clear: Array[Rect2i] = []
