class_name DifficultyPhase
extends Resource
## One phase of a floor's difficulty curve (v0.4.0 TU, owner D1–D3; DifficultyCurveDefinition). Starting values the
## owner tunes after playing.

## When the phase begins, in seconds of floor time (the first phase at 0).
@export var start_seconds := 0.0
## The HUD's name for it (a locale key with en and es).
@export var name_key: StringName
## The danger tier at the phase's start, × 1000 (HP, damage and shards scale by it; SC's per-tier tables).
@export var tier_permille := 0
## The alive cap and the spawn interval, per mille of SC's values at the current tier (under 1000: fewer; over
## 1000: slower spawns).
@export var cap_permille := 1000
@export var interval_permille := 1000
## Enemy max HP and damage, per mille of SC's values at the current tier (≤ 1000: the curve only eases toward the
## peak, where both are 1000).
@export var hp_permille := 1000
@export var damage_permille := 1000
## The largest pack in this phase (0 = no limit: a Swarmer pack of 8).
@export var pack_cap := 0
## True: the phase keeps its values to its end (the calm minute). False: they ramp linearly to the next phase's.
@export var hold := false
## Enemy ids (the spawn mix's) that start appearing in this phase; earlier phases' kinds stay.
@export var kinds: Array[StringName] = []
