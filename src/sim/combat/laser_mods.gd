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
##   chain"; Q28; v0.11.0 O1d, owner 2026-11-08: "an even smoother curve that tracks up to maybe 8 enemies"): at the
##   shot the nearest enemies in front of the aim within reach (at most home_chain, 8), in sight of the one before
##   (LaserHoming.routes()), and the path runs through each in turn as one smooth curve (LaserHoming.curve(): a C2
##   spline through their
##   centres), then straight on along its arrival heading to the first wall (v0.11.0 O1c; at most TAIL_MAX_M, 40 m, so
##   it always ends); a lance without Homing keeps its 9 m reach. The curve is cut into short legs (at most home_step_mm
##   long, each turning at most home_bend_deg from the one before, so the path never kinks); a target the path would
##   have to turn more than home_arc_deg to go on to, or one past home_len_permille of the reach along the curve, ends
##   the chain there.
## - Twin with Homing (v0.11.0 O1d, owner: "they curve out and into the enemy, not overlapping each other"; without
##   Homing Twin stays straight, Q8): each ray takes its own enemies, the pack split by side of the aim;
##   fewer enemies than rays and they share them. Each ray leaves on its own outward heading (home_bow_deg
##   off the aim on its own side, the outer rays; a third ray runs down the middle) and bows into its first target
##   (a shared one is met from both sides, a lens: LaserHoming.bow()), and each runs on along its own arrival heading,
##   so tails
##   fan apart. A bow that would hit a wall before its target is flattened, then straightened (LaserHoming.BOW_TRIES).
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
## The most legs of one path (a curve of short legs through eight targets, a bounce).
const MAX_LEGS := 256
## v0.11.0 O1d: a path's enemies are searched this many legs at a time (_near_span(): the long curve never scans the
## room per leg).
const SPAN_LEGS := 8
## v0.11.0 O1c (owner): Homing's straight tail runs on to the first wall, at most this long (m) so it always ends.
const TAIL_MAX_M := 40.0
const ECHO_TICKS_MAX := 8
const HZ := 60
## 2π, for an arc's length from its angle (a constant, no trig).
const TAU_F := 6.283185307179586
## The laser row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"lance_ticks": 19,
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
	"home_step_mm": 450,
	"home_bend_deg": 6,
	"home_arc_deg": 160,
	"home_len_permille": 3000,
	"home_chain": 8,
	"home_bow_deg": 50,
	"home_lens_permille": 1300,
	"home_turn_mm": 1500,
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
	return _sweep(w, from, dir, length, r, most, seen, PackedInt32Array(), true)


## ray(), over the actors in `scan` (unless `all`, every actor).
static func _sweep(
	w: World,
	from: Vector2,
	dir: Vector2,
	length: float,
	r: float,
	most: int,
	seen: Dictionary,
	scan: PackedInt32Array,
	all: bool
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
	var last := a.size() if all else scan.size()
	for j in range(1 if all else 0, last):  # every actor (phase 4 runs before the tick's grid)
		var i := j if all else scan[j]
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
	var routes: Array[Dictionary] = []
	if m & HOMING:
		routes = LaserHoming.routes(w, spec, origin, base, lanes.size())
	for li in lanes.size():
		var way := {}
		if not routes.is_empty() and not (routes[li]["ids"] as PackedInt32Array).is_empty():
			way = LaserHoming.bow(w, spec, origin, base, li, lanes, turns, routes[li], r)
		else:
			way = lane_start(w, origin, (base + turns[li]) & 4095, lanes[li])
		var path := _path(w, spec, m, way, r)
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


## A lane's start at heading `ang`, `offset` across it: {from (on the hero's edge), ang, pts (no curve yet), heading}.
static func lane_start(w: World, origin: Vector2, ang: int, offset: float) -> Dictionary:
	var dir := Kin.dir(ang)
	var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * offset
	return {"from": from, "ang": ang, "pts": PackedVector2Array(), "heading": ang}


## The main path of one lane along `way` (lane_start, or LaserHoming.bow's curve): {legs, tip (where it ends), heading
## (its last
## leg's), first (the first enemy hit, or -1), first_at, first_heading, seen}. Straight unless Homing bent it through
## its targets or Ricochet reflects it off its first wall (the rest of the curve is then dropped: it runs straight on).
static func _path(w: World, spec: AttackSpec, m: int, way: Dictionary, r: float) -> Dictionary:
	var seen := {}
	var legs: Array[Dictionary] = []
	var from: Vector2 = way["from"]
	var ang: int = way["ang"]
	var pts: PackedVector2Array = way["pts"]
	var way_end: int = way["heading"]
	var out := {"legs": legs, "first": -1, "first_at": from, "first_heading": ang, "heading": ang}
	var bounce := m & RICOCHET != 0
	var pos := from
	var hd := ang
	var remain := spec.reach_m  # the straight run's length left (Homing: set where the curve ends)
	var traveled := 0.0
	var bounced := false
	var k := 0
	var scan := PackedInt32Array()
	while (k < pts.size() or remain > 0.01) and legs.size() < MAX_LEGS:
		var on_curve := k < pts.size()
		var dir := Kin.dir(hd)
		var len := remain
		if on_curve:
			if k % SPAN_LEGS == 0:
				scan = _near_span(w, pos, pts, k, r)
			var d := pts[k] - pos
			var dl := Kin.length(d)
			k += 1
			if dl < 0.001:
				continue
			dir = d / dl
			len = dl
			hd = Kin.angle_of(d)
			if k == pts.size():
				hd = way_end  # the curve's end tangent: straight on from here
		var leg := _sweep(w, pos, dir, len, r, Laser.ALL, seen, scan, not on_curve)
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
			pts = PackedVector2Array()
			k = 0
			continue
		if on_curve and k == pts.size():
			remain = TAIL_MAX_M
			continue
		if not on_curve:
			break
	out["tip"] = legs.back()["to"] if not legs.is_empty() else from
	out["seen"] = seen
	return out


## v0.11.0 O1d: the actors within reach of the next SPAN_LEGS legs of the curve `pts` from `k` (a box round them; `at`
## is
## where the first starts): _path sweeps only these, not the room, along a long curve.
static func _near_span(
	w: World, at: Vector2, pts: PackedVector2Array, k: int, r: float
) -> PackedInt32Array:
	var lo := at
	var hi := at
	for j in range(k, mini(k + SPAN_LEGS, pts.size())):
		lo = Vector2(minf(lo.x, pts[j].x), minf(lo.y, pts[j].y))
		hi = Vector2(maxf(hi.x, pts[j].x), maxf(hi.y, pts[j].y))
	var out := PackedInt32Array()
	var a := w.actors
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		var p := a.pos(i)
		var pad := r + a.radius[i]
		if p.x >= lo.x - pad and p.x <= hi.x + pad and p.y >= lo.y - pad and p.y <= hi.y + pad:
			out.append(i)
	return out


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


## Homing's targets at the shot for one ray: the home_chain nearest enemies within the reach of `origin` (the hero), in
## the order the curve can take best (LaserHoming.order()).
## v0.10.0 FX (owner: "homing must respect walls"): an enemy behind the aim `ang` (more than 90 degrees off it) is no
## target, and each target must be in sight (no wall on the line) of the one before it in the chain, the first of the
## hero (so the curve can reach one behind a wall round it, through one in sight).
static func pick(w: World, spec: AttackSpec, origin: Vector2, ang: int) -> PackedInt32Array:
	return LaserHoming.order(w, origin, ang, LaserHoming.pool(w, spec, origin, ang), {})


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
