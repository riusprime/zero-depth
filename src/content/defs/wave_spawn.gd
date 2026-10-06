class_name WaveSpawn
extends Resource
## One line of a wave: this many of this enemy, at spawn slots with this tag (CONTENT_SCHEMA §4).

@export var enemy_id: StringName
@export var count := 1
@export var spawn_slot_tag: StringName = &"edge"
