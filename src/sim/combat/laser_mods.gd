class_name LaserMods
extends RefCounted
## v0.9.5 FC1 (owner: "homing + laser would make the laser follow the neares enemy making a smooth curve, and with
## pierce it would make a smooth curve trying to hit the closest 5 enemies"; docs/roadmap/v0.9.5/FORM_COMBOS.md L1-L11):
## what the cards do to the Laser. One handler per card. A Laser ignores these cards' generic ops (WandCompile.run: it
## only notes the card in modifier_ids), and this file reads them from there: mask(spec).
## v0.11.0 O1 (owner, PLAN L1, L2; Q6, Q8, Q28): the Laser is a lance, one instant shot every 3 s (Laser's class
## doc), so every card works on the shot:
## - Geometry (plan(), a pure read at the firing tick): the main path of each lane, straight, bent by Homing (one smooth
##   path planned for the shot, below), reflected once by Ricochet, and the extra paths (Halo's fan, Backfire, Split's
##   fork) and Ring's circle, each a {from, to, hits, at, wall, kind, lane, share, ...} dictionary. Every path passes
##   every enemy on it (Q28); a wall stops it.
## - Homing (Q8: "only Homing bends it"; L2: "a single smooth, curved trajectory … not a rigid or visibly segmented
##   chain"; Q28: "it still bends through up to 5 chosen targets, then runs straight to full range"): at the shot the
##   nearest enemies in front of the aim within reach, in sight (pick(), at most home_chain, 5), and the path runs
##   through each in turn as one smooth curve (curve(): a Hermite spline through their centres), then straight on to
##   the first wall
##   (v0.11.0 O1c; at most TAIL_MAX_M, 40 m, so it always ends); a lance without Homing keeps its 9 m reach. The
##   curve is
##   cut into short legs (at most home_step_mm long,
##   each turning at most home_bend_deg from the one before, so the path never kinks); a target the path would have to
##   turn more than home_arc_deg to go on to, or one past home_len_permille of the reach along the curve, ends the
##   chain there.
## - Rapid Fire (Q6): the cooldown × rapid_cd per mille (700: -30 %), each shot × rapid_damage_permille (800: -20 %).
## - Echo (Q6): the main paths strike again echo_delay_ms (0.4 s) later at echo_share (50 %).
## - Big Shot (Q6): the lance big_width per mille wide (2x), big_damage per mille (x1.6), no aim lag.
## - Spiral: the shot's heading swings side to side on the sim clock (spiral_offset).
## - Mine is not offered with the Laser (Q6: off its row); a held one from a lab world still drops its mines (below).
## - State (World.mx lz_*, advance() each tick): Echo's waiting strikes and Mine's mines; the last shot's paths for the
##   view (record(); view-only, not hashed: they decide nothing).
## - Numbers: data/wand/attack_slots.tres, the laser row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Caps: a lance is no projectile, so none of this counts in the projectile caps; a kind hits an enemy at most once a
## shot (Laser.fire), a path has at most MAX_LEGS legs, Echo keeps at most 8 shots and Mine 4 mines.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const HALO := 1
const RING := 2
const BACKFIRE := 4
const HOMING := 8
const RICOCHET := 16
const ECHO := 32
const BIG := 64
const RAPID := 128
const SPLIT := 256
const MINE := 512
const SPIRAL := 1024
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"halo_shot",
	&"gun_ring",
	&"gun_backfire",
	&"gun_homing",
	&"gun_ricochet",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"gun_spiral",
]
const CARD_BITS: Array[int] = [
	HALO, RING, BACKFIRE, HOMING, RICOCHET, ECHO, BIG, RAPID, SPLIT, MINE, SPIRAL
]
## What a path dictionary's `kind` is.
const K_MAIN := &"main"
const K_HALO := &"halo"
const K_RING := &"ring"
const K_BACK := &"back"
const K_SPLIT := &"split"
## The kinds by index (record(): the view's copy of a shot keeps the index).
const KINDS: Array[StringName] = [K_MAIN, K_HALO, K_RING, K_BACK, K_SPLIT]
## record()'s flags of a path.
const F_IMPACT := 1
const F_END := 2
const F_WALL := 4
## The most legs of one path (a curve of short legs through five targets, a bounce).
const MAX_LEGS := 256
## The most legs one Homing piece (target to target) is cut into (curve()).
const PIECE_LEGS := 48
## v0.11.0 O1c (owner): Homing's straight tail runs on to the first wall, at most this long (m) so it always ends.
const TAIL_MAX_M := 40.0
const ECHO_TICKS_MAX := 8
const HZ := 60
## 2π, for an arc's length from its angle (a constant, no trig).
const TAU_F := 6.283185307179586
## The laser row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"lance_ticks": 30,
	"lance_feed": 3,
	"pierce_falloff_permille": 850,
	"pierce_floor_permille": 400,
	"halo_len_mm": 3000,
	"halo_turn_deg": 30,
	"halo_share": 400,
	"ring_mm": 1400,
	"ring_share": 500,
	"back_mm": 4500,
	"back_share": 1000,
	"home_step_mm": 750,
	"home_bend_deg": 12,
	"home_arc_deg": 160,
	"home_len_permille": 3000,
	"home_chain": 5,
	"echo_delay_ms": 400,
	"echo_share": 500,
	"big_width": 2000,
	"big_damage": 1600,
	"rapid_cd": 700,
	"rapid_damage_permille": 800,
	"split_mm": 4000,
	"split_deg": 25,
	"split_share": 500,
	"mine_every_ms": 1000,
	"mine_mm": 1500,
	"mine_share": 5000,
	"mine_max": 4,
	"mine_life_ms": 4000,
	"mine_trigger_mm": 600,
	"spiral_deg": 12,
	"spiral_hz": 2,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the laser cards the Laser `spec` carries (0: a plain Laser, nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eleven cards (WandCompile.run: on a Laser its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## The laser row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"laser", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func deg(d: int) -> int:
	return d * SimTick.ANGLE_UNITS / 360


static func mm(v: int) -> float:
	return v / 1000.0


## The shot's damage factor (per mille): Big Shot's x1.6, Rapid Fire's -20 % (Q6).
static func damage_permille(w: World, m: int) -> int:
	var f := param(w, "big_damage") if m & BIG else 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage_permille") / 1000
	return f


## The lance's width factor (per mille): Big Shot's double.
static func width_permille(w: World, m: int) -> int:
	return param(w, "big_width") if m & BIG else 1000


## Rapid Fire (Q6): the cooldown `base` × rapid_cd per mille (-30 %). `unit` is kept for the callers that read the
## period in thousandths (ItemEffects); the factor is the same.
static func rapid_period(w: World, spec: AttackSpec, base: int, _unit: int = 1) -> int:
	if not Laser.held(spec) or mask(spec) & RAPID == 0:
		return base
	return maxi(1, base * param(w, "rapid_cd") / 1000)


## Spiral: the shot's side-to-side turn now (1/4096 turns), a triangle wave on the sim clock.
static func spiral_offset(w: World) -> int:
	var hz := param(w, "spiral_hz")
	var period := maxi(1, HZ / hz)
	var u := ((w.tick % period) * 120 + 60) / period  # 0..119 over one wave, the peaks on whole ticks
	var v := u if u < 30 else (60 - u if u < 90 else u - 120)  # -30..30
	return deg(param(w, "spiral_deg")) * v / 30


## The heading the main lance has now: the player's aim, plus Spiral. v0.11.0 O1 (Q6): Big Shot no longer lags it.
static func heading(w: World, m: int, angle: int) -> int:
	var a := angle
	if m & SPIRAL:
		a += spiral_offset(w)
	return a & 4095


# --- Geometry -----------------------------------------------------------------------------------------------------
## One straight sweep from `from` along `dir` for `length`, `r` wide: stopped by a wall, or by its `most`-th enemy
## (the ones in `seen` don't count). {from, to, hits (nearest first), at, wall (it ended on one), wall_k (its index
## or -1)}.
static func ray(
	w: World, from: Vector2, dir: Vector2, length: float, r: float, most: int, seen: Dictionary
) -> Dictionary:
	var to := from + dir * length
	var wall := 1.0
	var wall_k := -1
	for k in w.walls_along(from, to, r):  # the grid's superset of the walls
		var s := Collide.sweep_vs_obb(from, to, r, w.walls[k])
		if s >= 0.0 and s < wall:
			wall = s
			wall_k = k
	var ts := PackedFloat32Array()
	var ids := PackedInt32Array()
	var a := w.actors
	for i in range(1, a.size()):  # every actor (phase 4 runs before the tick's grid)
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or seen.has(i):
			continue
		var s := Collide.sweep_vs_circle(from, to, r, a.pos(i), a.radius[i])
		if s < 0.0 or s >= wall:
			continue
		var at := ts.size()  # nearest first; a tie keeps the lower index
		while at > 0 and ts[at - 1] > s:
			at -= 1
		ts.insert(at, s)
		ids.insert(at, i)
	var end := wall
	var hit_wall := wall < 1.0
	if ids.size() >= most:
		ids.resize(most)
		ts.resize(most)
		end = ts[most - 1]
		hit_wall = false
	var pts := PackedVector2Array()
	for s in ts:
		pts.append(from + (to - from) * s)
	return {
		"from": from,
		"to": from + (to - from) * end,
		"hits": ids,
		"at": pts,
		"wall": hit_wall,
		"wall_k": wall_k if hit_wall else -1,
	}


## The paths of `spec` from `origin` along `angle` now with the laser cards (Laser.trace calls it for a card-carrying
## Laser): the lanes' main legs, then the centre lane's extras. Each also has kind, lane, share (per mille of the shot's
## damage), wmul (width per mille), impact (draw an impact at `to`) and end (the lane's last main leg).
static func plan(w: World, spec: AttackSpec, origin: Vector2, angle: int) -> Array[Dictionary]:
	var m := mask(spec)
	var out: Array[Dictionary] = []
	var base := heading(w, m, angle)
	var wmul := width_permille(w, m)
	var r := spec.radius_m * wmul / 1000.0
	var lanes := GunForms.lanes(spec, Laser.LANE_RADIUS_M)
	var turns := GunForms.lane_turns(spec)
	var centre := (lanes.size() - 1) / 2
	var targets := pick(w, spec, origin, base) if m & HOMING else PackedInt32Array()
	for li in lanes.size():
		var ang := (base + turns[li]) & 4095
		var dir := Kin.dir(ang)
		var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * lanes[li]
		var path := _path(w, spec, m, from, ang, r, targets)
		var legs: Array[Dictionary] = path["legs"]
		for k in legs.size():
			var leg := legs[k]
			leg["kind"] = K_MAIN
			leg["lane"] = li
			leg["share"] = 1000
			leg["wmul"] = wmul
			leg["end"] = k == legs.size() - 1
			leg["impact"] = k == legs.size() - 1 and bool(leg["wall"])
			out.append(leg)
		if li == centre:
			_extras(w, m, origin, base, path, r, wmul, li, out)
	return out


## The main path of one lane: {legs, tip (where it ends), heading (its last leg's), first (the first enemy hit, or -1),
## first_at, first_heading, seen}. Straight unless Homing bends it through `targets` (curve()) or Ricochet reflects it
## off its first wall (the rest of the curve is then dropped: it runs straight on).
static func _path(
	w: World, spec: AttackSpec, m: int, from: Vector2, ang: int, r: float, targets: PackedInt32Array
) -> Dictionary:
	var seen := {}
	var legs: Array[Dictionary] = []
	var out := {"legs": legs, "first": -1, "first_at": from, "first_heading": ang, "heading": ang}
	var bounce := m & RICOCHET != 0
	var way := PackedVector2Array()
	var way_end := ang
	if not targets.is_empty():
		var c := curve(w, spec, from, ang, targets)
		way = c["pts"]
		way_end = int(c["heading"])
	var pos := from
	var hd := ang
	var remain := spec.reach_m  # the straight run's length left (Homing: set where the curve ends)
	var traveled := 0.0
	var bounced := false
	var k := 0
	while (k < way.size() or remain > 0.01) and legs.size() < MAX_LEGS:
		var on_curve := k < way.size()
		var dir := Kin.dir(hd)
		var len := remain
		if on_curve:
			var d := way[k] - pos
			var dl := Kin.length(d)
			k += 1
			if dl < 0.001:
				continue
			dir = d / dl
			len = dl
			hd = Kin.angle_of(d)
			if k == way.size():
				hd = way_end  # the curve's end tangent: straight on from here
		var leg := ray(w, pos, dir, len, r, Laser.ALL, seen)
		for id in leg["hits"]:
			seen[id] = true
		if int(out["first"]) < 0 and leg["hits"].size() > 0:
			out["first"] = leg["hits"][0]
			out["first_at"] = leg["at"][0]
			out["first_heading"] = Kin.angle_of(dir)
		legs.append(leg)
		var went := Kin.length(leg["to"] - leg["from"])
		traveled += went
		if not on_curve:
			remain -= went
		pos = leg["to"]
		out["heading"] = hd
		if leg["wall"]:
			if not bounce or bounced:
				break
			var box: Obb = w.walls[leg["wall_k"]]
			var n := _normal(box, pos, r)
			hd = Kin.angle_of(dir - n * (2.0 * dir.dot(n)))
			pos += n * 0.03
			bounced = true
			if on_curve:  # the rest of the curve is dropped: straight on for what the reach has left
				remain = maxf(0.0, spec.reach_m - traveled)
			way = PackedVector2Array()
			k = 0
			continue
		if on_curve and k == way.size():
			remain = TAIL_MAX_M
			continue
		if not on_curve:
			break
	out["tip"] = legs.back()["to"] if not legs.is_empty() else from
	out["seen"] = seen
	return out


## Homing's one smooth path through `targets` (in order) from `from` heading `ang` (v0.11.0 O1, L2): a cubic Hermite
## curve through each target's centre, leaving along the aim, its tangent at each target the bisector of the lines in
## and out (so it never kinks), each piece as long as its chord. Each piece is cut into legs at most home_step_mm long,
## more of them where it bends, until no leg turns more than home_bend_deg from the one before (at most PIECE_LEGS a
## piece). A target the path would turn more than home_arc_deg to go on to, or one that would make the curve longer
## than home_len_permille of the reach (3x), ends the chain.
## {pts (the points after `from`, each target's centre among them), heading (the way on from the last), length}.
static func curve(
	w: World, spec: AttackSpec, from: Vector2, ang: int, targets: PackedInt32Array
) -> Dictionary:
	var most := deg(param(w, "home_arc_deg"))
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
	var tangents: Array[Vector2] = [Kin.dir(ang)]
	for k in range(1, knots.size()):
		var a := _unit(knots[k] - knots[k - 1])
		var b := _unit(knots[k + 1] - knots[k]) if k + 1 < knots.size() else a
		var m := a + b
		tangents.append(_unit(m) if Kin.length(m) > 0.001 else a)
	var bend := maxi(1, deg(param(w, "home_bend_deg")))
	var step := maxf(0.05, mm(param(w, "home_step_mm")))
	var pts := PackedVector2Array()
	var used := 0.0
	var last_dir := Kin.dir(ang)
	for k in range(1, knots.size()):
		var piece := _piece(
			knots[k - 1], tangents[k - 1], knots[k], tangents[k], step, bend, last_dir
		)
		var len := 0.0
		var at := knots[k - 1]
		for p in piece:
			len += Kin.length(p - at)
			at = p
		if used + len > mm(param(w, "home_len_permille")) * spec.reach_m:
			break
		pts.append_array(piece)
		used += len
		last_dir = _unit(
			(
				piece[piece.size() - 1]
				- (piece[piece.size() - 2] if piece.size() > 1 else knots[k - 1])
			)
		)
	var hd := ang
	if not pts.is_empty():
		var k := pts.size()
		hd = Kin.angle_of(tangents[_knot_of(knots, pts[k - 1])])
	return {"pts": pts, "heading": hd, "length": used}


## One piece of curve() from `a` (tangent `ta`) to `b` (tangent `tb`), both tangents unit, scaled by the chord: its
## points after `a`, `b` last, in legs at most `step` long, doubled until no leg turns more than `bend` from the one
## before (the first from `in_dir`, the way the path came in), at most PIECE_LEGS.
static func _piece(
	a: Vector2, ta: Vector2, b: Vector2, tb: Vector2, step: float, bend: int, in_dir: Vector2
) -> PackedVector2Array:
	var chord := Kin.length(b - a)
	var n := maxi(2, ceili(chord * 1.5 / step))  # a bent piece runs longer than its chord
	var out := PackedVector2Array()
	while true:
		out = PackedVector2Array()
		var worst := 0
		var at := a
		var dir_in := Kin.angle_of(in_dir)
		for k in range(1, n + 1):
			var s := float(k) / n
			var s2 := s * s
			var s3 := s2 * s
			var p := (
				a * (2.0 * s3 - 3.0 * s2 + 1.0)
				+ ta * (chord * (s3 - 2.0 * s2 + s))
				+ b * (-2.0 * s3 + 3.0 * s2)
				+ tb * (chord * (s3 - s2))
			)
			if k == n:
				p = b
			var d := Kin.angle_of(p - at)
			worst = maxi(worst, Kin.angle_diff(d, dir_in))
			dir_in = d
			out.append(p)
			at = p
		if worst <= bend or n >= PIECE_LEGS:
			break
		n = mini(PIECE_LEGS, n * 2)
	return out


static func _unit(v: Vector2) -> Vector2:
	var l := Kin.length(v)
	return v / l if l > 0.000001 else Vector2(1.0, 0.0)


## The index in `knots` of the point `p` (a target's centre), else the last.
static func _knot_of(knots: PackedVector2Array, p: Vector2) -> int:
	for k in knots.size():
		if knots[k] == p:
			return k
	return knots.size() - 1


## The live enemies within `r` of `center` (their edge), by index: a full scan, as ray() does (the shot fires in
## phase 4, before the tick's actor grid).
static func near(w: World, center: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var a := w.actors
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if Kin.length(a.pos(i) - center) <= r + a.radius[i]:
			out.append(i)
	return out


static func _gone(w: World, i: int) -> bool:
	return i <= 0 or i >= w.actors.size() or w.actors.dead[i] == 1


## Homing's targets at the shot: the home_chain (5) nearest enemies within the reach of `origin` (the hero)
## (v0.11.0 O1, Q28: the lance pierces, so always the chain), in the order the curve can take best (_order()).
## v0.10.0 FX (owner: "homing must respect walls"): an enemy behind the aim `ang` (more than 90 degrees off it) is no
## target, and each target must be in sight (no wall on the line) of the one before it in the chain, the first of the
## hero (so the curve can reach one behind a wall round it, through one in sight).
static func pick(w: World, spec: AttackSpec, origin: Vector2, ang: int) -> PackedInt32Array:
	var aim := Kin.dir(ang)
	var found := near(w, origin, spec.reach_m)
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
	var n := param(w, "home_chain")
	var pool: Array[int] = []
	for i in ids:  # the nearest n
		if pool.size() >= n:
			break
		pool.append(i)
	return _order(w, origin, ang, pool)


## The order curve() visits `pool` in (v0.11.0 O1, L2): of every order (at most 5! = 120), the one whose chain from
## `origin` goes furthest before a step the curve can't take (a target out of sight of the one before, or a turn of
## more than home_arc_deg from the line in), then the shortest such chain (by its straight steps; on a tie the first
## found, the nearest-first order tried first): a chain that runs along a pack rather than back and forth across it.
static func _order(w: World, origin: Vector2, ang: int, pool: Array[int]) -> PackedInt32Array:
	var most := deg(param(w, "home_arc_deg"))
	var best := PackedInt32Array()
	var best_cost := 0.0
	var perm := pool.duplicate()
	var c := []
	c.resize(perm.size())
	c.fill(0)
	var at := 0
	var first := true
	while true:  # Heap's algorithm, every order once
		if first:
			first = false
		else:
			while at < perm.size() and c[at] >= at:
				c[at] = 0
				at += 1
			if at >= perm.size():
				break
			var j: int = 0 if at % 2 == 0 else c[at]
			var t: int = perm[j]
			perm[j] = perm[at]
			perm[at] = t
			c[at] += 1
			at = 0
		var got := PackedInt32Array()
		var cost := 0.0
		var from := origin
		var prev := ang
		for i in perm:
			var p := w.actors.pos(i)
			var v := p - from
			if Kin.angle_diff(Kin.angle_of(v), prev) > most or not w.sees(from, p):
				break
			got.append(i)
			cost += Kin.length(v)
			prev = Kin.angle_of(v)
			from = p
		if got.size() > best.size() or (got.size() == best.size() and cost < best_cost - 0.000001):
			best = got
			best_cost = cost
	return best


## The outward normal of the wall box at the point `p` on its (grown) face.
static func _normal(box: Obb, p: Vector2, r: float) -> Vector2:
	var d := p - box.center
	var lx := d.dot(box.axis_u)
	var ly := d.dot(box.axis_v)
	if absf(lx) / (box.half.x + r) >= absf(ly) / (box.half.y + r):
		return box.axis_u if lx >= 0.0 else -box.axis_u
	return box.axis_v if ly >= 0.0 else -box.axis_v


static func _extras(
	w: World,
	m: int,
	origin: Vector2,
	base: int,
	path: Dictionary,
	r: float,
	wmul: int,
	lane: int,
	out: Array[Dictionary]
) -> void:
	var tip: Vector2 = path["tip"]
	var hd: int = path["heading"]
	if m & HALO:
		var span := deg(param(w, "halo_turn_deg"))
		for k in range(-1, 2):
			var d := Kin.dir((hd + k * span) & 4095)
			var b := ray(w, tip, d, mm(param(w, "halo_len_mm")), r, Laser.ALL, path["seen"])  # past what it hit
			_tag(b, K_HALO, lane, param(w, "halo_share"), wmul)
			out.append(b)
	if m & RING:
		var ring_r := mm(param(w, "ring_mm"))
		var ids := near(w, tip, ring_r)
		var pts := PackedVector2Array()
		for i in ids:
			pts.append(w.actors.pos(i))
		var b := {"from": tip, "to": tip, "hits": ids, "at": pts, "wall": false, "circle": ring_r}
		_tag(b, K_RING, lane, param(w, "ring_share"), wmul)
		b["impact"] = false
		out.append(b)
	if m & BACKFIRE:
		var d := Kin.dir((base + 2048) & 4095)
		var from := origin + d * w.player.radius_m
		var b := ray(w, from, d, mm(param(w, "back_mm")), r, Laser.ALL, {})
		_tag(b, K_BACK, lane, param(w, "back_share"), wmul)
		out.append(b)
	if m & SPLIT and int(path["first"]) > 0:
		var at: Vector2 = path["first_at"]
		var fh: int = path["first_heading"]
		var span := deg(param(w, "split_deg"))
		for s in [-1, 1]:
			var d := Kin.dir((fh + s * span) & 4095)
			var b := ray(
				w, at, d, mm(param(w, "split_mm")), r, Laser.ALL, {int(path["first"]): true}
			)
			_tag(b, K_SPLIT, lane, param(w, "split_share"), wmul)
			out.append(b)


static func _tag(b: Dictionary, kind: StringName, lane: int, share: int, wmul: int) -> void:
	b["kind"] = kind
	b["lane"] = lane
	b["share"] = share
	b["wmul"] = wmul
	b["end"] = true
	b["impact"] = bool(b["wall"])


# --- State, each tick ---------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): Echo's strikes and the mines' triggers; the view's record of the last shot
## is dropped when the Gun's shot is no Laser. A plain Laser (no card here) touches nothing else.
static func advance(w: World) -> void:
	var s := w.mx
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	var held := Laser.held(spec)
	if not held and s.lz_shot_tick >= 0:
		s.lz_shot_clear()
	var m := mask(spec) if held else 0
	if m == 0:
		if s.lz_touched():
			s.lz_clear()
		return
	if not Laser.firing(w):
		s.lz_mine_next = 0
	_echo_strikes(w, spec)
	_mine_triggers(w, spec)


## One shot (Laser.fire, `beams` its plan, `dmg` its damage, `milli` the thousandths of one old beam tick): Echo stores
## the main legs to strike again; a held Mine drops a mine at the tip every mine_every_ms.
static func after_shot(w: World, m: int, beams: Array[Dictionary], dmg: int, milli: int) -> void:
	var s := w.mx
	if m & ECHO and dmg > 0:
		var e := maxi(1, dmg * param(w, "echo_share") / 1000)
		_echo_store(w, beams, e)
	if m & MINE:
		if s.lz_mine_next == 0 or w.tick >= s.lz_mine_next:
			s.lz_mine_next = w.tick + ticks(param(w, "mine_every_ms"))
			var tip := _tip(beams)
			if s.lz_mine_at.size() >= param(w, "mine_max"):
				s.lz_mine_at.remove_at(0)
				s.lz_mine_born.remove_at(0)
				s.lz_mine_dmg.remove_at(0)
			s.lz_mine_at.append(tip)
			s.lz_mine_born.append(w.tick)
			s.lz_mine_dmg.append(maxi(1, milli * param(w, "mine_share") / 1000000))


## The view's copy of the shot just fired (WorldReader.beams draws it for its glow; it decides nothing): each path's
## from and to, and its kind (KINDS index), lane, width per mille and flags (F_IMPACT, F_END, F_WALL).
static func record(w: World, beams: Array[Dictionary]) -> void:
	var s := w.mx
	s.lz_shot_tick = w.tick
	var from := PackedVector2Array()
	var to := PackedVector2Array()
	var row := PackedInt32Array()
	for b in beams:
		from.append(b["from"])
		to.append(b["to"])
		var f := (
			(F_IMPACT if bool(b.get("impact", false)) else 0) | (F_END if bool(b["end"]) else 0)
		)
		f |= F_WALL if bool(b["wall"]) else 0
		row.append_array([KINDS.find(b["kind"]), int(b["lane"]), int(b["wmul"]), f])
	s.lz_shot_from = from
	s.lz_shot_to = to
	s.lz_shot_row = row


static func _tip(beams: Array[Dictionary]) -> Vector2:
	var tip: Vector2 = beams[0]["to"]
	for b in beams:
		if b["kind"] == K_MAIN and bool(b["end"]):
			tip = b["to"]
			break
	return tip


static func _echo_store(w: World, beams: Array[Dictionary], dmg: int) -> void:
	var s := w.mx
	var due := w.tick + ticks(param(w, "echo_delay_ms"))
	var groups := 0
	var last := -1
	for d in s.lz_echo_due:
		if d != last:
			groups += 1
			last = d
	if groups >= ECHO_TICKS_MAX:  # the oldest shot's strike is dropped
		var first: int = s.lz_echo_due[0]
		while s.lz_echo_due.size() > 0 and s.lz_echo_due[0] == first:
			_echo_remove(s, 0)
	for b in beams:
		if b["kind"] != K_MAIN:
			continue
		s.lz_echo_due.append(due)
		s.lz_echo_from.append(b["from"])
		s.lz_echo_to.append(b["to"])
		s.lz_echo_r.append(float(b["wmul"]) * spec_radius(w) / 1000.0)
		s.lz_echo_dmg.append(dmg)


static func spec_radius(w: World) -> float:
	return Modifiers.bolt(w).radius_m


static func _echo_remove(s: ModifierState, k: int) -> void:
	s.lz_echo_due.remove_at(k)
	s.lz_echo_from.remove_at(k)
	s.lz_echo_to.remove_at(k)
	s.lz_echo_r.remove_at(k)
	s.lz_echo_dmg.remove_at(k)


## The waiting strikes whose tick has come: each hits every enemy on its leg (once for its shot).
static func _echo_strikes(w: World, spec: AttackSpec) -> void:
	var s := w.mx
	var k := 0
	var seen := {}
	var root := -1
	while k < s.lz_echo_due.size():
		if s.lz_echo_due[k] > w.tick:
			k += 1
			continue
		if root < 0:
			root = w.take_root()
		var due: int = s.lz_echo_due[k]
		var from: Vector2 = s.lz_echo_from[k]
		var to: Vector2 = s.lz_echo_to[k]
		var c := AttackContext.make(
			from, 0, s.lz_echo_dmg[k], root, SimEvent.TAG_AREA, spec.effect_id
		)
		c.secondary = true
		var a := w.actors
		var ts: Array[float] = []
		var ids: Array[int] = []
		for i in range(1, a.size()):
			if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or seen.has(due * 100000 + i):
				continue
			var t := Collide.sweep_vs_circle(from, to, s.lz_echo_r[k], a.pos(i), a.radius[i])
			if t < 0.0:
				continue
			seen[due * 100000 + i] = true
			var at := ts.size()  # nearest first along the strike (v0.11.0 O1c: the falloff runs down it)
			while at > 0 and ts[at - 1] > t:
				at -= 1
			ts.insert(at, t)
			ids.insert(at, i)
		var f := 1000
		var base: int = s.lz_echo_dmg[k]
		for i in ids:
			c.damage = maxi(1, base * f / 1000)
			f = Laser.falloff_next(w, f)
			Laser.hit(w, spec, c, i, from, a.pos(i), false)
		_echo_remove(s, k)


## The mines: one expires after mine_life_ms; an enemy on it sets it off, a mine_mm burst of its stored damage.
static func _mine_triggers(w: World, spec: AttackSpec) -> void:
	var s := w.mx
	var k := 0
	var life := ticks(param(w, "mine_life_ms"))
	var trig := mm(param(w, "mine_trigger_mm"))
	var burst := mm(param(w, "mine_mm"))
	while k < s.lz_mine_at.size():
		var at: Vector2 = s.lz_mine_at[k]
		if w.tick - s.lz_mine_born[k] >= life:
			_mine_remove(s, k)
			continue
		if not _grounded_near(w, at, trig):  # v0.11.0 O9: a flier (the Cave Bat) never sets one off
			k += 1
			continue
		var dmg: int = s.lz_mine_dmg[k]
		_mine_remove(s, k)
		var c := AttackContext.make(at, 0, dmg, w.take_root(), SimEvent.TAG_AREA, spec.effect_id)
		c.secondary = true
		for i in w.enemies_near(at, burst):
			Laser.hit(w, spec, c, i, at, w.actors.pos(i), false)


## v0.11.0 O9 (ENEMIES.md H2): an enemy on the ground (not a flier: EnemyAi.flies) within r of `at`.
static func _grounded_near(w: World, at: Vector2, r: float) -> bool:
	for i in w.enemies_near(at, r):
		if not EnemyAi.flies(w, i):
			return true
	return false


static func _mine_remove(s: ModifierState, k: int) -> void:
	s.lz_mine_at.remove_at(k)
	s.lz_mine_born.remove_at(k)
	s.lz_mine_dmg.remove_at(k)
