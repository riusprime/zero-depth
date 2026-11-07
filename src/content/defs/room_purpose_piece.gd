class_name RoomPurposePiece
extends Resource
## What a biome draws for one token of a purpose room (v0.11.0 O15, RoomPurposePalette). Until the owner's purpose-room
## models arrive (OWNER_TODO §3.6) the pieces are kit stand-ins; a new model swaps in by changing `piece` here.

@export var token := &""
## The kit piece (RoomPurposeDefinition.PIECES).
@export var piece := &""
## Its footprint (m; x along the part's yaw).
@export var size := Vector2.ONE
## Its drawn height (m; 0 keeps the kit's own; a biome piece always keeps its own).
@export var height := 0.0
## A drawn piece resting on its group's solids (a lintel across two standing stones): its base this high (m, 0 on the
## ground). Only a drawn piece; 0 for a solid.
@export var lift := 0.0
## True: a sim blocker (its turned footprint is a wall). False: drawn only, a low decoration piece.
@export var solid := true
