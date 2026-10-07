class_name BossPhaseDefinition
extends Resource
## One boss phase (CONTENT_SCHEMA §4): it starts when HP falls to hp_threshold_permille of max (the first is 1000)
## and picks from its attacks. entry_attack (optional) is performed once, first, when the phase starts.

@export var hp_threshold_permille := 1000
@export var attack_ids := PackedStringArray()
@export var entry_attack: StringName
## Pursuit speed and the pause between attacks, per mille of the boss's (0 speed = planted).
@export var speed_permille := 1000
@export var cooldown_permille := 1000
