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
# --- v0.4.0 AB (ElementAbilities, AbilityCombos). Hashed after the fields above, once any leaves its default. ---
## Arc Field: the last strike (tick, from, where each bolt hit) and whether Superconductor raised it.
var arc_tick := -1
var arc_from := Vector2.ZERO
var arc_to := PackedVector2Array()
var arc_super := 0
## Frost Nova: the last nova (tick, centre, radius).
var nova_tick := -1
var nova_pos := Vector2.ZERO
var nova_r := 0.0
## Fire patches (Flame Trail, Napalm Drone): centre, radius, the tick it goes out, damage per hit, burn stacks per
## hit, and its kind (FIRE_TRAIL / FIRE_NAPALM). Oldest first.
var fire_pos := PackedVector2Array()
var fire_r := PackedFloat32Array()
var fire_end := PackedInt32Array()
var fire_dmg := PackedInt32Array()
var fire_stacks := PackedInt32Array()
var fire_kind := PackedInt32Array()
## Enemies the fire hit lately (ids, the first tick they may be hit again), and where the last trail patch fell
## (trail_tick -1 = none on this floor yet).
var fire_ids := PackedInt32Array()
var fire_next := PackedInt32Array()
var trail_tick := -1
var trail_at := Vector2.ZERO
## Storm Bombs: the last chain (tick, the blast centre, where each bolt hit).
var storm_tick := -1
var storm_from := Vector2.ZERO
var storm_to := PackedVector2Array()
## Blade Dance: the tick the dance ends; Wingman: the first tick of the next volley and the last one; Ember Ward:
## the first tick it may burst again and the last burst (tick, centre, radius); Blink Charge and Glacier Ring: the
## last tick they fired.
var dance_until := 0
var wing_next := 0
var wing_tick := -1
var ward_next := 0
var ward_tick := -1
var ward_pos := Vector2.ZERO
var ward_r := 0.0
var charge_tick := -1
var charge_pos := Vector2.ZERO
var glacier_tick := -1


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
		or touched_ab()
	)


## Any v0.4.0 AB field away from its default.
func touched_ab() -> bool:
	return (
		arc_tick != -1
		or nova_tick != -1
		or not fire_pos.is_empty()
		or not fire_ids.is_empty()
		or trail_tick != -1
		or storm_tick != -1
		or dance_until != 0
		or wing_next != 0
		or ward_next != 0
		or charge_tick != -1
		or glacier_tick != -1
	)


func hash_into(h: StateHasher) -> void:
	h.add_ints(cd)
	for v in [blink_charges, shock_pending, shock_tick, chain_tick, orbit_angle, orbit_hit_tick]:
		h.add_int(v)
	for v in [regen_acc, regen_tick]:
		h.add_int(v)
	for p: Vector2 in [shock_pos, chain_from, chain_to]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32(shock_r)
	for arr: PackedVector2Array in [drone_pos, bomb_pos, bomb_from, blast_pos]:
		h.add_int(arr.size())
		for p in arr:
			h.add_f32(p.x)
			h.add_f32(p.y)
	for arr: PackedInt32Array in [
		drone_cd, drone_fire, bomb_throw, bomb_land, bomb_root, bomb_dmg, blast_tick
	]:
		h.add_ints(arr)
	h.add_f32s(bomb_r)
	h.add_f32s(blast_r)
	h.add_ints(orbit_ids)
	h.add_ints(orbit_next)
	if not touched_ab():
		return
	for v in [arc_tick, arc_super, nova_tick, trail_tick, storm_tick, dance_until, wing_next]:
		h.add_int(v)
	for v in [wing_tick, ward_next, ward_tick, charge_tick, glacier_tick]:
		h.add_int(v)
	for p: Vector2 in [arc_from, nova_pos, trail_at, storm_from, ward_pos, charge_pos]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32(nova_r)
	h.add_f32(ward_r)
	for arr: PackedVector2Array in [arc_to, fire_pos, storm_to]:
		h.add_int(arr.size())
		for p in arr:
			h.add_f32(p.x)
			h.add_f32(p.y)
	h.add_f32s(fire_r)
	for arr: PackedInt32Array in [fire_end, fire_dmg, fire_stacks, fire_kind, fire_ids, fire_next]:
		h.add_ints(arr)
