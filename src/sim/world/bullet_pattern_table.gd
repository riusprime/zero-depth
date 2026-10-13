class_name BulletPatternTable
extends RefCounted
## v0.7.5 BF1: one bullet pattern in sim units (BulletPatternDefinition compiled by PatternCompiler.compile_pattern):
## metres, metres per tick, ticks, 1/4096 turns (and 1/4096 turns per tick for the spin), per mille. Only the fields
## its kind uses are read. BulletPatterns fires it.

enum Kind { RING, SPIRAL, FAN, CROSS, WALL, FLOWER, BURST }

var id := &""
var kind := Kind.RING
var look := &""
var speed := 0.0
var radius_m := 0.18
var life_ticks := 1
var waves := 1
var wave_gap_ticks := 1
var turn_per_wave := 0
var alternate := false
var aim_offset := 0
var safe_radius_m := 1.4
var count := 1
var gap_count := 0
var gap_width := 0
var spread := 0
var arms := 1
## The turn in 1/4096 turns per tick ×1000 (milli-units), so slow spins keep their fraction.
var spin_milli := 0
var reverse_ticks := 0
var wall_length_m := 0.0
var spacing_m := 0.6
var gap_m := 0.0
var gap_offset_m := 0.0
var gap_shift_m := 0.0
var crossing := false
var petals := 5
var petal_min_permille := 450
var petal_cut_permille := 300
var lob_ticks := 0
var land_radius_m := 0.0


## Ticks from the pattern's start to its last shot (inclusive), plus one: the attack's active time.
func duration_ticks() -> int:
	return lob_ticks + wave_gap_ticks * (waves - 1) + 1
