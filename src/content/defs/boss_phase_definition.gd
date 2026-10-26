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
## v0.9.5 BH4 (BOSSES_HARD.md T2, T3; BossStream): the Tidecaller's streams, which run beside the attack rotation. A
## ring stream: stream_attack (a `pattern` attack of the boss, not in attack_ids) fires one wave of its pattern every
## stream_every_seconds, each ring turned on from the last. A crossing wave: wave_attack (a `wave` attack) forms
## wave_count of them (from different walls) every wave_every_seconds. Empty / 0 = none.
@export var stream_attack: StringName
@export var stream_every_seconds := 0.0
@export var wave_attack: StringName
@export var wave_every_seconds := 0.0
@export var wave_count := 0
