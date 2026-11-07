class_name VariantState
extends RefCounted
## v0.11.0 O13a (ENEMIES.md V1-V5; Variants): what the biome variants leave on a floor, as parallel arrays.
## - Trails (the Ember and Frost Chargers' charges), in drop order: the kind (Variants.TRAIL_FIRE / TRAIL_SLICK), the
##   centre and radius, the tick it was dropped and the tick it goes, the ticks it waits before it burns (fire), its
##   number (fire: the burn's damage, already powered by its charger's tier; slick: the hero's easing per mille a tick),
##   the burn's period (fire) and the id of the charger that dropped it. `burn_next`: the first tick the hero may burn
##   again (one burn per period, however many patches overlap).
## - Rubble (the Rubble Warden's crust): each piece's centre and half side; each is also a wall while it stands
##   (World.add_barrier: collision, shots, sight, never the flow field), for the floor. `crusted`: the ids of the
##   Rubble Wardens whose crust already fell.
## World hashes it only once anything was ever dropped (touched), so worlds without the variants hash as before.

const INT_FIELDS: Array[StringName] = [
	&"trail_kind",
	&"trail_born",
	&"trail_until",
	&"trail_arm",
	&"trail_value",
	&"trail_period",
	&"trail_owner",
]
const FLOAT_FIELDS: Array[StringName] = [&"trail_x", &"trail_y", &"trail_r"]

var trail_kind := PackedInt32Array()
var trail_born := PackedInt32Array()
var trail_until := PackedInt32Array()
var trail_arm := PackedInt32Array()
var trail_value := PackedInt32Array()
var trail_period := PackedInt32Array()
var trail_owner := PackedInt32Array()
var trail_x := PackedFloat32Array()
var trail_y := PackedFloat32Array()
var trail_r := PackedFloat32Array()
var burn_next := 0
var rubble_x := PackedFloat32Array()
var rubble_y := PackedFloat32Array()
var rubble_half := PackedFloat32Array()
var crusted := PackedInt32Array()
var touched := false


func trail_count() -> int:
	return trail_kind.size()


func trail_pos(k: int) -> Vector2:
	return Vector2(trail_x[k], trail_y[k])


func rubble_count() -> int:
	return rubble_x.size()


## Rubble piece k as the wall it is (centre, half side, unturned).
func rubble_obb(k: int) -> Obb:
	return Obb.make(Vector2(rubble_x[k], rubble_y[k]), Vector2(rubble_half[k], rubble_half[k]), 0)


func add_trail(
	kind: int,
	at: Vector2,
	r: float,
	born: int,
	until: int,
	arm: int,
	value: int,
	period: int,
	owner_id: int
) -> void:
	touched = true
	trail_kind.append(kind)
	trail_x.append(at.x)
	trail_y.append(at.y)
	trail_r.append(r)
	trail_born.append(born)
	trail_until.append(until)
	trail_arm.append(arm)
	trail_value.append(value)
	trail_period.append(period)
	trail_owner.append(owner_id)


## Removes the trails at the given ascending indices, keeping order.
func remove_trails(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			ai.remove_at(indices[k])
		set(f, ai)
	for f in FLOAT_FIELDS:
		var af: PackedFloat32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			af.remove_at(indices[k])
		set(f, af)


func add_rubble(at: Vector2, half: float) -> void:
	touched = true
	rubble_x.append(at.x)
	rubble_y.append(at.y)
	rubble_half.append(half)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
	h.add_int(burn_next)
	h.add_f32s(rubble_x)
	h.add_f32s(rubble_y)
	h.add_f32s(rubble_half)
	h.add_ints(crusted)
