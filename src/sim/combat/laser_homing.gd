class_name LaserHoming
extends RefCounted
## v0.11.0 O1d (owner, 2026-11-08: "an even smoother curve that tracks up to maybe 8 enemies", "when multiple rays are
## shooted with twin ... they curve out and into the enemy, not overlapping each other"): Homing's geometry for the
## Laser, out of LaserMods (the class doc there has the rules). routes() takes each lane's targets for the shot, order()
## finds the best chain through a lane's targets, bow() its way out of the hero with curve() through them.
## Pure: float maths and Kin only, one sight check per pair, no randomness.

## The legs curve() leaves for the straight tail after it.
const TAIL_LEGS := 4
## The most legs one Homing piece (target to target) is cut into (curve()), and the times its bent legs are halved.
const PIECE_LEGS := 96
const PIECE_PASSES := 6
## How much of the full bow a ray tries, per mille, widest first: a bow that would hit a wall is flattened before the
## ray falls back to the straightest path (bow()).
const BOW_TRIES: Array[int] = [1000, 600, 300, 0]


## The routes of `count` lanes at the shot: [{ids, shared}, one a lane]. One lane: pick(). Several: the
## targets split by side of the aim (_split(): "each ray takes its own enemies"), each lane's in its own best order; a
## lane left with none (fewer enemies than lanes, or its group all out of sight) shares the first target of its nearest
## neighbour's route. No target at all: every route empty (the lanes run straight, as without Homing).
static func routes(
	w: World, spec: AttackSpec, origin: Vector2, ang: int, count: int
) -> Array[Dictionary]:
	var chosen := pool(w, spec, origin, ang)
	var sight := {}  # one look per pair, for the whole shot
	var routed: Array[PackedInt32Array] = []
	for g in _split(w, origin, ang, chosen, count):
		routed.append(order(w, origin, ang, g, sight))
	var out: Array[Dictionary] = []
	for li in count:
		out.append({"ids": routed[li], "shared": false})
	for li in count:
		if not routed[li].is_empty():
			continue
		var best := -1
		for k in count:
			if not routed[k].is_empty() and (best < 0 or absi(k - li) < absi(best - li)):
				best = k
		if best >= 0:
			out[li] = {"ids": PackedInt32Array([routed[best][0]]), "shared": true}
			out[best]["shared"] = true
	return out


## The pool routes() chooses from: the home_chain nearest enemies in front of `ang` within reach, nearest first.
static func pool(w: World, spec: AttackSpec, origin: Vector2, ang: int) -> Array[int]:
	var aim := Kin.dir(ang)
	var found := LaserMods.near(w, origin, spec.reach_m)
	var ds: Array[float] = []
	var ids: Array[int] = []
	for i in found:
		var to := w.actors.pos(i) - origin
		if to.dot(aim) < 0.0:
			continue
		var d := Kin.length(to)
		var at := ids.size()  # nearest first; a tie keeps the lower index
		while at > 0 and (ds[at - 1] > d or (ds[at - 1] == d and ids[at - 1] > i)):
			at -= 1
		ds.insert(at, d)
		ids.insert(at, i)
	ids.resize(mini(ids.size(), LaserMods.param(w, "home_chain")))
	return ids


## `pool` (nearest first) cut into `count` groups by side of the aim `ang` (lane 0 is the clockwise one:
## GunForms.lanes),
## as even as they divide (the extra ones in the first lanes), so rays don't cross needlessly; each group keeps the
## pool's nearest-first order.
static func _split(
	w: World, origin: Vector2, ang: int, pool: Array[int], count: int
) -> Array[Array]:
	var off: Array[int] = []
	var by: Array[int] = []
	for i in pool:
		var d := ((Kin.angle_of(w.actors.pos(i) - origin) - ang + 2048) & 4095) - 2048
		var at := by.size()  # clockwise first; a tie keeps the pool's order
		while at > 0 and off[at - 1] > d:
			at -= 1
		off.insert(at, d)
		by.insert(at, i)
	var out: Array[Array] = []
	var size := by.size() / count
	var extra := by.size() % count
	var k := 0
	for li in count:
		var take := size + (1 if li < extra else 0)
		var chosen := {}
		for j in take:
			chosen[by[k + j]] = true
		k += take
		var g: Array[int] = []
		for i in pool:
			if chosen.has(i):
				g.append(i)
		out.append(g)
	return out


## Sight from `a` to `b` (actor indices `ia`, `ib`; 0: the hero), asked once a shot: `sight` keeps the answers.
static func _sees(w: World, sight: Dictionary, ia: int, a: Vector2, ib: int, b: Vector2) -> bool:
	var key := ia * 65536 + ib
	if not sight.has(key):
		sight[key] = w.sees(a, b)
	return sight[key]


