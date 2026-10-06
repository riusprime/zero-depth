class_name ActorStore
extends RefCounted
## Actors as parallel arrays in ascending id order (SIM_CONTRACTS §4). Index 0 is always the player.

enum Kind { PLAYER, DUMMY }

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var ids := PackedInt32Array()
var kinds := PackedInt32Array()
var teams := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var radius := PackedFloat32Array()
var hp := PackedInt32Array()
## Dummy AI: ticks until the next shot, and the target offset picked by the heavy pass.
var fire_cd := PackedInt32Array()
var jitter_x := PackedFloat32Array()
var jitter_y := PackedFloat32Array()


func size() -> int:
	return ids.size()


func add(id: int, kind: int, team: int, p: Vector2, r: float, p_hp: int, p_fire_cd: int) -> void:
	ids.append(id)
	kinds.append(kind)
	teams.append(team)
	pos_x.append(p.x)
	pos_y.append(p.y)
	radius.append(r)
	hp.append(p_hp)
	fire_cd.append(p_fire_cd)
	jitter_x.append(0.0)
	jitter_y.append(0.0)


func pos(i: int) -> Vector2:
	return Vector2(pos_x[i], pos_y[i])


func set_pos(i: int, p: Vector2) -> void:
	pos_x[i] = p.x
	pos_y[i] = p.y


func hash_into(h: StateHasher) -> void:
	h.add_ints(ids)
	h.add_ints(kinds)
	h.add_ints(teams)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)
	h.add_f32s(radius)
	h.add_ints(hp)
	h.add_ints(fire_cd)
	h.add_f32s(jitter_x)
	h.add_f32s(jitter_y)
