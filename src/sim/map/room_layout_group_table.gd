class_name RoomLayoutGroupTable
extends RefCounted
## A cluster around an anchor (a fraction of the room, per mille of each side of the layout's frame).
## (v0.8.0 RT; was RoomLayoutTable.Group, a global class so WorldSnapshot can classify it)

var anchor := Vector2i(500, 500)
var pieces: Array[RoomLayoutPieceTable] = []
