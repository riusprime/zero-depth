class_name IntensityState
extends RefCounted
## The intensity director's state on the floor (v0.8.0 N5; Intensity): the hidden intensity in milli (0..1000000),
## the state, its timer, the quiet length (drawn at the peak; × struggle_quiet_permille when the quiet
## begins with the hero struggling), the cycle count (the stream's name), the calm ticks, the hero's HP last tick and
## the tick it was last read. A fresh one is BUILD_UP (a floor's start, and an older save). Hashed only when the
## floor's spawner has the director (SpawnTable.intensity), so older worlds keep their hashes.
## The hero's live state. kill_ring holds the kills of each of the last KILL_SLOTS seconds of
## fighting (the director's ticks outside QUIET; ring_ticks counts them), kill_seen is World.kills when last read, and
## standing the hero's reading this tick (Standing). An older save has none of them (WorldSnapshot.ADDED_SINCE_V05):
## an empty ring, so the kill rate is read again once a full window has been counted.

enum Mode { BUILD_UP, PEAK, PULL_BACK, QUIET }
## How the hero is doing (Intensity.read_standing).
enum Standing { BETWEEN, STRUGGLING, STRONG }

## The kill window, in one-second slots (~10 s).
const KILL_SLOTS := 10

var level := 0
var mode := Mode.BUILD_UP
var timer := 0
var quiet_len := 0
var cycle := 0
var calm := 0
var last_hp := -1
var seen_tick := -1
var kill_ring := PackedInt32Array()
var kill_seen := 0
var ring_ticks := 0
var standing := Standing.BETWEEN


func hash_into(h: StateHasher) -> void:
	for v in [
		level,
		mode,
		timer,
		quiet_len,
		cycle,
		calm,
		last_hp,
		seen_tick,
		kill_seen,
		ring_ticks,
		standing
	]:
		h.add_int(v)
	h.add_ints(kill_ring)


## The kills in the window (the ring's sum).
func window_kills() -> int:
	var n := 0
	for v in kill_ring:
		n += v
	return n
