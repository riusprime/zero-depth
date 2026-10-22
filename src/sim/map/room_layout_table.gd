class_name RoomLayoutTable
extends RefCounted
## A designed room interior, compiled (v0.8.0 RT; RoomLayoutDefinition, RunContentCompiler.compile_room_layouts):
## whole centimetres and angles in 1/4096 turns, in the layout's own frame (+x along the room's long side). RoomLayouts
## turns, mirrors and places it.

var id := &""
## The room size it is drawn for (x >= y).
var cells := Vector2i(2, 2)
var weight := 1
var groups: Array[RoomLayoutGroupTable] = []
## Open lanes (per mille of the room in the layout's frame), for the tests' design checks.
var keep_clear: Array[Rect2i] = []
