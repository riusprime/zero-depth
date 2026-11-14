class_name SurgeTable
extends RefCounted
## PLAN H1; owner Q15: the horde surges' numbers in ticks, compiled from SurgeDefinition
## (ContentCompiler.compile_surge) onto SpawnTable.surge. Loadout: never written in play (Surges).

var surges_min := 1
var surges_max := 2
var first_min_ticks := 2400
var first_max_ticks := 4800
var gap_min_ticks := 3600
var gap_max_ticks := 7200
var size_min := 30
var size_max := 60
var duration_ticks := 600
## Enemies alive a surge may bring the floor to (already at most the spawner's cap_max).
var alive_cap := 120
