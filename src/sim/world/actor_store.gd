class_name ActorStore
extends RefCounted
## Actors as parallel arrays in ascending id order (SIM_CONTRACTS §4). Index 0 is always the player.
## Kinds are appended, never renumbered, because they are hashed.

enum Kind { PLAYER, DUMMY, CHARGER, WARDEN, NEEDLE }

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const INT_FIELDS: Array[StringName] = [
	&"ids",
	&"kinds",
	&"teams",
	&"hp",
	&"max_hp",
	&"invuln",
	&"dead",
	&"state",
	&"state_t",
	&"facing",
	&"lock_a",
	&"cd",
	&"fire_cd",
	&"burn_stacks",
	&"burn_t",
	&"burn_cd",
	&"burn_root",
]
const FLOAT_FIELDS: Array[StringName] = [
	&"pos_x", &"pos_y", &"radius", &"lock_x", &"lock_y", &"lock_len", &"jitter_x", &"jitter_y"
]

var ids := PackedInt32Array()
var kinds := PackedInt32Array()
var teams := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var radius := PackedFloat32Array()
var hp := PackedInt32Array()
var max_hp := PackedInt32Array()
## Ticks of invulnerability left (after a hit, a spawn-in, a blink).
var invuln := PackedInt32Array()
## 1 once a KILL was emitted; dead actors leave the store in tick phase 9 (the player stays, dead).
var dead := PackedInt32Array()
## Behaviour state machine (EnemyAi): the state, ticks spent in it, facing, a locked point and angle, a cooldown.
var state := PackedInt32Array()
var state_t := PackedInt32Array()
var facing := PackedInt32Array()
var lock_x := PackedFloat32Array()
var lock_y := PackedFloat32Array()
var lock_a := PackedInt32Array()
## A locked length (a charge's lane, a burst's line), cut short by walls.
var lock_len := PackedFloat32Array()
var cd := PackedInt32Array()
## Dummy AI: ticks until the next shot, and the target offset picked by the heavy pass.
var fire_cd := PackedInt32Array()
var jitter_x := PackedFloat32Array()
var jitter_y := PackedFloat32Array()
## Ember Edge burn (v0.2.0 items): stacks, ticks until it runs out, ticks to the next DoT tick, and the root that
## last added a stack (one stack per root chain).
var burn_stacks := PackedInt32Array()
var burn_t := PackedInt32Array()
var burn_cd := PackedInt32Array()
var burn_root := PackedInt32Array()


func size() -> int:
	return ids.size()


func add(id: int, kind: int, team: int, p: Vector2, r: float, p_hp: int, p_fire_cd: int) -> int:
	# Packed arrays are values: get() returns a copy, so append to it and set it back.
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.append(0)
		set(f, ai)
	for f in FLOAT_FIELDS:
		var af: PackedFloat32Array = get(f)
		af.append(0.0)
		set(f, af)
	var i := ids.size() - 1
	ids[i] = id
	kinds[i] = kind
	teams[i] = team
	pos_x[i] = p.x
	pos_y[i] = p.y
	radius[i] = r
	hp[i] = p_hp
	max_hp[i] = p_hp
	fire_cd[i] = p_fire_cd
	return i


func pos(i: int) -> Vector2:
	return Vector2(pos_x[i], pos_y[i])


func set_pos(i: int, p: Vector2) -> void:
	pos_x[i] = p.x
	pos_y[i] = p.y


func index_of(id: int) -> int:
	return ids.bsearch(id) if ids.has(id) else -1


## Removes the entries at the given ascending indices, keeping order.
func remove_sorted(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	var keep := PackedInt32Array()
	var j := 0
	for i in ids.size():
		if j < indices.size() and indices[j] == i:
			j += 1
		else:
			keep.append(i)
	for f in INT_FIELDS:
		set(f, ProjectileStore._pick_i(get(f), keep))
	for f in FLOAT_FIELDS:
		set(f, ProjectileStore._pick_f(get(f), keep))


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))
