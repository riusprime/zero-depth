class_name BossLattice
extends RefCounted
## The Hive Lens's Lattice (BossLensTable.lat_*, strand_*, orbit_*; BossFightStore.hl_*), run by BossLens: the boss's
## light bounces from drone to drone and weaves a web that turns across the room.
## - The clock, from lat_phase: the first is due lat_first_ticks after the first tick the boss stands in a phase
##   (after its gate), the next lat_every_ticks after that one's cast began. It waits while the boss is in an attack
##   (an attack under way finishes first), kneels at a gate, winds up or burns a Gaze or the calm after one runs
##   (calm_ticks), and while fewer than lat_min drones live (BossLens casts the split first).
## - The cast: lat_cast_ticks (its turn, +1 or -1, drawn from the ai stream as it begins). With fewer than lat_min
##   drones alive when it ends, there is no web this time.
## - The web, for lat_ticks: the drones in the order of their angle round the boss; a strand joins the boss to the
##   first, each to the next, and the last back to the boss. The drones stop their own attacks (the ORBIT state, a
##   script row) and turn round the boss orbit_step a tick in the cast's turn, their distance eased (at their own walk
##   speed) to what it was, held to orbit_min_m..orbit_max_m, and kept inside the room. A drone killed takes the two
##   strands that met at it: the gap stays open for the rest of this web. With no drone of it left the web ends.
## - A hero touching a strand (strand_half_m from its line, plus its own radius) loses strand_hit per mille of its max
##   HP (a hit: armour and the dash's invulnerability apply), then no strand hurts it for strand_lock_ticks.
## - A gate or the end of the fight ends it; its drones go back to their own ways (free_drones).
## Pure: integer angles (Kin), one ai-stream draw a cast.

const S := EnemyAi.State
## A Lattice drone's own actor state (after BossDoom.CART): BossSignatures.egg_think leaves it to this file.
const ORBIT := 11
## The angles are kept in thousandths of 1/4096 turn.
const MILLI := 1000
const TURN := 4096 * MILLI
## A drone keeps this far inside the room's edge.
const EDGE_M := 0.5
## STATUS_APPLY effects (source the boss). CAST: a Lattice's cast begins (amount = its ticks, amount_applied = its turn,
## +1 or -1). START: the web rose (amount = its ticks, amount_applied = its drones). END: it ended (amount = its drones
## left; 0 also when no web rose). STRAND_HIT: a strand hurt the hero (pos = the nearest point of the strand, amount =
## the HP it cost).
const CAST := &"lattice_cast"
const START := &"lattice_start"
const END := &"lattice_end"
const STRAND_HIT := &"lattice_strand_hit"
## The damage effect id of a strand.
const EFFECT := &"lens_strand"


## True when the next Lattice's time has come and none is cast or runs.
static func due(w: World) -> bool:
	var fs := w.boss_fight
	return fs.hl_due >= 0 and w.tick >= fs.hl_due and not busy(w)


## True while a Lattice is cast or runs.
static func busy(w: World) -> bool:
	return w.boss_fight.hl_cast_from >= 0 or w.boss_fight.hl_run_from >= 0


## True while the web stands (after the cast).
static func running(w: World) -> bool:
	return w.boss_fight.hl_run_from >= 0


## BossLens.advance: boss i's Lattice in `phase`.
static func advance(w: World, i: int, f: BossLensTable, phase: int) -> void:
	var fs := w.boss_fight
	if phase < f.lat_phase:
		return
	var gate := w.actors.state[i] == BossAi.GATE
	if gate:
		stop(w, i)
		return
	if fs.hl_phase != phase:  # The first tick it stands in a new phase starts that phase's clock
		fs.hl_phase = phase
		fs.hl_due = w.tick + f.lat_first_ticks
	if fs.hl_run_from >= 0:
		_run(w, i, f)
	elif fs.hl_cast_from >= 0:
		if w.tick - fs.hl_cast_from >= f.lat_cast_ticks:
			_rise(w, i, f)
	elif _may_cast(w, i, f):
		fs.hl_cast_from = w.tick
		fs.hl_due = w.tick + f.lat_every_ticks
		fs.hl_spin = 1 if w.rng_ai.range_int(0, 1) == 0 else -1
		var e := BossLens.event(w, i, CAST, w.actors.pos(i))
		e.amount = f.lat_cast_ticks
		e.amount_applied = fs.hl_spin


