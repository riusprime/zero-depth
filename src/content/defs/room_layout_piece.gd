class_name RoomLayoutPiece
extends Resource
## One piece of a designed room's group (v0.8.0 RT, owner O12; CONTENT_SCHEMA §5 "Designed rooms"), in metres from
## its group's anchor in the layout's own frame (+x along the room's long side). A solid piece is a sim blocker: its
## footprint (`at` ± `size` / 2, axis-aligned) is a wall the player and enemies can't cross, drawn with `piece` at the
## kit's height (or `height`). A piece that isn't solid is drawn only (presentation): decoration (grass, rubble,
## debris) anywhere in the room, or a taller piece standing inside one of its group's solid footprints, never on open
## floor ("looks solid = is solid", StageDresser rule 1).

## The kit piece that draws it (RoomLayoutDefinition.KIT).
@export var piece: StringName
## Its centre, metres from the group's anchor.
@export var at := Vector2.ZERO
## Its footprint, metres (x along the layout's x before the piece's yaw).
@export var size := Vector2.ONE
## A drawn piece's turn, degrees (counter-clockwise on the sim plane). A solid piece is never turned: it fills its
## footprint.
@export var yaw := 0.0
## Its drawn height in metres; 0 keeps the kit's own height.
@export var height := 0.0
## True: a sim blocker. False: drawn only.
@export var solid := false