## The order curve() visits `pool` in (v0.11.0 O1, L2; dynamic programming over the subsets, at most
## n x (n - 1) x 2^(n - 2) steps of plain array work and n x n sight checks, one per pair and kept in `sight`, where it
## tried every order: 8! = 40,320 chains of sight checks): the chain from `origin` that goes furthest before a step the
## curve can't take (a target out of sight of the one before, or a turn of more than home_arc_deg from the line in),
## then
## the shortest such chain (by its straight steps; on a tie the one ending furthest down the pool: nearest-first): a
## chain that runs along a pack rather than back and forth across it. Each step's turn counts as home_turn_mm of chain a
## quarter-turn, so of two chains of about the same length the one that sweeps round wins. The bend check and the turn
## are measured on the cheapest way into each subset (the one approximation a full search would not make).
static func order(
	w: World, origin: Vector2, ang: int, pool: Array[int], sight: Dictionary
) -> PackedInt32Array:
	var n := pool.size()
	if n == 0:
		return PackedInt32Array()
	var most := LaserMods.deg(LaserMods.param(w, "home_arc_deg"))
	var pos := PackedVector2Array()
	for i in pool:
		pos.append(w.actors.pos(i))
	var pen := LaserMods.mm(LaserMods.param(w, "home_turn_mm")) / 1024.0
	var total := 1 << n
	var cost := PackedFloat64Array()
	cost.resize(total * n)
	cost.fill(-1.0)
	var head := PackedInt32Array()
	head.resize(total * n)
	var pred := PackedInt32Array()
	pred.resize(total * n)
	for i in n:
		var v := pos[i] - origin
		if Kin.angle_diff(Kin.angle_of(v), ang) > most:
			continue
		if not _sees(w, sight, 0, origin, pool[i], pos[i]):
			continue
		var at := (1 << i) * n + i
		cost[at] = Kin.length(v) + pen * Kin.angle_diff(Kin.angle_of(v), ang)
		head[at] = Kin.angle_of(v)
		pred[at] = -1
	var dist := PackedFloat64Array()
	var dir := PackedInt32Array()
	dist.resize(n * n)
	dir.resize(n * n)
	for a in n:
		for b in n:
			var d := pos[b] - pos[a]
			dist[a * n + b] = Kin.length(d)
			dir[a * n + b] = Kin.angle_of(d)
	var best_at := -1
	var best_n := 0
	var best_c := 0.0
	for mask in range(1, total):
		var count := 0
		for b in n:
			count += (mask >> b) & 1
		for last in n:
			if (mask >> last) & 1 == 0:
				continue
			var s := mask * n + last
			var c := cost[s]
			if c < 0.0:
				continue
			if count > best_n or (count == best_n and c < best_c + 0.000001):  # a tie: the later last
				best_at = s
				best_n = count
				best_c = c
			var h := head[s]
			for j in n:
				if (mask >> j) & 1 != 0:
					continue
				var step := last * n + j
				var into := (mask | (1 << j)) * n + j
				var turn := Kin.angle_diff(dir[step], h)
				var nc := c + dist[step] + pen * turn
				if cost[into] >= 0.0 and cost[into] <= nc + 0.000001:
					continue
				if turn > most:
					continue
				if not _sees(w, sight, pool[last], pos[last], pool[j], pos[j]):
					continue
				cost[into] = nc
				head[into] = dir[step]
				pred[into] = last
	var out := PackedInt32Array()
	while best_at >= 0:
		var last := best_at % n
		out.insert(0, pool[last])
		var before := pred[best_at]
		var mask := best_at / n
		best_at = -1 if before < 0 else (mask & ~(1 << last)) * n + before
	return out


