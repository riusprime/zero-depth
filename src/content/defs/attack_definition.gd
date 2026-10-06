class_name AttackDefinition
extends Resource
## One enemy attack (CONTENT_SCHEMA §3). The windup (telegraph_seconds) is what the player sees; it must compile to
## at least SimTick.MIN_TELEGRAPH_TICKS.

enum Shape { CIRCLE, CONE, LINE, RING, PROJECTILE }

@export var id: StringName
@export var shape := Shape.CIRCLE
## Checked against the behaviour's schema (src/sim/ai/behaviour_schemas.gd).
@export var shape_params := {}
@export var telegraph_seconds := 0.5
@export var active_seconds := 1.0 / 60.0
@export var recovery_seconds := 0.5
@export var damage := 10
@export var proc_pct := 100
@export var hitstop_ticks := 0
