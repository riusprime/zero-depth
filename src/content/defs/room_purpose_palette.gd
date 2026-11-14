class_name RoomPurposePalette
extends Resource
## A purpose room's pieces in one biome (v0.11.0 O15, RoomPurposeDefinition): every token its groups name.

## The biome (a BiomeDefinition id).
@export var biome := &""
@export var pieces: Array[RoomPurposePiece] = []


## The piece for `token`, or null.
func piece_for(token: StringName) -> RoomPurposePiece:
	for p in pieces:
		if p != null and p.token == token:
			return p
	return null
