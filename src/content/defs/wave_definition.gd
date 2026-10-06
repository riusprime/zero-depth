class_name WaveDefinition
extends Resource
## One wave: its spawns, and how long after the previous wave is cleared it arrives (CONTENT_SCHEMA §4).

@export var spawns: Array[WaveSpawn] = []
@export var delay_seconds := 1.0
