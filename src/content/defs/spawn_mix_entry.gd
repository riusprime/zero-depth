class_name SpawnMixEntry
extends Resource
## One line of a spawn director's mix: an enemy, its weight, and the tier it starts appearing at. A new enemy kind
## joins the hordes with one more line (v0.4.0 SC).

@export var enemy_id: StringName
@export var weight := 1
@export var unlock_tier := 0
## v0.4.0 SC: a fixed pack size for this enemy (a swarm of 8, say); 0 = the director's per-floor draw.
@export var pack_size := 0
