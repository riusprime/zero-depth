class_name ShotFieldTable
extends RefCounted
## One kind of disc a boss lays that slows the hero's shots crossing it (BossShotFields), in sim units (ticks, m,
## per mille).

var radius_m := 1.75
## How long it stays (0 = until its fight ends).
var life_ticks := 480
## The share of its speed a shot inside keeps, per mille (1..1000).
var speed_permille := 200
## At most this many of one boss's lie at once: one more removes the oldest.
var max_count := 3
