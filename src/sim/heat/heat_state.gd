class_name HeatState
extends RefCounted
## The player's overclock heat (World.heat; null when the loadout has no heat, so those worlds hash as before).
## Every field but the table is hashed (hash_into). Heat runs it; views read it through WorldReader.heat_state.

## The compiled numbers (part of the loadout, like the item tables; not hashed).
var table: HeatTable
## Heat in milli-points, 0..table.max_milli().
var milli := 0
## Ticks since the last landed attack added heat (the decay waits table.decay_delay_ticks).
var idle := 0
## Overheat: ticks of the stall left (0 = not stalled), and its full length.
var stall := 0
var stall_total := 0
## The root of the last attack that added heat (a swing adds once however many enemies it hits).
var last_root := 0
## Heat.TIER_* now, and the tick it last changed (the meter flashes on it).
var tier := 0
var tier_tick := -1
## The last overheat (tick; meltdown = it blew up instead of stalling), vent (tick, where, heat vented, radius) and
## Overclock ember (tick, where), for the views.
var overheat_tick := -1
var meltdown := false
var vent_tick := -1
var vent_pos := Vector2.ZERO
var vent_heat := 0
var vent_radius := 0.0
var ember_tick := -1
var ember_pos := Vector2.ZERO


func _init(p_table: HeatTable) -> void:
	table = p_table


func hash_into(h: StateHasher) -> void:
	for v in [milli, idle, stall, stall_total, last_root, tier, tier_tick, overheat_tick]:
		h.add_int(v)
	for v in [1 if meltdown else 0, vent_tick, vent_heat, ember_tick]:
		h.add_int(v)
	for v in [vent_pos.x, vent_pos.y, vent_radius, ember_pos.x, ember_pos.y]:
		h.add_f32(v)