static func _may_cast(w: World, i: int, f: BossLensTable) -> bool:
	var fs := w.boss_fight
	if not due(w) or w.player_dead() or w.actors.state[i] != S.MOVE:
		return false
	if BossLens.gazing(w, i) or (fs.hl_gaze_end >= 0 and w.tick - fs.hl_gaze_end <= f.calm_ticks):
		return false
	return BossLens.drones(w, f).size() >= f.lat_min


## The cast is over: the web rises through the drones alive, in the order of their angle round the boss.
static func _rise(w: World, i: int, f: BossLensTable) -> void:
	var fs := w.boss_fight
	var a := w.actors
	fs.hl_cast_from = -1
	var js := BossLens.drones(w, f)
	if js.size() < f.lat_min:
		_end(w, i, 0)
		return
	var c := a.pos(i)
	var rows: Array[Array] = []
	for j in js:
		var off := a.pos(j) - c
		rows.append([Kin.angle_of(off), a.ids[j], Kin.length(off)])
	rows.sort_custom(_by_angle)
	for r: Array in rows:
		fs.hl_d_id.append(int(r[1]))
		fs.hl_d_a.append(int(r[0]) * MILLI)
		fs.hl_d_r.append(clampf(float(r[2]), f.orbit_min_m, f.orbit_max_m))
		var j := a.index_of(int(r[1]))
		EnemyAi.enter_state(a, j, ORBIT)
	fs.hl_run_from = w.tick
	fs.hl_hit_at = 0
	var e := BossLens.event(w, i, START, c)
	e.amount = f.lat_ticks
	e.amount_applied = rows.size()


## The rows' order: by angle, then by id (a tie never depends on the actors' order).
static func _by_angle(x: Array, y: Array) -> bool:
	return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1]))


static func _run(w: World, i: int, f: BossLensTable) -> void:
	var fs := w.boss_fight
	if w.tick - fs.hl_run_from >= f.lat_ticks or _left(w) == 0:
		stop(w, i)
		return
	_turn(w, i, f)
	_strands_hit(w, i, f)


## The drones of the web still alive.
static func _left(w: World) -> int:
	var n := 0
	for k in w.boss_fight.hl_d_id.size():
		if drone_at(w, k) >= 0:
			n += 1
	return n


## The actor index of the web's drone k while it lives, else -1.
static func drone_at(w: World, k: int) -> int:
	var j := w.actors.index_of(w.boss_fight.hl_d_id[k])
	return j if j >= 0 and w.actors.dead[j] == 0 else -1


## The web turns: each drone alive steps round the boss and eases toward its distance, inside the room.
static func _turn(w: World, i: int, f: BossLensTable) -> void:
	var fs := w.boss_fight
	var a := w.actors
	var c := a.pos(i)
	var room := w.bosses.arena
	for k in fs.hl_d_id.size():
		var j := drone_at(w, k)
		if j < 0:
			continue
		fs.hl_d_a[k] = posmod(fs.hl_d_a[k] + fs.hl_spin * f.orbit_step, TURN)
		var now := Kin.length(a.pos(j) - c)
		var step := w.enemy_table(a.kinds[j]).speed
		var r := now + clampf(fs.hl_d_r[k] - now, -step, step)
		var p := c + Kin.dir(fs.hl_d_a[k] / MILLI) * r
		if room.has_area():
			var inner := room.grow(-(EDGE_M + a.radius[j]))
			p = Vector2(
				clampf(p.x, inner.position.x, inner.end.x),
				clampf(p.y, inner.position.y, inner.end.y)
			)
		a.set_pos(j, p)


