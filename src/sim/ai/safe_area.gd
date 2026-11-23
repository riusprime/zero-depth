class_name SafeArea
extends RefCounted
## "Inside this area or hurt": the check a boss mechanic shares when part of the floor is safe and the rest costs
## HP (the Tidecaller's Riptide strips and its High Tide's dry circle). It knows no boss: a caller gives the safe
## shapes and what standing outside them costs.
## - The hero's centre decides: inside any safe strip (a Rect2) or any safe disc ([x, y, radius]) is safe.
## - The cost is a share of the hero's max HP, never scaled by the boss's power, so its size is the data's.
## - ONCE is one hit (Damage.hit: armour and the dash's invulnerability apply, as for any boss strike on the
##   ground). STEP is one step of damage over time (Damage.tick_dot): it neither waits for the invulnerability a
##   hit gives nor gives any, so a step every half second is paid every half second and shields nothing else.
## Pure: no stream is drawn.

enum Mode { ONCE, STEP }


## A room cut into `count` parallel strips that run along its longer side (x when it is square), from its low side
## up. They tile the room, no point in two strips and none of it in none: a Rect2 holds single-precision numbers and
## its end is its position plus its size in them, so each edge is rounded to one first (_stored) and each strip's
## size is set until its end lands on the next edge; with `w * k` alone a point on a shared edge could lie in both.
static func strips(room: Rect2, count: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := maxi(1, count)
	var along_x := runs_along_x(room)
	var low := room.position.y if along_x else room.position.x
	var high := room.end.y if along_x else room.end.x
	var w := (high - low) / n
	var edges: Array[float] = []
	for k in n + 1:
		edges.append(_stored(high if k == n else low + w * k))
	for k in n:
		var a := edges[k]
		var size := _stored(edges[k + 1] - a)
		for t in 3:  # One rounding step off at most: the size moves by what the end misses
			var miss := edges[k + 1] - _stored(a + size)
			if miss == 0.0:
				break
			size = _stored(size + miss)
		if along_x:
			out.append(Rect2(room.position.x, a, room.size.x, size))
		else:
			out.append(Rect2(a, room.position.y, size, room.size.y))
	return out


## v as a Rect2 or a Vector2 stores it (single precision).
static func _stored(v: float) -> float:
	return Vector2(v, 0.0).x


## True when the room's strips run along x (its longer side, or a square's).
static func runs_along_x(room: Rect2) -> bool:
	return room.size.x >= room.size.y


## The strip p lies in (the nearest one for a point outside the room).
static func strip_of(room: Rect2, count: int, p: Vector2) -> int:
	var n := maxi(1, count)
	var along_x := runs_along_x(room)
	var across := (p.y - room.position.y) if along_x else (p.x - room.position.x)
	var w := (room.size.y if along_x else room.size.x) / n
	return clampi(int(floorf(across / maxf(w, 0.0001))), 0, n - 1)


## True when p is inside any of the safe strips or the safe discs ([x, y, radius] each).
static func inside(p: Vector2, rects: Array[Rect2], discs: Array[Vector3] = []) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	for d in discs:
		var off := p - Vector2(d.x, d.y)
		if off.x * off.x + off.y * off.y <= d.z * d.z:
			return true
	return false


## `permille` of the hero's max HP, at least 1.
static func cost(w: World, permille: int) -> int:
	return maxi(1, w.actors.max_hp[0] * permille / 1000)


## The hero outside every safe shape pays `permille` of its max HP to boss i, by `mode`. `attack` is what the death
## recap names (World.killer_attack) and `effect` the damage's effect id. Returns the HP it lost (0 when it stood
## inside, is dead, or the hit was avoided).
static func check(
	w: World,
	i: int,
	rects: Array[Rect2],
	discs: Array[Vector3],
	permille: int,
	mode: Mode,
	attack: int,
	effect: StringName
) -> int:
	if w.player_dead() or inside(w.player_pos(), rects, discs):
		return 0
	return hurt(w, i, permille, mode, attack, effect)


## The hero pays `permille` of its max HP to boss i (check()'s cost, for a caller that has made the area test itself).
static func hurt(
	w: World, i: int, permille: int, mode: Mode, attack: int, effect: StringName
) -> int:
	if w.player_dead():
		return 0
	var id := w.actors.ids[i]
	var p := w.player_pos()
	var got := 0
	if mode == Mode.ONCE:
		got = Damage.hit(
			w, 0, cost(w, permille), id, id, w.take_root(), SimEvent.TAG_AREA, p, p, effect
		)
	else:
		var shield := w.actors.invuln[0]
		w.actors.invuln[0] = 0
		got = Damage.tick_dot(w, 0, cost(w, permille), id, id, effect)
		if not w.player_dead():
			w.actors.invuln[0] = shield
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = attack
	return got
