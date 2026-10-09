class_name CurseState
extends RefCounted
## v0.6.0 CU: what the trade-off curses keep in play (World.cs; Curses). Per floor (not carried); hashed once touched.

## Brittle: ticks of stun left, and the tick the last stun started (-1 = none).
var stun_t := 0
var stun_tick := -1
## Rooted: the tick of the last dodge (-1 = none) and dodges this floor.
var dodge_tick := -1
var dodges := 0
## Heavy Hands: Gun shots counted under it, and the tick of the last boosted hit (-1 = none).
var shots := 0
var heavy_tick := -1
## Blood Price: the tick a Skill or Blink last cost HP (-1 = none).
var blood_tick := -1


func touched() -> bool:
	return (
		stun_t != 0
		or stun_tick != -1
		or dodge_tick != -1
		or dodges != 0
		or shots != 0
		or heavy_tick != -1
		or blood_tick != -1
	)


func hash_into(h: StateHasher) -> void:
	for v in [stun_t, stun_tick, dodge_tick, dodges, shots, heavy_tick, blood_tick]:
		h.add_int(v)
