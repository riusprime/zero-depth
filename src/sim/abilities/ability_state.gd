class_name AbilityState
extends RefCounted
## The abilities' per-floor state (v0.4.0 BS; World.ab): cooldowns, drones, bombs in flight, the orbit, the blink
## charges, and the last of each effect for the views. A new floor starts it fresh (Abilities.start_floor); what a
## run keeps (the slots, levels and stat values) lives on World and travels with RunCarry. Hashed by
## Abilities.hash_into once touched.

## Ticks until each owned slot (World.ability_owned order) may fire again.
var cd := PackedInt32Array()
## Blink: charges ready now.
var blink_charges := 0
## Blink: a landing shock waiting for phase 6 (-1 = none) and the last shock (tick, where, radius) for the view.
var shock_pending := -1
var shock_tick := -1
var shock_pos := Vector2.ZERO
var shock_r := 0.0
## Drone Buddy: each drone's position, ticks to its next shot and the tick it last fired.
var drone_pos := PackedVector2Array()
var drone_cd := PackedInt32Array()
var drone_fire := PackedInt32Array()
## Drone Buddy L5: the last chain (tick, from, to).
var chain_tick := -1
var chain_from := Vector2.ZERO
var chain_to := Vector2.ZERO
## Bomb Lobber: bombs in flight (where they land, where they left, the throw and landing ticks, root, radius,
## damage).
var bomb_pos := PackedVector2Array()
var bomb_from := PackedVector2Array()
var bomb_throw := PackedInt32Array()
var bomb_land := PackedInt32Array()
var bomb_root := PackedInt32Array()
var bomb_r := PackedFloat32Array()
var bomb_dmg := PackedInt32Array()
## v0.5.0 CP: 1 = a thrown bomb (Cluster Payload splits it on landing), 0 = a bomblet.
var bomb_split := PackedInt32Array()
## v0.5.0 CP, Afterimage: the echo a blink leaves (where, the tick it bursts, -1 = none) and the last burst (tick,
## where, radius) for the view.
var echo_pos := Vector2.ZERO
var echo_at := -1
var echo_tick := -1
var echo_burst_pos := Vector2.ZERO
var echo_r := 0.0
## The last BLAST_LOG landings (where, tick, radius), oldest first.
var blast_pos := PackedVector2Array()
var blast_tick := PackedInt32Array()
var blast_r := PackedFloat32Array()
## Orbit Blades: the ring's angle (1/4096 turns), and enemies hit lately (ids, first tick they may be hit again).
var orbit_angle := 0
var orbit_ids := PackedInt32Array()
var orbit_next := PackedInt32Array()
var orbit_hit_tick := -1
## Stat regen (Stats.advance_regen): the accumulator and the last tick it healed.
var regen_acc := 0
var regen_tick := -1


func touched() -> bool:
	return (
		not cd.is_empty()
		or blink_charges != 0
		or shock_tick != -1
		or not drone_pos.is_empty()
		or not bomb_pos.is_empty()
		or not blast_tick.is_empty()
		or not orbit_ids.is_empty()
		or regen_acc != 0
		or regen_tick != -1
		or echo_at != -1
		or echo_tick != -1
	)


func hash_into(h: StateHasher) -> void:
	h.add_ints(cd)
	for v in [blink_charges, shock_pending, shock_tick, chain_tick, orbit_angle, orbit_hit_tick]:
		h.add_int(v)
	for v in [regen_acc, regen_tick, echo_at, echo_tick]:
		h.add_int(v)
	for p: Vector2 in [shock_pos, chain_from, chain_to, echo_pos, echo_burst_pos]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32(shock_r)
	h.add_f32(echo_r)
	for arr: PackedVector2Array in [drone_pos, bomb_pos, bomb_from, blast_pos]:
		h.add_int(arr.size())
		for p in arr:
			h.add_f32(p.x)
			h.add_f32(p.y)
	for arr: PackedInt32Array in [
		drone_cd, drone_fire, bomb_throw, bomb_land, bomb_root, bomb_dmg, bomb_split, blast_tick
	]:
		h.add_ints(arr)
	h.add_f32s(bomb_r)
	h.add_f32s(blast_r)
	h.add_ints(orbit_ids)
	h.add_ints(orbit_next)
