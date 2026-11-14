class_name RoomPurposePart
extends Resource
## One part of a purpose room's group (v0.11.0 O15, RoomPurposeDefinition): a token the biome's palette turns into a
## kit piece (RoomPurposePalette), metres from its group's anchor before the group's yaw.

## The palette token (RoomPurposePiece.token), e.g. &"shelter" or &"seat".
@export var token := &""
## Its centre, metres from the group's anchor (before the group's yaw).
@export var at := Vector2.ZERO
## Its turn, degrees (counter-clockwise on the sim plane, before the group's yaw).
@export var yaw := 0.0
## Its drawn height as a multiple of the palette's (1.0: as the palette; a biome piece keeps the kit's own).
@export var height_scale := 1.0
## The seeded spread of that height (0..0.5: up to ±50 %).
@export var height_spread := 0.0
## 0: always. 1 or 2: one side of its group (the group draws which side, e.g. a shelter's lean-to left or right).
@export var side := 0
## The chance it is laid when its group is (per mille).
@export var chance_permille := 1000
