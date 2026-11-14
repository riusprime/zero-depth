class_name RoomPurposeChoice
extends Resource
## A seeded choice of a purpose room (v0.11.0 O15, RoomPurposeDefinition): one option is drawn per room by weight, and
## the groups naming it are laid only under their options (which shelter slot stays empty, a column standing, broken
## or fallen, the cart's side).

@export var id := &""
## One weight per option (option k is index k).
@export var weights := PackedInt32Array([1, 1])
