class_name RoomPurposeGroup
extends Resource
## A cluster of a purpose room (v0.11.0 O15, RoomPurposeDefinition): parts laid together round an anchor and kept
## whole or dropped whole (a doorway's box, an item spot, the room's edge or its flow needs the place).

## Where the group sits, as a fraction of the room's half-size (-1..1; x along the room's long side, the centre 0).
@export var anchor := Vector2.ZERO
## Metres added to the anchor (a group a set distance from a wall: anchor 1, offset -3.4).
@export var offset := Vector2.ZERO
## Degrees the group's parts turn round the anchor (authored, so a shelter faces the fire).
@export var yaw := 0.0
## The purpose's focal piece: the room takes the purpose only where every focal group stands (the mirror is chosen to
## keep them clear of the doorways).
@export var focal := false
## The choice (RoomPurposeChoice.id) that decides whether it is laid, and the options of it that keep it. Empty: no
## choice (always, by its chance).
@export var choice := &""
@export var options := PackedInt32Array()
## The chance it is laid (per mille), after the choice.
@export var chance_permille := 1000
@export var parts: Array[RoomPurposePart] = []