## Every strand standing now: [from, to, the id at its start, the id at its end] (the boss's own id at its ends).
static func strands(w: World, i: int) -> Array[Array]:
	var fs := w.boss_fight
	var out: Array[Array] = []
	var n := fs.hl_d_id.size()
	if fs.hl_run_from < 0 or n == 0 or i < 0:
		return out
	var boss := w.actors.ids[i]
	var nodes: Array[Array] = [[w.actors.pos(i), boss]]
	for k in n:
		var j := drone_at(w, k)
		nodes.append([w.actors.pos(j) if j >= 0 else Vector2.INF, fs.hl_d_id[k]])
	nodes.append([w.actors.pos(i), boss])
	for k in n + 1:
		var p: Vector2 = nodes[k][0]
		var q: Vector2 = nodes[k + 1][0]
		if p.is_finite() and q.is_finite():
			out.append([p, q, int(nodes[k][1]), int(nodes[k + 1][1])])
	return out


## The point of segment p..q nearest to x.
static func nearest(p: Vector2, q: Vector2, x: Vector2) -> Vector2:
	var d := q - p
	var l2 := d.dot(d)
	if l2 <= 0.000001:
		return p
	return p + d * clampf((x - p).dot(d) / l2, 0.0, 1.0)


static func _strands_hit(w: World, i: int, f: BossLensTable) -> void:
	var fs := w.boss_fight
	if w.player_dead() or w.tick < fs.hl_hit_at:
		return
	var hero := w.player_pos()
	var reach := f.strand_half_m + w.player.radius_m
	for s: Array in strands(w, i):
		var at := nearest(s[0], s[1], hero)
		if Kin.length(hero - at) > reach:
			continue
		var got := SafeArea.hurt(w, i, f.strand_hit, SafeArea.Mode.ONCE, f.strand_cause, EFFECT)
		if got > 0:
			fs.hl_hit_at = w.tick + f.strand_lock_ticks
			BossLens.event(w, i, STRAND_HIT, at).amount = got
		return


## The Lattice ends (cast or web), if one is under way.
static func stop(w: World, i: int) -> void:
	if not busy(w):
		return
	_end(w, i, _left(w))


static func _end(w: World, i: int, left: int) -> void:
	var fs := w.boss_fight
	free_drones(w)
	fs.hl_cast_from = -1
	fs.hl_run_from = -1
	fs.hl_end = w.tick
	if i >= 0:
		BossLens.event(w, i, END, w.actors.pos(i)).amount = left


## The web's drones still alive go back to their own ways; the web forgets them.
static func free_drones(w: World) -> void:
	var fs := w.boss_fight
	for k in fs.hl_d_id.size():
		var j := drone_at(w, k)
		if j >= 0 and w.actors.state[j] == ORBIT:
			EnemyAi.enter_state(w.actors, j, S.MOVE)
	fs.clear_lattice_drones()


## The view's read (BossLens.state's "lattice"): {} with none cast or running; else "casting" (0..1000 through the
## cast, -1 once the web stands), "cast_left" (ticks), "running", "left" (ticks of the web left, 0 in the cast),
## "spin" (+1 or -1), "half_width" (a strand's), "strands" ([{"from", "to", "a", "b"}]: a and b the actor ids at its
## ends, the boss's own id at the boss), "drones" (the web's drones alive, in order: [{"id", "position"}]).
static func state(w: World, i: int, f: BossLensTable) -> Dictionary:
	var fs := w.boss_fight
	if not busy(w):
		return {}
	var casting := -1
	var cast_left := 0
	var left := 0
	if fs.hl_cast_from >= 0:
		casting = clampi((w.tick - fs.hl_cast_from) * 1000 / maxi(1, f.lat_cast_ticks), 0, 1000)
		cast_left = maxi(0, fs.hl_cast_from + f.lat_cast_ticks - w.tick)
	else:
		left = maxi(0, fs.hl_run_from + f.lat_ticks - w.tick)
	var lines: Array[Dictionary] = []
	for s: Array in strands(w, i):
		lines.append({"from": s[0], "to": s[1], "a": s[2], "b": s[3]})
	var web: Array[Dictionary] = []
	for k in fs.hl_d_id.size():
		var j := drone_at(w, k)
		if j >= 0:
			web.append({"id": fs.hl_d_id[k], "position": w.actors.pos(j)})
	return {
		"casting": casting,
		"cast_left": cast_left,
		"running": fs.hl_run_from >= 0,
		"left": left,
		"spin": fs.hl_spin,
		"half_width": f.strand_half_m,
		"strands": lines,
		"drones": web,
	}