## Lane `li`'s bowed way through its `route`: LaserMods.lane_start's dictionary with the curve (pts, heading). Without
## a Twin the
## one lane leaves along the aim. The lane leaves home_bow_deg off the aim on its own side (the outer lanes; a middle
## one straight on), its first tangent home_lens_permille long so the bow sweeps; a target it shares with another lane
## is met from the far side (the end tangent mirrors the start across the chord: a lens). The widest bow is tried first
## and flattened (BOW_TRIES) if it would hit a wall before its last target; then the straightest way (its first step
## straight at the first target).
static func bow(
	w: World,
	spec: AttackSpec,
	origin: Vector2,
	base: int,
	li: int,
	lanes: PackedFloat32Array,
	turns: PackedInt32Array,
	route: Dictionary,
	r: float
) -> Dictionary:
	var ids: PackedInt32Array = route["ids"]
	var count := lanes.size()
	var side := 2 * li - (count - 1)  # negative: the lane on the clockwise side of the aim
	var full := side * LaserMods.deg(LaserMods.param(w, "home_bow_deg")) / maxi(1, count - 1)
	var lens := 1000 if side == 0 else LaserMods.param(w, "home_lens_permille")
	var shared := bool(route["shared"]) and ids.size() == 1
	var way := {}
	var tried := -(1 << 20)
	for f in BOW_TRIES:
		var turn: int = full * f / 1000 + turns[li] * (1000 - f) / 1000
		if turn == tried:
			continue
		tried = turn
		way = LaserMods.lane_start(w, origin, (base + turn) & 4095, lanes[li])
		_curve_into(w, spec, way, ids, lens, shared)
		if _clear(w, way, r):
			return way
	way = LaserMods.lane_start(w, origin, base, lanes[li])  # the straightest: at the first target
	var straight := Kin.angle_of(w.actors.pos(ids[0]) - (way["from"] as Vector2))
	way["ang"] = straight
	way["heading"] = straight
	_curve_into(w, spec, way, ids, 1000, false)
	return way


## Fills `way` with the curve from its start through `ids`.
static func _curve_into(
	w: World, spec: AttackSpec, way: Dictionary, ids: PackedInt32Array, lens: int, mirror: bool
) -> void:
	var c := curve(w, spec, way["from"], way["ang"], ids, lens, mirror)
	way["pts"] = c["pts"]
	way["heading"] = c["heading"]


## No leg of the curve in `way` touches a wall (`r` wide, as the lance sweeps).
static func _clear(w: World, way: Dictionary, r: float) -> bool:
	var at: Vector2 = way["from"]
	for p in way["pts"] as PackedVector2Array:
		for k in w.walls_along(at, p, r):
			if Collide.sweep_vs_obb(at, p, r, w.walls[k]) >= 0.0:
				return false
		at = p
	return true


## Homing's one smooth path through `targets` (in order) from `from` heading `ang` (v0.11.0 O1, L2; a C2
## curve, a chord-length cubic spline, so its bend changes smoothly along the whole chain). It leaves along `ang`, its
## speed there `lens` per mille of the chord's (a longer first tangent sweeps a wider bow); it ends on the natural
## tangent (or, `mirror`, on the start tangent mirrored across the last chord: a lens). Each piece is cut into legs at
## most home_step_mm long, more of them where it bends, until no leg turns more than home_bend_deg from the one before
## (at most PIECE_LEGS a piece, LaserMods.MAX_LEGS for the path). A target the path would turn more than home_arc_deg
## to go on to,
## or one that would make the curve longer than home_len_permille of the reach (3x), ends the chain.
## {pts (the points after `from`, each target's centre among them), heading (the way on from the last), length}.
static func curve(
	w: World,
	spec: AttackSpec,
	from: Vector2,
	ang: int,
	targets: PackedInt32Array,
	lens: int = 1000,
	mirror: bool = false
) -> Dictionary:
	var most := LaserMods.deg(LaserMods.param(w, "home_arc_deg"))
	var knots := PackedVector2Array([from])
	var prev := ang
	for t in targets:
		var p := w.actors.pos(t)
		var v := p - knots[knots.size() - 1]
		if Kin.length(v) < 0.05:
			continue
		if Kin.angle_diff(Kin.angle_of(v), prev) > most:
			break
		knots.append(p)
		prev = Kin.angle_of(v)
	if knots.size() < 2:
		return {"pts": PackedVector2Array(), "heading": ang, "length": 0.0}
	var d := _tangents(knots, Kin.dir(ang) * (lens / 1000.0), mirror)
	var bend := maxi(1, LaserMods.deg(LaserMods.param(w, "home_bend_deg")))
	var step := maxf(0.05, LaserMods.mm(LaserMods.param(w, "home_step_mm")))
	var limit := LaserMods.mm(LaserMods.param(w, "home_len_permille")) * spec.reach_m
	var pts := PackedVector2Array()
	var used := 0.0
	var last := 0
	var last_dir := Kin.dir(ang)
	for k in range(1, knots.size()):
		var a := knots[k - 1]
		var chord := Kin.length(knots[k] - a)
		var piece := _piece(a, d[k - 1] * chord, knots[k], d[k] * chord, step, bend, last_dir)
		var len := 0.0
		var at := a
		for p in piece:
			len += Kin.length(p - at)
			at = p
		if used + len > limit or pts.size() + piece.size() > LaserMods.MAX_LEGS - TAIL_LEGS:
			break
		pts.append_array(piece)
		used += len
		last = k
		last_dir = _unit(
			piece[piece.size() - 1] - (piece[piece.size() - 2] if piece.size() > 1 else a)
		)
	return {"pts": pts, "heading": Kin.angle_of(d[last]) if last > 0 else ang, "length": used}


