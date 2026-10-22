class_name IntensityState
extends RefCounted
## The intensity director's state on the floor (v0.8.0 N5; Intensity): the hidden intensity in milli (0..1000000),
## the state, its timer (in QUIET it runs past 0 into the negative: the overtime), the quiet length drawn at the
## peak, the cycle count (the stream's name), the calm ticks, the hero's HP last tick and the tick it was last read.
## A fresh one is BUILD_UP (a floor's start, and an older save). Hashed only when the floor's spawner has the director
## (SpawnTable.intensity), so older worlds keep their hashes.

enum Mode { BUILD_UP, PEAK, PULL_BACK, QUIET }

var level := 0
var mode := Mode.BUILD_UP
var timer := 0
var quiet_len := 0
var cycle := 0
var calm := 0
var last_hp := -1
var seen_tick := -1


func hash_into(h: StateHasher) -> void:
	for v in [level, mode, timer, quiet_len, cycle, calm, last_hp, seen_tick]:
		h.add_int(v)
