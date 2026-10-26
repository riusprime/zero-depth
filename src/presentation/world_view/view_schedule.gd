class_name ViewSchedule
extends RefCounted
## v0.9.5 PF4 (owner: "Effects update every other tick"): the purely decorative views that sync at 30 Hz, each on a
## fixed tick parity (view id -> 0 even, 1 odd), so the load is split. A view not listed syncs every tick. Never list
## anything that shows a telegraph, a hitbox, a projectile, HP or anything the player dodges by.
## - status_fx: the burn / frost / poison particles, rings and pips that ride an enemy's own node (the node moves every
##   tick; its animation clock counts ticks, not syncs).
## - modifier_marks: the hero's own shell / charge / phase auras and the poison-drop and queued marks (the player's
##   own cards: nothing an enemy does and nothing to dodge).
## Presentation only (EI-07).

const HALF_RATE := {&"status_fx": 0, &"modifier_marks": 1}


## Whether view `id` syncs on `tick`; a half-rate view's first sync (`seen` has no `id`) always runs.
static func due(id: StringName, tick: int, seen: Dictionary) -> bool:
	if not HALF_RATE.has(id):
		return true
	if not seen.has(id):
		seen[id] = true
		return true
	return tick % 2 == int(HALF_RATE[id])
