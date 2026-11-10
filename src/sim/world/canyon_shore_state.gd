class_name CanyonShoreState
extends RefCounted
## ENEMIES.md R5-R8; CanyonShore: what the Red Canyon's and the Frozen Shore's signature enemies leave on
## a floor, as parallel arrays (each group in the order it was added).
## - Bursts (a dead Kiln Beetle's): the centre and radius, the tick it fell and the tick it blows, its damage to the
##   hero and to each enemy (already powered by the beetle's tier).
## - Vents (the Cinder Priests'): the centre and the column's radius, the priest's id, the next eruption's tick
##   (-1: cooling, no rhythm), its period and pulse (ticks), its damage, the tick it goes (-1: while its priest lives)
##   and the last eruption's tick (-1: none yet).
## - Blobs (the Frost Spitters', in the air): from, to, the slick's radius, the tick thrown and the tick it lands, the
##   spitter's id, the slick's ticks and the hero's easing on it (per mille a tick).
## - Chunks (a broken Glacier Turtle shell's): the centre and velocity (m a tick), the tick it broke off and the tick it
##   goes, its damage, the turtle's id and its serial; `hit_chunk` / `hit_actor`: who each chunk already hurt (once).
## - Shells: the ids of the Glacier Turtles hit on the shell so far, and each shell's HP left (an untouched turtle's is
##   its table's).
## World hashes it only once anything was ever added (touched), so worlds without these enemies hash as before.

const INT_GROUPS := {
	&"burst": [&"burst_born", &"burst_due", &"burst_hero", &"burst_enemy"],
	&"vent":
	[
		&"vent_owner",
		&"vent_next",
		&"vent_period",
		&"vent_warn",
		&"vent_damage",
		&"vent_until",
		&"vent_last",
	],
	&"blob": [&"blob_born", &"blob_land", &"blob_owner", &"blob_ticks", &"blob_ease"],
	&"chunk": [&"chunk_born", &"chunk_until", &"chunk_damage", &"chunk_owner", &"chunk_serial"],
}
const FLOAT_GROUPS := {
	&"burst": [&"burst_x", &"burst_y", &"burst_r"],
	&"vent": [&"vent_x", &"vent_y", &"vent_r"],
	&"blob": [&"blob_fx", &"blob_fy", &"blob_tx", &"blob_ty", &"blob_r"],
	&"chunk": [&"chunk_x", &"chunk_y", &"chunk_vx", &"chunk_vy"],
}

var burst_x := PackedFloat32Array()
var burst_y := PackedFloat32Array()
var burst_r := PackedFloat32Array()
var burst_born := PackedInt32Array()
var burst_due := PackedInt32Array()
var burst_hero := PackedInt32Array()
var burst_enemy := PackedInt32Array()
var vent_x := PackedFloat32Array()
var vent_y := PackedFloat32Array()
var vent_r := PackedFloat32Array()
var vent_owner := PackedInt32Array()
var vent_next := PackedInt32Array()
var vent_period := PackedInt32Array()
var vent_warn := PackedInt32Array()
var vent_damage := PackedInt32Array()
var vent_until := PackedInt32Array()
var vent_last := PackedInt32Array()
var blob_fx := PackedFloat32Array()
var blob_fy := PackedFloat32Array()
var blob_tx := PackedFloat32Array()
var blob_ty := PackedFloat32Array()
var blob_r := PackedFloat32Array()
var blob_born := PackedInt32Array()
var blob_land := PackedInt32Array()
var blob_owner := PackedInt32Array()
var blob_ticks := PackedInt32Array()
var blob_ease := PackedInt32Array()
var chunk_x := PackedFloat32Array()
var chunk_y := PackedFloat32Array()
var chunk_vx := PackedFloat32Array()
var chunk_vy := PackedFloat32Array()
var chunk_born := PackedInt32Array()
var chunk_until := PackedInt32Array()
var chunk_damage := PackedInt32Array()
var chunk_owner := PackedInt32Array()
var chunk_serial := PackedInt32Array()
var next_serial := 0
var hit_chunk := PackedInt32Array()
var hit_actor := PackedInt32Array()
var shell_ids := PackedInt32Array()
var shell_hp := PackedInt32Array()
var touched := false


func burst_count() -> int:
	return burst_due.size()


func vent_count() -> int:
	return vent_owner.size()


func blob_count() -> int:
	return blob_land.size()


func chunk_count() -> int:
	return chunk_born.size()


