class_name BossLava
extends RefCounted
## v0.8.0 BS2 (owner O5; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md S6, approved 2026-10-14; SIM_CONTRACTS §10f): the
## Foundry's floor is lava.
## - Molten floor: a `row_flood` attack with lava_ticks leaves its lanes molten where they struck, from the tick after
##   their last standing tick, for lava_ticks: a player standing in it (their centre) takes lava_damage once every
##   lava_burn_ticks, and the flow field goes round it (NavField.set_extra), so enemies path round it. Every lane is
##   cut by fords ford_m wide: at the boss's x and where the way from the room's centre to its exit crosses the lane.
##   Fair: the lava is laid only if, with it (and any other molten floor) down, the free floor still joins the boss to
##   the player and to an exit (fair(): a flood over the field's cells); if not, none of it is laid.
## - The meltdown: a `melt` attack (the Foundry's phase-3 entry; its windup is a roar while the outer ring glows)
##   melts, on its first active tick and for good, the room's outer melt_ring_m: the floor farther from the room's
##   centre than its inscribed radius less melt_ring_m; every melt_step_ticks it melts melt_step_m closer (each step
##   glows melt_warn_ticks first), never closer than melt_min_m.
##   A bridge ford_m wide from the centre to the room's exit stays cool. It burns the attack's damage once every
##   burn_ticks; enemies path round it; the Foundry itself keeps to the cool ground (keep_on_ground).
## Both burn on one clock (BossStore.burn_cd); damage over time from the boss (Damage.tick_dot: the player's hurt
## iframes apply). A boss gone, its lava and melt go. Pure: no stream is drawn here.

## A melt's shape (melt_shape): [centre, radius now, has an exit, the exit point, the bridge's half width, bound].
const MELT_CENTRE := 0
const MELT_R := 1
const MELT_HAS_EXIT := 2
const MELT_EXIT := 3
const MELT_HALF := 4
const MELT_BOUND := 5
## How far into the room from its door the exit point is (m).
const EXIT_DEPTH_M := 1.0
## The fairness flood counts the boss reached from the free cells this close to its edge, and the player from those
## within its radius + this.
const BOSS_REACH_M := 1.0
const PLAYER_REACH_M := 1.6
## Without a room (the playground's stage): the melt's and the flood's reach around the boss (m).
const OPEN_REACH_M := 24.0
## A lava piece shorter than this after its fords is left out.
const MIN_PIECE_M := 0.1

# --- molten floor -------------------------------------------------------------------------------------------------


## Tick phase 6, the last standing tick of boss i's `row_flood` (BossAi.resolve): its lanes stay molten, cut by
## their fords, if that leaves a way. Returns how many pieces were laid.
static func lay(w: World, i: int, atk: BossAttackTable) -> int:
	if atk.lava_ticks <= 0:
		return 0
	var pieces: Array[Rect2] = []
	for k in atk.count:
		var r := BossDodge.row_flood_of(w, i, k).bounds()
		pieces.append_array(_cut(r, _fords(w, i, r.get_center().y), atk.ford_m * 0.5))
	if pieces.is_empty() or not fair(w, i, pieces):
		return 0
	var bs := w.bosses
	var t := BossAi.entry_of(w, i)
	for r in pieces:
		bs.lava_x.append(r.get_center().x)
		bs.lava_y.append(r.get_center().y)
		bs.lava_hx.append(r.size.x * 0.5)
		bs.lava_hy.append(r.size.y * 0.5)
		bs.lava_from.append(w.tick + 1)
		bs.lava_until.append(w.tick + 1 + atk.lava_ticks)
		bs.lava_boss.append(w.actors.ids[i])
		bs.lava_attack.append(bs.attack[t])
	BossSignatures.set_nav_extra(w)
	return pieces.size()


