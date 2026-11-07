class_name RuinsRocksState
extends RefCounted
## v0.11.0 O13b (ENEMIES.md R1-R4; RuinsRocks): what the Ruins' and the Night Rocks' signature enemies leave on a floor,
## as parallel arrays.
## - Cables (the Wire Weavers'), in planting order: the ids of its two posts (the cable runs between them where they
##   stand), the Weaver's id, the tick it went live, its touch's damage (already powered by its Weaver's tier), its
##   half thickness and its period. `cable_next`: the first tick a cable may hurt the hero again (one touch a period,
##   however many cables it touches).
## - Rocks (the Stone Throwers' thrown rocks), in landing order: the centre, the half side, the tick it goes and the
##   Thrower's id; each is also a wall while it stands (World.add_barrier: collision, shots, sight, never the flow
##   field).
## - Hides (the Rock Lurkers still waiting): the Lurker's id and its boulder's centre and half side, a wall while it
##   waits (as a rock); the Lurker's body inside it passes through its own wall (World: RuinsRocks.hidden).
## World hashes it only once anything was ever placed (touched), so worlds without these enemies hash as before.

const INT_FIELDS: Array[StringName] = [
	&"cable_a",
	&"cable_b",
	&"cable_owner",
	&"cable_born",
	&"cable_damage",
	&"cable_period",
	&"rock_until",
	&"rock_owner",
	&"hide_id",
]
const FLOAT_FIELDS: Array[StringName] = [
	&"cable_half", &"rock_x", &"rock_y", &"rock_half", &"hide_x", &"hide_y", &"hide_half"
]

var cable_a := PackedInt32Array()
var cable_b := PackedInt32Array()
var cable_owner := PackedInt32Array()
var cable_born := PackedInt32Array()
var cable_damage := PackedInt32Array()
var cable_period := PackedInt32Array()
var cable_half := PackedFloat32Array()
var cable_next := 0
var rock_x := PackedFloat32Array()
var rock_y := PackedFloat32Array()
var rock_half := PackedFloat32Array()
var rock_until := PackedInt32Array()
var rock_owner := PackedInt32Array()
var hide_id := PackedInt32Array()
var hide_x := PackedFloat32Array()
var hide_y := PackedFloat32Array()
var hide_half := PackedFloat32Array()
var touched := false


func cable_count() -> int:
	return cable_a.size()


func rock_count() -> int:
	return rock_x.size()


func hide_count() -> int:
	return hide_id.size()


## Rock k as the wall it is (centre, half side, unturned).
func rock_obb(k: int) -> Obb:
	return Obb.make(Vector2(rock_x[k], rock_y[k]), Vector2(rock_half[k], rock_half[k]), 0)


## Hide k as the wall it is.
func hide_obb(k: int) -> Obb:
	return Obb.make(Vector2(hide_x[k], hide_y[k]), Vector2(hide_half[k], hide_half[k]), 0)


## The hide of Lurker `id`, or -1.
func hide_of(id: int) -> int:
	for k in hide_id.size():
		if hide_id[k] == id:
			return k
	return -1


## Cables the Weaver `id` keeps.
func cables_of(id: int) -> int:
	var n := 0
	for k in cable_owner.size():
		if cable_owner[k] == id:
			n += 1
	return n


func add_cable(
	a_id: int, b_id: int, owner_id: int, born: int, damage: int, period: int, half: float
) -> void:
	touched = true
	cable_a.append(a_id)
	cable_b.append(b_id)
	cable_owner.append(owner_id)
	cable_born.append(born)
	cable_damage.append(damage)
	cable_period.append(period)
	cable_half.append(half)


func remove_cable(k: int) -> void:
	for f: StringName in [
		&"cable_a", &"cable_b", &"cable_owner", &"cable_born", &"cable_damage", &"cable_period"
	]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)
	cable_half.remove_at(k)


func add_rock(at: Vector2, half: float, until: int, owner_id: int) -> void:
	touched = true
	rock_x.append(at.x)
	rock_y.append(at.y)
	rock_half.append(half)
	rock_until.append(until)
	rock_owner.append(owner_id)


func remove_rock(k: int) -> void:
	rock_x.remove_at(k)
	rock_y.remove_at(k)
	rock_half.remove_at(k)
	rock_until.remove_at(k)
	rock_owner.remove_at(k)


func add_hide(id: int, at: Vector2, half: float) -> void:
	touched = true
	hide_id.append(id)
	hide_x.append(at.x)
	hide_y.append(at.y)
	hide_half.append(half)


func remove_hide(k: int) -> void:
	hide_id.remove_at(k)
	hide_x.remove_at(k)
	hide_y.remove_at(k)
	hide_half.remove_at(k)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
	h.add_int(cable_next)
