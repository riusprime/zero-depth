class_name ProjectileStore
extends RefCounted
## Projectiles as structure-of-arrays in ascending id order. Each carries its provenance.

## v0.6.0 MX4: the behaviour columns (ProjectileMoves), ints.
const MOVE_INT_FIELDS: Array[StringName] = [
	&"pierce_left", &"ret", &"home", &"orbit_t", &"orbit_n", &"orbit_a", &"life0"
]
## v0.8.0 MR (owner O91; SecondaryProc), bits of `second`: a secondary bolt (Twin's second lane, Spread's and Halo's
## bolts past the centre one, an Echo's repeat: its hits at the secondary proc) and a repeat's (an Echo's repeat and a
## repeat's hook bolts: their hits launch no trigger's later cast).
const SECONDARY := 1
const REPEAT := 2

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
## v0.6.5 WN3 (GunForms): the corkscrew's swing (1/4096 turns; 0 = none) and a mine's wait (ticks; 0 = not a mine).
var spiral := PackedInt32Array()
var mine_t := PackedInt32Array()
## v0.7.5 BF1 (BulletPatterns): a hostile fireball's look key ("" = a plain shot), so each boss's and enemy's shots
## look its own; empty until the first fireball (set_look), so stores that never held one step and hash as before.
var look := PackedStringArray()
## v0.7.5 BF2: a boss fireball's attack (the boss table's attack index that fired it; -1 = none), so the death recap
## names the pattern that killed, not the one the boss is on now. Empty until a boss's fireball flies (set_cause).
var cause := PackedInt32Array()
## v0.8.0 MR (owner O91; SecondaryProc): a player bolt's kind (the SECONDARY and REPEAT bits; 0 a plain one). Empty
## until the first such bolt (set_second), so stores that never held one step and hash as before.
var second := PackedInt32Array()


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
	spiral.append(0)  # v0.6.5 WN3: GunForms.on_spawn sets them from the spec
	mine_t.append(0)
	if not look.is_empty():  # v0.7.5 BF1
		look.append("")
	if not cause.is_empty():  # v0.7.5 BF2
		cause.append(-1)
	if not second.is_empty():  # v0.8.0 MR
		second.append(0)


## v0.7.5 BF1: projectile i is a fireball of look `key` (the column fills the first time).
func set_look(i: int, key: StringName) -> void:
	if look.size() < ids.size():
		look.resize(ids.size())
	look[i] = String(key)


## v0.7.5 BF2: projectile i was fired by its boss's attack `attack` (the column fills the first time, -1 elsewhere).
func set_cause(i: int, attack: int) -> void:
	if cause.size() < ids.size():
		var was := cause.size()
		cause.resize(ids.size())
		for k in range(was, ids.size()):
			cause[k] = -1
	cause[i] = attack


## v0.7.5 BF2: the boss attack that fired projectile i (-1 = none or not a boss's).
func cause_of(i: int) -> int:
	return cause[i] if i < cause.size() else -1


## v0.8.0 MR: projectile i is a secondary bolt or a repeat's (`kind`; the column fills the first time, 0 elsewhere).
func set_second(i: int, kind: int) -> void:
	if second.size() < ids.size():
		var was := second.size()
		second.resize(ids.size())
		for k in range(was, ids.size()):
			second[k] = 0
	second[i] = kind


## v0.8.0 MR: projectile i's kind (0 = a primary bolt).
func second_of(i: int) -> int:
	return second[i] if i < second.size() else 0


## v0.7.5 BF1: projectile i's look key ("" = a plain shot).
func look_of(i: int) -> String:
	return look[i] if i < look.size() else ""


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
		if i < mine_t.size():  # v0.6.5 WN3
			spiral.remove_at(i)
			mine_t.remove_at(i)
		if i < look.size():  # v0.7.5 BF1
			look.remove_at(i)
		if i < cause.size():  # v0.7.5 BF2
			cause.remove_at(i)
		if i < second.size():  # v0.8.0 MR
			second.remove_at(i)
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
	if not look.is_empty():  # v0.7.5 BF1: only once a fireball has flown (the kernel golden's never do)
		h.add_string(",".join(look))
	if not cause.is_empty():  # v0.7.5 BF2: only once a boss's fireball has flown
		h.add_ints(cause)
	if not second.is_empty():  # v0.8.0 MR: only once a secondary bolt has flown
		h.add_string("second")
		h.add_ints(second)
	if not with_specs:
		return
	for k in spec_key:  # v0.6.0 MX2: only once a projectile names a spec (the kernel golden's never do)
		if k != "":
			h.add_string(",".join(spec_key))
			break
