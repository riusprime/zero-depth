class_name BossSlag
extends RefCounted
## The Foundry's cooling slag and Overpressure (BossTable.forge; BossFightStore.slab_*, fg_over_*), run by BossForge.
## - Cooling slag, from slab_phase: one of the boss's burning pools (BossHazard) that is slab_cool_ticks old cools
##   into a slab where it lay: the pool goes (it burns no more and frees its place under the hazards' cap) and the slab
##   stays slab_ticks, then crumbles. A slab never hurts. The hero stands on one when its centre is inside it. So the
##   slabs never run out, a lane's pool lies nearer the room's centre (pool_spot) and, with nothing coming, a pool
##   drops where the hero stands (_drop).
## - The boss's vent blast (its `slam_ring` attack) shatters, as it strikes, the slab the hero stands on when that
##   slab's centre is inside the ring: it is no slab from then on (the row stays SHATTER_SHOW_TICKS for the view).
## - Overpressure, from over_phase: the first over_first_ticks into that phase, then every over_every_ticks (start to
##   start). It begins only when a slab is safe for its whole length (safe_slabs: whole, lasting to its end, and its
##   centre on cool floor of the meltdown as it will be then, the hero's width inside the edge); without one it waits
##   until one is, so it is never a hit that cannot be avoided. Its cast (over_cast_ticks) points
##   ObjectiveMarkers.FOUNDRY_SLAB at the nearest safe slab (kept on the nearest through the burn); then for
##   over_ticks the open floor burns: every over_step_ticks a hero off every slab loses over_hit per mille of max HP
##   (SafeArea STEP: never swallowed by the hurt invulnerability) and its scald gauge fills by scald_open.
## Pure: no stream is drawn.

## STATUS_APPLY effects (source the boss). SLAB_COOL: a pool cooled into a slab (pos its centre, amount its id,
## amount_applied the pool's id). SLAB_CRUMBLE: a slab's time is up (amount its id). SLAB_SHATTER: the vent blast
## broke the slab under the hero (amount its id). OVER_CAST: Overpressure's cast begins (pos = the nearest safe slab,
## amount = the cast's ticks). OVER_BURN: the open floor burns (amount = its ticks). OVER_END: it is over.
const SLAB_COOL := &"slab_cooled"
const SLAB_CRUMBLE := &"slab_crumbled"
const SLAB_SHATTER := &"slab_shattered"
const OVER_CAST := &"overpressure_cast"
const OVER_BURN := &"overpressure"
const OVER_END := &"overpressure_end"
## A pool dropped so the slabs never run out (pos its centre, amount its hazard id).
const SLAG_DROP := &"slag_drop"
## The damage effect id of the open floor's burn.
const OVER_EFFECT := &"boss_overpressure"
## A shattered slab's row stays this long for the view, then goes.
const SHATTER_SHOW_TICKS := 30


## BossForge.advance, tick phase 6: pools cool, slabs crumble or shatter, Overpressure runs.
static func advance(w: World, i: int, f: BossForgeTable, phase: int) -> void:
	if phase >= f.slab_phase:
		_cool(w, i, f)
		_drop(w, i, f)
	_crumble(w)
	_shatter(w, i)
	_overpressure(w, i, f, phase)


# --- slabs --------------------------------------------------------------------------------------------------------


