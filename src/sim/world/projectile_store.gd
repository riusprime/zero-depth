class_name ProjectileStore
extends RefCounted
## Projectiles as structure-of-arrays in ascending id order. Each carries its provenance.

var ids := PackedInt32Array()
var owner := PackedInt32Array()
var team := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var vel_x := PackedFloat32Array()
var vel_y := PackedFloat32Array()
var radius := PackedFloat32Array()
var life := PackedInt32Array()
var root_id := PackedInt32Array()
var proc_pct := PackedInt32Array()
## Damage on hit (0 = harmless, as the kernel scenario's dummies) and SimEvent tags.
var damage := PackedInt32Array()
var tags := PackedInt32Array()
## Ricochet Core (v0.2.0): wall bounces left, and the tick of the last bounce (-1 = none) for the view.
var bounces := PackedInt32Array()
var bounce_tick := PackedInt32Array()


func size() -> int:
	return ids.size()


func add(
	id: int,
	p_owner: int,
	p_team: int,
	p: Vector2,
	v: Vector2,
	r: float,
	p_life: int,
	p_damage: int = 0,
	p_tags: int = SimEvent.TAG_PROJECTILE,
	p_bounces: int = 0
) -> void:
	ids.append(id)
	owner.append(p_owner)
	team.append(p_team)
	pos_x.append(p.x)
	pos_y.append(p.y)
	vel_x.append(v.x)
	vel_y.append(v.y)
	radius.append(r)
	life.append(p_life)
	root_id.append(id)
	proc_pct.append(100)
	damage.append(p_damage)
	tags.append(p_tags)
	bounces.append(p_bounces)
	bounce_tick.append(-1)


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
	ids = _pick_i(ids, keep)
	owner = _pick_i(owner, keep)
	team = _pick_i(team, keep)
	life = _pick_i(life, keep)
	root_id = _pick_i(root_id, keep)
	proc_pct = _pick_i(proc_pct, keep)
	damage = _pick_i(damage, keep)
	tags = _pick_i(tags, keep)
	bounces = _pick_i(bounces, keep)
	bounce_tick = _pick_i(bounce_tick, keep)
	pos_x = _pick_f(pos_x, keep)
	pos_y = _pick_f(pos_y, keep)
	vel_x = _pick_f(vel_x, keep)
	vel_y = _pick_f(vel_y, keep)
	radius = _pick_f(radius, keep)


func hash_into(h: StateHasher) -> void:
	h.add_ints(ids)
	h.add_ints(owner)
	h.add_ints(team)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)
	h.add_f32s(vel_x)
	h.add_f32s(vel_y)
	h.add_f32s(radius)
	h.add_ints(life)
	h.add_ints(root_id)
	h.add_ints(proc_pct)
	h.add_ints(damage)
	h.add_ints(tags)
	h.add_ints(bounces)
	h.add_ints(bounce_tick)


static func _pick_i(a: PackedInt32Array, keep: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(keep.size())
	for k in keep.size():
		out[k] = a[keep[k]]
	return out


static func _pick_f(a: PackedFloat32Array, keep: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(keep.size())
	for k in keep.size():
		out[k] = a[keep[k]]
	return out
