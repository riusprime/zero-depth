class_name SpawnMixEntry
extends Resource
## One line of a spawn director's mix: an enemy, its weight, and the tier it starts appearing at. A new enemy kind
## joins the hordes with one more line (v0.4.0 SC).

@export var enemy_id: StringName
@export var weight := 1
@export var unlock_tier := 0
## How many arrive together (v0.4.0 SC + EN, one rule): 0 = the floor's draw (SpawnDirectorDefinition
## pack_min_by_floor .. pack_max_by_floor); > 0 = always that many (a Swarmer pack of 8). Never past the alive cap.
@export var pack := 0