## Boss i's burning pools slab_cool_ticks old become slabs.
static func _cool(w: World, i: int, f: BossForgeTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	var id := w.actors.ids[i]
	for k in range(bs.hz_x.size() - 1, -1, -1):
		if bs.hz_boss[k] != id or bs.hz_kind[k] != HazardTable.Kind.DAMAGE:
			continue
		if w.tick - bs.hz_from[k] < f.slab_cool_ticks:
			continue
		var c := Vector2(bs.hz_x[k], bs.hz_y[k])
		var pool := bs.hz_id[k]
		fs.slab_id.append(fs.fg_slab_next)
		fs.slab_boss.append(id)
		fs.slab_from.append(w.tick)
		fs.slab_until.append(w.tick + f.slab_ticks)
		fs.slab_broke.append(0)
		fs.slab_x.append(c.x)
		fs.slab_y.append(c.y)
		fs.slab_r.append(bs.hz_r[k])
		bs.remove_hazard(k)
		var e := BossForge.event(w, i, SLAB_COOL, c)
		e.amount = fs.fg_slab_next
		e.amount_applied = pool
		fs.fg_slab_next += 1


## With no pool of boss i's and no slab that will serve an Overpressure on the floor the meltdown leaves, and
## drop_ticks since its last, a pool drops where the hero stands (pulled onto that floor when the hero is on the
## melt), warned as every pool is: the slag that becomes the next slab, so the slabs never run out.
static func _drop(w: World, i: int, f: BossForgeTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	var h := BossAi.table_of(w, i).hazard
	if f.drop_ticks <= 0 or h == null or w.player_dead() or w.actors.state[i] == BossAi.GATE:
		return
	if fs.fg_drop_at >= 0 and w.tick - fs.fg_drop_at < f.drop_ticks:
		return
	var id := w.actors.ids[i]
	var margin := w.player.radius_m
	for k in bs.hz_x.size():
		if bs.hz_boss[k] == id and bs.hz_kind[k] == HazardTable.Kind.DAMAGE:
			if not _melted_at(w, Vector2(bs.hz_x[k], bs.hz_y[k]), 0, margin):
				return
	if not safe_slabs(w, f.over_cast_ticks + f.over_ticks).is_empty():
		return
	var p := w.player_pos()
	var ahead := f.slab_cool_ticks + f.over_cast_ticks + f.over_ticks  # The melt as its slab will need it
	for k in bs.melt_boss.size():
		var atk := BossLava.melt_attack(w, k)
		if atk == null:
			continue
		var c := Vector2(bs.melt_x[k], bs.melt_y[k])
		var r := BossLava.melt_radius(atk, bs.melt_r0[k], w.tick + ahead - bs.melt_from[k])
		var keep := maxf(0.0, r - 2.0 * margin)
		var off := p - c
		if Kin.length(off) > keep:
			p = c + off / maxf(Kin.length(off), 0.001) * keep
	fs.fg_drop_at = w.tick
	if BossHazard.place(w, i, p):
		BossForge.event(w, i, SLAG_DROP, p).amount = bs.hz_id[bs.hz_id.size() - 1]


## Slabs past their time crumble; a shattered slab's row goes after SHATTER_SHOW_TICKS.
static func _crumble(w: World) -> void:
	var bs := w.boss_fight
	for k in range(bs.slab_id.size() - 1, -1, -1):
		var broke := bs.slab_broke[k]
		if broke > 0:
			if w.tick - broke >= SHATTER_SHOW_TICKS:
				bs.remove_slab(k)
			continue
		if bs.slab_until[k] > w.tick:
			continue
		var bi := w.actors.index_of(bs.slab_boss[k])
		if bi >= 0:
			BossForge.event(w, bi, SLAB_CRUMBLE, slab_centre(bs, k)).amount = bs.slab_id[k]
		bs.remove_slab(k)


## On the tick boss i's slam ring strikes, the slab under the hero breaks if its centre is inside the ring.
static func _shatter(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] != EnemyAi.State.ACTIVE or a.state_t[i] != 0:
		return
	if BossAi.attack_of(w, i).move != BossAttackTable.Move.SLAM_RING:
		return
	var k := slab_under(w, w.player_pos())
	if k < 0:
		return
	var r := BossAi.ring_of(w, i)
	var bs := w.boss_fight
	var off := Kin.length(slab_centre(bs, k) - (r[0] as Vector2))
	if off < float(r[1]) or off > float(r[2]):
		return
	bs.slab_broke[k] = maxi(1, w.tick)
	BossForge.event(w, i, SLAB_SHATTER, slab_centre(bs, k)).amount = bs.slab_id[k]


## BossHazard.on_lanes: where a pool of radius r on lane piece `piece` goes: its middle; for a boss whose forge cools
## its pools (from slab_phase), the spot of the piece nearest the room's centre where the pool still fits along it, so
## its slab lies on the floor the meltdown leaves.
static func pool_spot(w: World, i: int, piece: Rect2, r: float) -> Vector2:
	var c := piece.get_center()
	var f := BossAi.table_of(w, i).forge
	if f == null or w.bosses.phase[BossAi.entry_of(w, i)] < f.slab_phase:
		return c
	var to := BossLava.room_centre(w, i)
	var lo := piece.position + Vector2(r, r)
	var hi := piece.end - Vector2(r, r)
	var x := clampf(to.x, lo.x, hi.x) if lo.x <= hi.x else c.x
	var y := clampf(to.y, lo.y, hi.y) if lo.y <= hi.y else c.y
	return Vector2(x, y)


static func slab_centre(bs: BossFightStore, k: int) -> Vector2:
	return Vector2(bs.slab_x[k], bs.slab_y[k])


## The whole slab p stands on (its centre inside it; the oldest first), or -1.
static func slab_under(w: World, p: Vector2) -> int:
	var bs := w.boss_fight
	for k in bs.slab_id.size():
		if bs.slab_broke[k] == 0 and Kin.length(slab_centre(bs, k) - p) <= bs.slab_r[k]:
			return k
	return -1


## The whole slabs safe to stand on until `ahead` ticks from now: lasting that long, and their centre the hero's
## width inside the cool floor every meltdown will have left then.
static func safe_slabs(w: World, ahead: int) -> PackedInt32Array:
	var bs := w.boss_fight
	var out := PackedInt32Array()
	for k in bs.slab_id.size():
		if bs.slab_broke[k] != 0 or bs.slab_until[k] < w.tick + ahead:
			continue
		if _melted_at(w, slab_centre(bs, k), ahead, w.player.radius_m):
			continue
		out.append(k)
	return out


## True when p (grown by `margin`) is on a meltdown's melt `ahead` ticks from now, or outside the boss room (an
## outer lane's pool can lie past its walls).
static func _melted_at(w: World, p: Vector2, ahead: int, margin: float) -> bool:
	var bs := w.bosses
	if bs.arena.has_area() and not bs.arena.grow(-margin).has_point(p):
		return true
	for k in bs.melt_boss.size():
		var atk := BossLava.melt_attack(w, k)
		if atk == null:
			continue
		var c := Vector2(bs.melt_x[k], bs.melt_y[k])
		var bound := bs.arena
		if not bound.has_area():
			bound = Rect2(
				c - Vector2.ONE * BossLava.OPEN_REACH_M, Vector2.ONE * BossLava.OPEN_REACH_M * 2.0
			)
		var m := [
			c,
			BossLava.melt_radius(atk, bs.melt_r0[k], w.tick + ahead - bs.melt_from[k]),
			bs.melt_exit[k] == 1,
			Vector2(bs.melt_ex[k], bs.melt_ey[k]),
			atk.ford_m * 0.5,
			bound
		]
		if BossLava.melt_covers(m, p, margin):
			return true
	return false


## The nearest to the hero of slabs `ks`, or -1.
static func nearest(w: World, ks: PackedInt32Array) -> int:
	var best := -1
	var best_d := INF
	var p := w.player_pos()
	for k in ks:
		var d := Kin.length(slab_centre(w.boss_fight, k) - p)
		if d < best_d:
			best = k
			best_d = d
	return best


# --- Overpressure -------------------------------------------------------------------------------------------------


static func _overpressure(w: World, i: int, f: BossForgeTable, phase: int) -> void:
	var bs := w.boss_fight
	if phase < f.over_phase:
		return
	if bs.fg_over_due < 0:
		bs.fg_over_due = w.tick + f.over_first_ticks
	if bs.fg_over_from < 0:
		if w.tick < bs.fg_over_due or w.actors.state[i] == BossAi.GATE:
			return
		var safe := safe_slabs(w, f.over_cast_ticks + f.over_ticks)
		if safe.is_empty():
			return  # It waits for a slab: never a burn with nowhere to stand
		bs.fg_over_from = w.tick
		bs.fg_over_step = -1
		bs.fg_over_due = w.tick + f.over_every_ticks
		var c := _point(w, safe)
		BossForge.event(w, i, OVER_CAST, c).amount = f.over_cast_ticks
		return
	var burn_at := bs.fg_over_from + f.over_cast_ticks
	var s := w.tick - burn_at
	_point(w, safe_slabs(w, maxi(0, f.over_ticks - maxi(0, s))))
	if s < 0:
		return
	if bs.fg_over_step < 0:  # The burn begins (on a later tick when a hit's freeze held this one)
		bs.fg_over_step = burn_at + f.over_step_ticks
		BossForge.event(w, i, OVER_BURN, w.actors.pos(i)).amount = f.over_ticks
	# A step a hit's freeze held back is paid on the first tick after it, so none is lost
	if w.tick >= bs.fg_over_step and bs.fg_over_step <= burn_at + f.over_ticks:
		bs.fg_over_step += f.over_step_ticks
		if slab_under(w, w.player_pos()) < 0:
			SafeArea.hurt(w, i, f.over_hit, SafeArea.Mode.STEP, f.over_cause, OVER_EFFECT)
			if phase >= f.scald_phase and not w.player_dead():
				BossForge.set_scald(w, i, f, bs.fg_scald + f.scald_open)
	if s >= f.over_ticks and bs.fg_over_step > burn_at + f.over_ticks:
		_end(w, i)


## The marker on the nearest of slabs `ks` (none when there is none). Returns that slab's centre (the boss's spot
## without one).
static func _point(w: World, ks: PackedInt32Array) -> Vector2:
	w.objectives.clear(ObjectiveMarkers.FOUNDRY_SLAB)
	var k := nearest(w, ks)
	if k < 0:
		return w.player_pos()
	var c := slab_centre(w.boss_fight, k)
	w.objectives.point(ObjectiveMarkers.FOUNDRY_SLAB, c)
	return c


static func _end(w: World, i: int) -> void:
	w.boss_fight.fg_over_from = -1
	w.objectives.clear(ObjectiveMarkers.FOUNDRY_SLAB)
	if i >= 0:
		BossForge.event(w, i, OVER_END, w.actors.pos(i))


## BossForge.cancel: an Overpressure running ends (its clock stays).
static func cancel(w: World, i: int) -> void:
	if w.boss_fight.fg_over_from >= 0:
		_end(w, i)


# --- the view's read (BossForge.state) ----------------------------------------------------------------------------


## The cooling pools (from slab_phase) and the slabs, each {"slab" (false: a pool still cooling), "id" (the pool's
## hazard id, or the slab's), "centre", "radius", "cooling" (0..1000 toward a slab; 1000 for a slab), "left" (ticks
## until it crumbles; -1 while cooling), "shattered", "safe" (a whole slab Overpressure counts now)}.
static func rows(w: World, i: int, f: BossForgeTable) -> Array:
	var bs := w.bosses
	var fs := w.boss_fight
	var out := []
	var phase := bs.phase[BossAi.entry_of(w, i)]
	var id := w.actors.ids[i]
	if phase >= f.slab_phase:
		for k in bs.hz_x.size():
			if bs.hz_boss[k] != id or bs.hz_kind[k] != HazardTable.Kind.DAMAGE:
				continue
			var age := w.tick - bs.hz_from[k]
			(
				out
				. append(
					{
						"slab": false,
						"id": bs.hz_id[k],
						"centre": Vector2(bs.hz_x[k], bs.hz_y[k]),
						"radius": bs.hz_r[k],
						"cooling": clampi(age * 1000 / maxi(1, f.slab_cool_ticks), 0, 1000),
						"left": -1,
						"shattered": false,
						"safe": false,
					}
				)
			)
	var ahead := f.over_cast_ticks + f.over_ticks  # A whole Overpressure; the rest of one running
	if fs.fg_over_from >= 0:
		ahead = maxi(0, fs.fg_over_from + ahead - w.tick)
	var safe := safe_slabs(w, ahead)
	for k in fs.slab_id.size():
		(
			out
			. append(
				{
					"slab": true,
					"id": fs.slab_id[k],
					"centre": slab_centre(fs, k),
					"radius": fs.slab_r[k],
					"cooling": 1000,
					"left": maxi(0, fs.slab_until[k] - w.tick),
					"shattered": fs.slab_broke[k] != 0,
					"safe": safe.has(k),
				}
			)
		)
	return out


## {} with no Overpressure running; else "cast" (0..1000 through the cast, -1 once the floor burns), "cast_left"
## (ticks), "burn" (0..1000 through the burn, -1 before), "burn_left" (ticks), "on_slab" (the hero stands on one).
static func over_state(w: World, f: BossForgeTable) -> Dictionary:
	var bs := w.boss_fight
	if bs.fg_over_from < 0:
		return {}
	var t := w.tick - bs.fg_over_from
	var s := t - f.over_cast_ticks
	return {
		"cast": clampi(t * 1000 / maxi(1, f.over_cast_ticks), 0, 1000) if s < 0 else -1,
		"cast_left": maxi(0, -s),
		"burn": clampi(s * 1000 / maxi(1, f.over_ticks), 0, 1000) if s >= 0 else -1,
		"burn_left": f.over_ticks - maxi(0, s),
		"on_slab": slab_under(w, w.player_pos()) >= 0,
	}
