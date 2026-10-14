class_name RoomLayoutPieceTable
extends RefCounted
## One piece: a sim blocker (solid) or a drawn-only piece.
## (v0.8.0 RT; was RoomLayoutTable.Piece, a global class so WorldSnapshot can classify it)

var piece := &""
## Its centre from the group's anchor, and its footprint (before its angle), in cm.
var at := Vector2i.ZERO
var size := Vector2i(100, 100)
## Its turn (1/4096; a solid's is 0), and its drawn height in cm (0: the kit's own).
var angle := 0
var height := 0
var solid := false
