class_name ProjectileStore
extends RefCounted
## Projectiles as structure-of-arrays in ascending id order. Each carries its provenance.

## v0.6.0 MX4: the behaviour columns (ProjectileMoves), ints.
const MOVE_INT_FIELDS: Array[StringName] = [
	&"pierce_left", &"ret", &"home", &"orbit_t", &"orbit_n", &"orbit_a", &"life0"
]

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
## v0.6.0 MX2: the spec a player projectile runs (an AttackBook key; "" = none: an enemy's, or one from before MX2).
var spec_key := PackedStringArray()
## v0.6.0 MX4 (ProjectileMoves): pierces left, return (0 none, 1 out, 2 coming back), homing turn per tick, the orbit
## (ticks left, its length, the angle it began at), the life it left with, its speed; `moves` once any had one
## (so stores whose projectiles never had a behaviour hash and step as before).
var pierce_left := PackedInt32Array()
var ret := PackedInt32Array()
var home := PackedInt32Array()
var orbit_t := PackedInt32Array()
var orbit_n := PackedInt32Array()
var orbit_a := PackedInt32Array()
var life0 := PackedInt32Array()
var speed := PackedFloat32Array()
var moves := false


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
	spec_key.append("")  # v0.6.0 MX2: World._apply_spawns names a player bolt's spec
	pierce_left.append(0)  # v0.6.0 MX4: ProjectileMoves.on_spawn sets them from the spec
	ret.append(0)
	home.append(0)
	orbit_t.append(0)
	orbit_n.append(0)
	orbit_a.append(0)
	life0.append(0)
	speed.append(0.0)


## Removes the entries at the given ascending indices, keeping order. In place, last first, with the arrays' own
## remove_at (v0.4.0 SC: a native move instead of rebuilding every array element by element each tick).
func remove_sorted(indices: PackedInt32Array) -> void:
	for k in range(indices.size() - 1, -1, -1):
		var i := indices[k]
		ids.remove_at(i)
		owner.remove_at(i)
		team.remove_at(i)
		life.remove_at(i)
		root_id.remove_at(i)
		proc_pct.remove_at(i)
		damage.remove_at(i)
		tags.remove_at(i)
		bounces.remove_at(i)
		bounce_tick.remove_at(i)
		if i < spec_key.size():
			spec_key.remove_at(i)
		if i < speed.size():  # v0.6.0 MX4
			pierce_left.remove_at(i)
			ret.remove_at(i)
			home.remove_at(i)
			orbit_t.remove_at(i)
			orbit_n.remove_at(i)
			orbit_a.remove_at(i)
			life0.remove_at(i)
			speed.remove_at(i)
		pos_x.remove_at(i)
		pos_y.remove_at(i)
		vel_x.remove_at(i)
		vel_y.remove_at(i)
		radius.remove_at(i)


## `with_specs` false leaves the spec keys out (the MX1 equivalence digest compares outcomes only).
func hash_into(h: StateHasher, with_specs: bool = true) -> void:
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
	if not with_specs:
		return
	for k in spec_key:  # v0.6.0 MX2: only once a projectile names a spec (the kernel golden's never do)
		if k != "":
			h.add_string(",".join(spec_key))
			break
