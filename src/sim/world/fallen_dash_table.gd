class_name FallenDashTable
extends RefCounted
## The Fallen's dash to a new spot between two moves in sim units (BossNemesis), compiled from
## FinalBossDefinition.reposition (FallenRules.REPOSITION_SPEC): its line shows dash_telegraph_ticks while it stands
## still, then it runs the line in dash_ticks; the line is dash_min_m to dash_max_m long and ends dash_wall_m from
## every wall.

var dash_telegraph_ticks := 24
var dash_ticks := 12
var dash_min_m := 6.0
var dash_max_m := 9.0
var dash_wall_m := 3.0
