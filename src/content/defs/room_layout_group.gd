class_name RoomLayoutGroup
extends Resource
## A cluster of a designed room (v0.8.0 RT): pieces placed together around an anchor. The anchor is a fraction of the
## room (0..1 on each side of the layout's frame), so a group keeps its own shape in metres and the groups spread out
## with the room's size. The generator keeps a group whole or drops it whole (when a doorway, the start or the gate
## needs its place, or the room would split), so a cluster never loses half its pieces.

## Where the group sits: a fraction of the room along the layout's x (its long side) and y.
@export var anchor := Vector2(0.5, 0.5)
@export var pieces: Array[RoomLayoutPiece] = []
