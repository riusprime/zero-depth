class_name IntensityTable
extends RefCounted
## The intensity director's numbers (v0.8.0 N5; IntensityDirectorDefinition compiled by
## IntensityCompiler.compile) in ticks, metres and intensity × 1000 per tick ("milli", so the per-tick gains
## and drains stay integers). Loadout: it hangs on the floor's SpawnTable (SpawnTable.intensity; null = off, so a
## world without it spawns and hashes as before).

## Intensity's top, in milli (1000 × 1000).
const TOP := 1000000

var close_radius_m := 3.0
## Milli per whole max HP taken (2000 × 1000).
var hit_full_hp_gain := 2000000
var close_kill_gain := 25000
var close_gain_per_tick := 500
var drain_per_tick := 1000
var calm_ticks := 120
var peak_level := 750000
var peak_ticks_min := 180
var peak_ticks_max := 300
var pull_back_radius_m := 8.0
var pull_back_enemies := 2
var pull_back_max_ticks := 480
var quiet_ticks_min := 600
var quiet_ticks_max := 1200
var relax_level := 300000
var build_interval_permille := 1000
