class_name EliteTable
extends RefCounted
## v0.9.0 EL (ELITES.md E1-E3): one elite archetype's ability and plain attack in sim units (ContentCompiler.
## compile_elite from EliteDefinition; EnemyTable.elite holds it, the rest of an elite's numbers are its EnemyTable's).
## Content: read in play, never written (WorldSnapshot keeps it as loadout). RunState.scale_enemies scales its damages
## with the floor (scale_damage), as an enemy table's.

var contact_damage := 0
var contact_cd_ticks := 60
## The ability: start to start, its windup, the windup's tracked head and vanished tail, the hit, its shape, the
## recovery (the punish window) and the damage taken meanwhile (per mille).
var every_ticks := 360
var windup_ticks := 60
var track_ticks := 0
var vanish_ticks := 0
var damage := 32
var radius_m := 3.0
var half_width_m := 0.0
var range_m := 0.0
var recover_ticks := 90
var vulnerable_permille := 1000
## The plain attack (basic_damage 0: none): start to start, windup, recovery, reach past the body, its pattern.
var basic_damage := 0
var basic_every_ticks := 90
var basic_windup_ticks := 48
var basic_recover_ticks := 30
var basic_range_m := 0.0
var basic_pattern: BulletPatternTable


## Scales every damage by `permille` (the floor's enemy damage factor; SpawnTable.scale's rounding).
func scale_damage(permille: int) -> void:
	contact_damage = SpawnTable.scale(contact_damage, permille)
	damage = SpawnTable.scale(damage, permille)
	basic_damage = SpawnTable.scale(basic_damage, permille)