func burst_pos(k: int) -> Vector2:
	return Vector2(burst_x[k], burst_y[k])


func vent_pos(k: int) -> Vector2:
	return Vector2(vent_x[k], vent_y[k])


func chunk_pos(k: int) -> Vector2:
	return Vector2(chunk_x[k], chunk_y[k])


## The vent priest `owner_id` keeps (-1: none).
func vent_of(owner_id: int) -> int:
	for k in vent_count():
		if vent_owner[k] == owner_id and vent_until[k] < 0:
			return k
	return -1


func add_burst(at: Vector2, r: float, born: int, due: int, hero: int, enemy: int) -> void:
	touched = true
	burst_x.append(at.x)
	burst_y.append(at.y)
	burst_r.append(r)
	burst_born.append(born)
	burst_due.append(due)
	burst_hero.append(hero)
	burst_enemy.append(enemy)


func add_vent(
	at: Vector2, r: float, owner_id: int, first: int, period: int, warn: int, damage: int
) -> void:
	touched = true
	vent_x.append(at.x)
	vent_y.append(at.y)
	vent_r.append(r)
	vent_owner.append(owner_id)
	vent_next.append(first)
	vent_period.append(period)
	vent_warn.append(warn)
	vent_damage.append(damage)
	vent_until.append(-1)
	vent_last.append(-1)


func add_blob(
	from: Vector2, to: Vector2, r: float, born: int, land: int, owner_id: int, ticks: int, ease: int
) -> void:
	touched = true
	blob_fx.append(from.x)
	blob_fy.append(from.y)
	blob_tx.append(to.x)
	blob_ty.append(to.y)
	blob_r.append(r)
	blob_born.append(born)
	blob_land.append(land)
	blob_owner.append(owner_id)
	blob_ticks.append(ticks)
	blob_ease.append(ease)


func add_chunk(
	at: Vector2, vel: Vector2, born: int, until: int, damage: int, owner_id: int
) -> void:
	touched = true
	chunk_x.append(at.x)
	chunk_y.append(at.y)
	chunk_vx.append(vel.x)
	chunk_vy.append(vel.y)
	chunk_born.append(born)
	chunk_until.append(until)
	chunk_damage.append(damage)
	chunk_owner.append(owner_id)
	chunk_serial.append(next_serial)
	next_serial += 1


## Whether chunk serial `serial` already hurt actor `actor_id`.
func chunk_hit(serial: int, actor_id: int) -> bool:
	for k in hit_chunk.size():
		if hit_chunk[k] == serial and hit_actor[k] == actor_id:
			return true
	return false


func note_hit(serial: int, actor_id: int) -> void:
	hit_chunk.append(serial)
	hit_actor.append(actor_id)


## Removes the rows at the given ascending indices of `group` (&"burst", &"vent", &"blob", &"chunk"), keeping order; a
## chunk's hit records go with it.
func remove(group: StringName, indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	if group == &"chunk":
		var gone := {}
		for k in indices:
			gone[chunk_serial[k]] = true
		for k in range(hit_chunk.size() - 1, -1, -1):
			if gone.has(hit_chunk[k]):
				hit_chunk.remove_at(k)
				hit_actor.remove_at(k)
	for f: StringName in INT_GROUPS[group]:
		var ai: PackedInt32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			ai.remove_at(indices[k])
		set(f, ai)
	for f: StringName in FLOAT_GROUPS[group]:
		var af: PackedFloat32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			af.remove_at(indices[k])
		set(f, af)


## Turtle `id`'s shell HP (`full` while it was never hit there).
func shell_of(id: int, full: int) -> int:
	var k := shell_ids.find(id)
	return shell_hp[k] if k >= 0 else full


func set_shell(id: int, hp: int) -> void:
	touched = true
	var k := shell_ids.find(id)
	if k >= 0:
		shell_hp[k] = hp
	else:
		shell_ids.append(id)
		shell_hp.append(hp)


func hash_into(h: StateHasher) -> void:
	for g: StringName in [&"burst", &"vent", &"blob", &"chunk"]:
		for f: StringName in INT_GROUPS[g]:
			h.add_ints(get(f))
		for f: StringName in FLOAT_GROUPS[g]:
			h.add_f32s(get(f))
	h.add_int(next_serial)
	h.add_ints(hit_chunk)
	h.add_ints(hit_actor)
	h.add_ints(shell_ids)
	h.add_ints(shell_hp)