## Where a lane at height y is forded: the boss's x, and where the way from the room's centre to its exit crosses y
## (the exit's own x when the way doesn't cross it).
static func _fords(w: World, i: int, y: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([w.actors.pos(i).x])
	var ex := exits(w)
	if ex.is_empty():
		return out
	var c := room_centre(w, i)
	var e := ex[0]
	var lo := minf(c.y, e.y)
	var hi := maxf(c.y, e.y)
	if y >= lo and y <= hi and absf(e.y - c.y) > 0.001:
		out.append(c.x + (e.x - c.x) * (y - c.y) / (e.y - c.y))
	else:
		out.append(e.x)
	return out


## Rect r with the strips [x - half, x + half] of every ford taken out, as pieces left to right.
static func _cut(r: Rect2, fords: PackedFloat32Array, half: float) -> Array[Rect2]:
	var spans: Array[Vector2] = [Vector2(r.position.x, r.end.x)]
	for x in fords:
		var next: Array[Vector2] = []
		for s in spans:
			if x + half <= s.x or x - half >= s.y:
				next.append(s)
				continue
			if x - half > s.x:
				next.append(Vector2(s.x, x - half))
			if x + half < s.y:
				next.append(Vector2(x + half, s.y))
		spans = next
	var out: Array[Rect2] = []
	for s in spans:
		if s.y - s.x >= MIN_PIECE_M:
			out.append(Rect2(s.x, r.position.y, s.y - s.x, r.size.y))
	return out


## True when, with `extra` laid on top of the molten floor already down, a lava-free way joins the boss (its edge) to
## the player and to an exit (when the room has one): a flood over the flow field's free cells that keep the hero's
## radius from all molten floor, inside the room. No field (no walls): always.
static func fair(w: World, i: int, extra: Array[Rect2]) -> bool:
	var nav := w.nav
	if nav.size == Vector2i.ZERO:
		return true
	var pr := w.player.radius_m
	var lava := rects(w)
	lava.append_array(extra)
	var bound := _bound_cells(w, i)
	var avoid := PackedByteArray()
	avoid.resize(nav.size.x * nav.size.y)
	avoid.fill(0)
	var melts := melt_shapes(w)
	for y in range(bound.position.y, bound.end.y):
		for x in range(bound.position.x, bound.end.x):
			var p := nav.center(Vector2i(x, y))
			for r in lava:
				if r.grow(pr).has_point(p):
					avoid[y * nav.size.x + x] = 1
					break
			for m: Array in melts:
				if melt_covers(m, p, pr):
					avoid[y * nav.size.x + x] = 1
	var boss := w.actors.pos(i)
	var starts := _cells_near(nav, boss, w.actors.radius[i] + BOSS_REACH_M, bound)
	var seen := nav.reach(starts, avoid, bound)
	if not _reached_near(nav, seen, w.player_pos(), pr + PLAYER_REACH_M, bound):
		return false
	var ex := exits(w)
	return ex.is_empty() or _reached_near(nav, seen, ex[0], EXIT_DEPTH_M, bound)


## The field's cells the fairness flood keeps to: the boss room's (its arena), else OPEN_REACH_M round the boss.
static func _bound_cells(w: World, i: int) -> Rect2i:
	var r := w.bosses.arena
	if not r.has_area():
		var c := w.actors.pos(i)
		r = Rect2(c - Vector2.ONE * OPEN_REACH_M, Vector2.ONE * OPEN_REACH_M * 2.0)
	var c0 := w.nav.cell_of(r.position)
	var c1 := w.nav.cell_of(r.end)
	c0 = Vector2i(maxi(c0.x, 0), maxi(c0.y, 0))
	c1 = Vector2i(mini(c1.x, w.nav.size.x - 1), mini(c1.y, w.nav.size.y - 1))
	return Rect2i(c0, c1 - c0 + Vector2i.ONE)


static func _cells_near(nav: NavField, p: Vector2, d: float, bound: Rect2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c0 := nav.cell_of(p - Vector2.ONE * d)
	var c1 := nav.cell_of(p + Vector2.ONE * d)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c := Vector2i(x, y)
			if bound.has_point(c) and Kin.length(nav.center(c) - p) <= d:
				out.append(y * nav.size.x + x)
	return out


static func _reached_near(
	nav: NavField, seen: PackedByteArray, p: Vector2, d: float, bound: Rect2i
) -> bool:
	for k in _cells_near(nav, p, d, bound):
		if seen[k] == 1:
			return true
	return false


## The molten floor down now, as rects.
static func rects(w: World) -> Array[Rect2]:
	var bs := w.bosses
	var out: Array[Rect2] = []
	for k in bs.lava_x.size():
		out.append(lava_rect(bs, k))
	return out


static func lava_rect(bs: BossStore, k: int) -> Rect2:
	var h := Vector2(bs.lava_hx[k], bs.lava_hy[k])
	return Rect2(Vector2(bs.lava_x[k], bs.lava_y[k]) - h, h * 2.0)


## The molten floor as boxes, for the flow field.
static func lava_obbs(w: World) -> Array[Obb]:
	var bs := w.bosses
	var out: Array[Obb] = []
	for k in bs.lava_x.size():
		out.append(
			Obb.make(Vector2(bs.lava_x[k], bs.lava_y[k]), Vector2(bs.lava_hx[k], bs.lava_hy[k]), 0)
		)
	return out


# --- the meltdown -------------------------------------------------------------------------------------------------


## Tick phase 6, the first active tick of boss i's `melt` attack: the outer ring melts for good, round the room's
## centre, with a cool bridge to the exit nearest it. A boss melts its room once (a second melt does nothing).
static func begin_melt(w: World, i: int) -> void:
	var bs := w.bosses
	var id := w.actors.ids[i]
	if bs.melt_boss.has(id):
		return
	var c := room_centre(w, i)
	var ex := exits(w)
	var atk := BossAi.attack_of(w, i)
	bs.melt_boss.append(id)
	bs.melt_attack.append(bs.attack[BossAi.entry_of(w, i)])
	bs.melt_from.append(w.tick)
	bs.melt_r0.append(first_radius(w, atk))
	bs.melt_x.append(c.x)
	bs.melt_y.append(c.y)
	bs.melt_ex.append(ex[0].x if not ex.is_empty() else c.x)
	bs.melt_ey.append(ex[0].y if not ex.is_empty() else c.y)
	bs.melt_exit.append(0 if ex.is_empty() else 1)
	BossSignatures.set_nav_extra(w)


## The radius a melt first melts to: the room's inscribed radius less its ring (OPEN_REACH_M's without a room), never
## under its minimum.
static func first_radius(w: World, atk: BossAttackTable) -> float:
	var r := w.bosses.arena
	var inner := minf(r.size.x, r.size.y) * 0.5 if r.has_area() else OPEN_REACH_M
	return maxf(atk.melt_min_m, inner - atk.melt_ring_m)


## The room's centre (the sealed boss room's interior), or where boss i stands without one.
static func room_centre(w: World, i: int) -> Vector2:
	var r := w.bosses.arena
	return r.get_center() if r.has_area() else w.actors.pos(i)


## The boss room's exits as points EXIT_DEPTH_M inside its door (empty without a floor's boss room).
static func exits(w: World) -> PackedVector2Array:
	var f := w.floor_layout
	if f == null or f.boss_room < 0 or f.boss_door_index < 0 or not w.bosses.arena.has_area():
		return PackedVector2Array()
	return PackedVector2Array([f.boss_door_inside(EXIT_DEPTH_M)])


## Meltdown k's attack (null when its boss is gone).
static func melt_attack(w: World, k: int) -> BossAttackTable:
	var bi := w.actors.index_of(w.bosses.melt_boss[k])
	if bi < 0:
		return null
	var t := BossAi.table_of(w, bi)
	var a := w.bosses.melt_attack[k]
	return t.attacks[a] if a >= 0 and a < t.attacks.size() else null


## A melt's radius `ticks` after it began at r0: melt_step_m less every melt_step_ticks, never under melt_min_m.
static func melt_radius(atk: BossAttackTable, r0: float, ticks: int) -> float:
	var steps := ticks / maxi(1, atk.melt_step_ticks)
	return maxf(atk.melt_min_m, r0 - atk.melt_step_m * steps)


## Each meltdown's shape now (MELT_*), for the field, the burn and the views.
static func melt_shapes(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.melt_boss.size():
		var atk := melt_attack(w, k)
		if atk == null:
			continue
		var c := Vector2(bs.melt_x[k], bs.melt_y[k])
		var bound := w.bosses.arena
		if not bound.has_area():
			bound = Rect2(c - Vector2.ONE * OPEN_REACH_M, Vector2.ONE * OPEN_REACH_M * 2.0)
		out.append(
			[
				c,
				melt_radius(atk, bs.melt_r0[k], w.tick - bs.melt_from[k]),
				bs.melt_exit[k] == 1,
				Vector2(bs.melt_ex[k], bs.melt_ey[k]),
				atk.ford_m * 0.5,
				bound
			]
		)
	return out


## True when point p is in melt shape m, grown by `margin` (0: the burn's own test of the player's centre): farther
## than its radius from the centre, inside its bound, and off its cool bridge.
static func melt_covers(m: Array, p: Vector2, margin: float) -> bool:
	var c: Vector2 = m[MELT_CENTRE]
	if Kin.length(p - c) <= float(m[MELT_R]) - margin:
		return false
	if not (m[MELT_BOUND] as Rect2).has_point(p):
		return false
	if not bool(m[MELT_HAS_EXIT]):
		return true
	return _to_segment(p, c, m[MELT_EXIT]) > float(m[MELT_HALF]) - margin


## The distance from p to the segment a..b.
static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var d := b - a
	var len2 := d.dot(d)
	var f := 0.0 if len2 <= 0.0 else clampf((p - a).dot(d) / len2, 0.0, 1.0)
	return Kin.length(p - (a + d * f))


## BossAi.move, after the boss walked: the Foundry keeps to the cool ground of its own melt (its centre at least its
## radius inside the edge).
static func keep_on_ground(w: World, i: int) -> void:
	var bs := w.bosses
	var k := bs.melt_boss.find(w.actors.ids[i])
	if k < 0:
		return
	var atk := melt_attack(w, k)
	if atk == null:
		return
	var c := Vector2(bs.melt_x[k], bs.melt_y[k])
	var keep := melt_radius(atk, bs.melt_r0[k], w.tick - bs.melt_from[k]) - w.actors.radius[i]
	var to := w.actors.pos(i) - c
	var d := Kin.length(to)
	if keep > 0.0 and d > keep:
		w.actors.set_pos(i, c + to * (keep / d))


## Boss i's melt attack winding up (WorldReader.boss_melts): the ring that will melt, glowing with the windup.
static func melt_windup(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var c := room_centre(w, i)
	var ex := exits(w)
	var bound := w.bosses.arena
	if not bound.has_area():
		bound = Rect2(c - Vector2.ONE * OPEN_REACH_M, Vector2.ONE * OPEN_REACH_M * 2.0)
	return {
		"centre": c,
		"radius": INF,
		"next": first_radius(w, atk),
		"warn": clampi(w.actors.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000),
		"bound": bound,
		"bridge": not ex.is_empty(),
		"exit": ex[0] if not ex.is_empty() else c,
		"half": atk.ford_m * 0.5,
	}


## Meltdown k's next step: [the radius it melts to next, 0..1000 of its warning glow (-1 when not glowing)]; the
## radius stays when it is at its minimum.
static func melt_warn(w: World, k: int) -> Array:
	var atk := melt_attack(w, k)
	if atk == null:
		return [0.0, -1]
	var t := w.tick - w.bosses.melt_from[k]
	var step := maxi(1, atk.melt_step_ticks)
	var r0 := w.bosses.melt_r0[k]
	var now := melt_radius(atk, r0, t)
	var next := melt_radius(atk, r0, (t / step + 1) * step)
	var into := t % step
	var lead := step - atk.melt_warn_ticks
	if next >= now or into < lead:
		return [next, -1]
	return [next, clampi((into - lead) * 1000 / maxi(1, atk.melt_warn_ticks), 0, 1000)]


# --- the tick -----------------------------------------------------------------------------------------------------


## Tick phase 6 (BossSignatures.advance): molten floor whose time is up cools, a melt that stepped closer refreshes
## the field, and molten floor under the player burns.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.lava_x.is_empty() and bs.melt_boss.is_empty():
		bs.burn_cd = 0
		return
	if bs.burn_cd > 0:
		bs.burn_cd -= 1
	var changed := false
	for k in range(bs.lava_x.size() - 1, -1, -1):
		if bs.lava_until[k] <= w.tick:
			bs.remove_lava(k)
			changed = true
	for k in bs.melt_boss.size():
		var atk := melt_attack(w, k)
		var t := w.tick - bs.melt_from[k]
		if atk != null and t > 0 and t % maxi(1, atk.melt_step_ticks) == 0:
			var r0 := bs.melt_r0[k]
			changed = changed or melt_radius(atk, r0, t) < melt_radius(atk, r0, t - 1)
	if changed:
		BossSignatures.set_nav_extra(w)
	_burn(w)


## Molten floor under the player's centre burns once per its period (lava first, then a melt).
static func _burn(w: World) -> void:
	var bs := w.bosses
	if bs.burn_cd > 0 or w.player_dead():
		return
	var p := w.player_pos()
	for k in bs.lava_x.size():
		if bs.lava_from[k] <= w.tick and lava_rect(bs, k).has_point(p):
			var bi := w.actors.index_of(bs.lava_boss[k])
			var t := BossAi.table_of(w, bi) if bi >= 0 else null
			var a := bs.lava_attack[k]
			if t == null or a < 0 or a >= t.attacks.size():
				continue
			var atk := t.attacks[a]
			_hurt(w, bi, atk.lava_damage, atk.lava_burn_ticks, BossSignatures.LATE_CAUSE + a)
			return
	var shapes := melt_shapes(w)
	for k in shapes.size():
		if melt_covers(shapes[k], p, 0.0):
			var bi := w.actors.index_of(bs.melt_boss[k])
			var atk := melt_attack(w, k)
			if bi >= 0 and atk != null:
				_hurt(w, bi, atk.damage, atk.burn_ticks, bs.melt_attack[k])
				return


static func _hurt(w: World, bi: int, amount: int, period: int, cause: int) -> void:
	w.bosses.burn_cd = maxi(1, period)
	var id := w.actors.ids[bi]
	Damage.tick_dot(w, 0, BossAi.powered(w, bi, amount), id, id, &"molten_floor")
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = cause


## Removes boss `boss_id`'s lava and melt (it is gone). Returns true when any went.
static func on_boss_gone(w: World, boss_id: int) -> bool:
	var bs := w.bosses
	var any := false
	for k in range(bs.lava_x.size() - 1, -1, -1):
		if bs.lava_boss[k] == boss_id:
			bs.remove_lava(k)
			any = true
	for k in range(bs.melt_boss.size() - 1, -1, -1):
		if bs.melt_boss[k] == boss_id:
			bs.remove_melt(k)
			any = true
	return any