## The velocities of the chord-length cubic spline through `knots` (per metre of chord: a C2 curve), starting with
## `start` and ending naturally or (`mirror`) with `start` mirrored across the last chord. Solves the tridiagonal system
## directly (a few float operations a knot; no trig).
static func _tangents(knots: PackedVector2Array, start: Vector2, mirror: bool) -> Array[Vector2]:
	var n := knots.size() - 1
	var h := PackedFloat64Array()
	var chord: Array[Vector2] = []
	for k in n:
		var v := knots[k + 1] - knots[k]
		var l := maxf(0.001, Kin.length(v))
		h.append(l)
		chord.append(v / l)
	var cp := PackedFloat64Array()
	cp.resize(n + 1)
	var dp: Array[Vector2] = []
	dp.resize(n + 1)
	cp[0] = 0.0
	dp[0] = start
	for k in range(1, n):
		var mid := (chord[k - 1] * h[k] + chord[k] * h[k - 1]) * 3.0
		var den := 2.0 * (h[k - 1] + h[k]) - h[k] * cp[k - 1]
		cp[k] = h[k - 1] / den
		dp[k] = (mid - dp[k - 1] * h[k]) / den
	var out: Array[Vector2] = []
	out.resize(n + 1)
	if mirror:
		var c := chord[n - 1]
		out[n] = c * (2.0 * c.dot(start)) - start
	else:
		out[n] = (chord[n - 1] * 3.0 - dp[n - 1]) / (2.0 - cp[n - 1])
	for k in range(n - 1, -1, -1):
		out[k] = dp[k] - out[k + 1] * cp[k]
	out[0] = start
	return out


## One piece of curve() from `a` (velocity `ma`) to `b` (velocity `mb`), the Hermite velocities over the whole piece:
## its
## points after `a`, `b` last, in legs at most `step` long; the legs that turn more than `bend` from the one before (the
## first from `in_dir`, the way the path came in) are halved, at most PIECE_PASSES times and to PIECE_LEGS legs, so the
## legs are short only where the curve bends.
static func _piece(
	a: Vector2, ma: Vector2, b: Vector2, mb: Vector2, step: float, bend: int, in_dir: Vector2
) -> PackedVector2Array:
	var reach := (
		Kin.length(ma) / 3.0 + Kin.length(b - a - ma / 3.0 - mb / 3.0) + Kin.length(mb) / 3.0
	)
	var n := maxi(2, ceili(reach / step))  # the control polygon's length: at least the curve's
	var at_s := PackedFloat64Array()
	for k in n + 1:
		at_s.append(float(k) / n)
	var out := PackedVector2Array()
	for _pass in PIECE_PASSES:
		var m := at_s.size() - 1
		out.resize(m)
		for k in m:
			out[k] = _hermite(a, ma, b, mb, at_s[k + 1]) if k < m - 1 else b
		var split := PackedByteArray()
		split.resize(m)
		var any := false
		var from := a
		var was := Kin.angle_of(in_dir)
		for k in m:
			var d := Kin.angle_of(out[k] - from)
			if Kin.angle_diff(d, was) > bend:
				any = true
				split[k] = 1
				if k > 0:
					split[k - 1] = 1
			was = d
			from = out[k]
		if not any or m >= PIECE_LEGS:
			break
		var finer := PackedFloat64Array([0.0])
		for k in m:
			if split[k] == 1:
				finer.append((at_s[k] + at_s[k + 1]) * 0.5)
			finer.append(at_s[k + 1])
		at_s = finer
	return out


static func _hermite(a: Vector2, ma: Vector2, b: Vector2, mb: Vector2, s: float) -> Vector2:
	var s2 := s * s
	var s3 := s2 * s
	return (
		a * (2.0 * s3 - 3.0 * s2 + 1.0)
		+ ma * (s3 - 2.0 * s2 + s)
		+ b * (-2.0 * s3 + 3.0 * s2)
		+ mb * (s3 - s2)
	)


static func _unit(v: Vector2) -> Vector2:
	var l := Kin.length(v)
	return v / l if l > 0.000001 else Vector2(1.0, 0.0)
