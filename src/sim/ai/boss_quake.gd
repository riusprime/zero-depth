class_name BossQuake
extends RefCounted
## v0.11.0 O3 (owner L5: "two or three pillars … earthquake-like pulses and small ongoing damage … use the boss's
## existing cross/spike attack against those pillars"; Q9 a: "boss takes more damage during the stun, this should
## happen at most 2 times per phase"): the Gatekeeper's quake pillars (BossTable.quake, a QuakeTable).
## - Rise: as phase from_phase begins (and each later phase), pillars rise until `count` stand: each on open floor
##   drawn from the ai stream inside the boss room (BossStore.arena; round the boss when there is none), only where
##   it fits as S1 pillars do (BossSignatures.fits: never on or touching a body, the hero's width from every wall and
##   pillar, so it is an island and never closes a way), wall_m of clear floor round it, gap_m from the other quake
##   pillars and boss_m from the boss's edge. They are S1 pillars (walls, in the flow field, snapshotted) that never
##   sink by time: their pillar_until is UNTIL.
## - Pulse: every pulse_ticks after it rose a pillar pulses: a player within ring_m of its centre takes
##   damage_permille of their max HP, damage over time from the boss (EFFECT; the recap's line is the table's
##   cause_key, BossCauses). The ring grows over the warn_ticks before (ring_state, the view's telegraph; EI-07).
## - Shatter: a Shock Lanes strike (BossDodge.resolve_marks, a row_lanes attack) shatters every quake pillar its lanes
##   run into (lanes_strike: the very clear_run the lane is drawn and hit with stops at the pillar). The first
##   stuns_per_phase breaks of a phase stun the boss stun_ticks (BossAi.STAGGERED, its old reel; its attack ends) and
##   it takes stun_permille of every hit meanwhile (taken_permille); a later break only removes the pillar.
## - The hint: every standing quake pillar is an objective (ObjectiveMarkers.GATEKEEPER_PILLAR) while it stands.
## No immunity window is added. Pure: the ai stream only (the placement).

## A quake pillar's pillar_until: it never sinks by time.
const UNTIL := 1 << 30
## World.killer_attack for a pulse that kills (BossCauses.key).
const ATTACK := -3
## The DAMAGE effect of a pulse (ReadableCause, the views).
const EFFECT := &"quake_pulse"
## STATUS_APPLY effects: a pillar shatters (at the pillar, amount 1 when it stunned), the boss is stunned (amount =
## the stun's ticks).
const SHATTER := &"quake_shatter"
const STUN := &"quake_stun"
## Candidate spots drawn per pillar before giving up on it.
const TRIES := 48
## A lane that stops this close to a quake pillar ran into it (the sweep's rounding).
const REACH_SLACK_M := 0.02
## Round the boss when the fight has no room (a test world): this far each way.
const NO_ROOM_HALF_M := 9.0


static func is_quake(bs: BossStore, k: int) -> bool:
	return bs.pillar_until[k] >= UNTIL


## The quake pillars of boss `boss_id` (indices into the pillar lists).
static func pillars_of(w: World, boss_id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var bs := w.bosses
	for k in bs.pillar_x.size():
		if is_quake(bs, k) and bs.pillar_boss[k] == boss_id:
			out.append(k)
	return out


static func center(bs: BossStore, k: int) -> Vector2:
	return Vector2(bs.pillar_x[k], bs.pillar_y[k])


# --- the rise (BossAi._update_phase) -----------------------------------------------------------------------------


## BossAi._update_phase: boss i (entry b, table t) has just begun phase `phase`: from the table's from_phase on, its
## break count starts again and pillars rise until `count` stand. Returns how many rose.
static func on_phase(w: World, i: int, t: BossTable, phase: int) -> int:
	var q := t.quake
	if q == null or phase < q.from_phase:
		return 0
	var bs := w.bosses
	var id := w.actors.ids[i]
	var e := bs.quake_of(id)
	if e < 0:
		bs.quake_boss.append(id)
		bs.quake_phase.append(phase)
		bs.quake_stuns.append(0)
	else:
		bs.quake_phase[e] = phase
		bs.quake_stuns[e] = 0
	var n := 0
	for k in q.count - pillars_of(w, id).size():
		if _raise(w, i, q):
			n += 1
	if n > 0:
		BossSignatures.set_nav_extra(w)
	_point(w, id)
	return n


static func _raise(w: World, i: int, q: QuakeTable) -> bool:
	var area := _area(w, i)
	var inset := q.half_m + q.wall_m
	var span := area.size - Vector2(inset, inset) * 2.0
	if span.x < 0.0 or span.y < 0.0:
		return false
	var sx := int(span.x * 100.0)
	var sy := int(span.y * 100.0)
	for k in TRIES:
		var p := (
			area.position
			+ Vector2(inset, inset)
			+ Vector2(w.rng_ai.range_int(0, sx), w.rng_ai.range_int(0, sy)) * 0.01
		)
		if _open(w, i, q, p):
			BossSignatures.add_pillar(w, w.actors.ids[i], p, q.half_m, UNTIL - w.tick)
			return true
	return false


## The floor the pillars rise on: the boss room's interior, or a square round the boss without one.
static func _area(w: World, i: int) -> Rect2:
	var room := w.bosses.arena
	if room.has_area():
		return room
	var c := w.actors.pos(i)
	var h := NO_ROOM_HALF_M
	return Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)


## True when a quake pillar fits at p: as an S1 pillar, with wall_m of clear floor round it, gap_m from the other
## quake pillars and boss_m from the boss's edge.
static func _open(w: World, i: int, q: QuakeTable, p: Vector2) -> bool:
	if Kin.length(p - w.actors.pos(i)) < w.actors.radius[i] + q.boss_m + q.half_m:
		return false
	var bs := w.bosses
	for k in bs.pillar_x.size():
		if is_quake(bs, k) and Kin.length(center(bs, k) - p) < q.gap_m:
			return false
	if not EnemyAi.clear_of_walls(w, p, q.half_m * 1.4143 + q.wall_m):
		return false
	return BossSignatures.fits(w, p, q.half_m)


# --- the pulses (tick phase 6, BossSignatures.advance) ----------------------------------------------------------


## Tick phase 6: each quake pillar whose pulse is due now hurts a player inside its ring.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.quake_boss.is_empty() or w.player_dead():
		return
	for k in bs.pillar_x.size():
		if not is_quake(bs, k):
			continue
		var bi := w.actors.index_of(bs.pillar_boss[k])
		if bi < 0 or w.actors.dead[bi] == 1:
			continue
		var q := BossAi.table_of(w, bi).quake
		if q == null or not pulses_now(w, q, k):
			continue
		if AttackShapes.disc_touches(center(bs, k), q.ring_m, w.player_pos(), w.player.radius_m):
			var dmg := maxi(1, w.actors.max_hp[0] * q.damage_permille / 1000)
			var id := bs.pillar_boss[k]
			Damage.tick_dot(w, 0, dmg, id, id, EFFECT)
			if w.player_dead() and w.killer_attack < 0:
				w.killer_attack = ATTACK
				return


## True on the ticks pillar k pulses: every pulse_ticks after it rose.
static func pulses_now(w: World, q: QuakeTable, k: int) -> bool:
	var age := w.tick - w.bosses.pillar_from[k]
	return age > 0 and age % q.pulse_ticks == 0


## Pillar k's ring now, for the views (the same centre, radius and clock the pulse hits with, EI-07): {"center",
## "half", "ring" (m), "warn" (0..1000 of the ring's growth over its warn_ticks, -1 outside them), "pulse" (0..1000
## through its pulse period), "struck" (true on a pulse tick), "rose", "pulse_ticks", "warn_ticks"}.
static func ring_state(w: World, q: QuakeTable, k: int) -> Dictionary:
	var bs := w.bosses
	var age := w.tick - bs.pillar_from[k]
	var into := posmod(age, q.pulse_ticks)
	var left := q.pulse_ticks - into
	var warn := -1
	if age > 0 and into == 0:
		warn = 1000
	elif left <= q.warn_ticks:
		warn = clampi((q.warn_ticks - left) * 1000 / maxi(1, q.warn_ticks), 0, 1000)
	return {
		"center": center(bs, k),
		"half": bs.pillar_h[k],
		"ring": q.ring_m,
		"warn": warn,
		"pulse": clampi(into * 1000 / q.pulse_ticks, 0, 1000),
		"struck": pulses_now(w, q, k),
		"rose": bs.pillar_from[k],
		"pulse_ticks": q.pulse_ticks,
		"warn_ticks": q.warn_ticks,
	}


## Every standing quake pillar's ring_state (WorldReader.boss_quake_pillars).
static func view(w: World) -> Array:
	var out := []
	var bs := w.bosses
	if bs.quake_boss.is_empty():
		return out
	for k in bs.pillar_x.size():
		if not is_quake(bs, k):
			continue
		var bi := w.actors.index_of(bs.pillar_boss[k])
		if bi < 0:
			continue
		var q := BossAi.table_of(w, bi).quake
		if q != null:
			out.append(ring_state(w, q, k))
	return out


# --- the shatter (BossDodge.resolve_marks) -----------------------------------------------------------------------


## Tick phase 6, the strike tick of marker k of boss i's row_lanes attack: every quake pillar of the boss its four
## lanes run into shatters (each lane stops at the first wall along it, as row_lanes_of draws and hits it). Returns
## how many shattered.
static func lanes_strike(w: World, i: int, k: int, atk: BossAttackTable) -> int:
	var bs := w.bosses
	var id := w.actors.ids[i]
	var mine := pillars_of(w, id)
	if mine.is_empty():
		return 0
	var c := BossDodge.mark_of(w, i, k)
	var reach := atk.length_m * 0.5
	var hit := PackedInt32Array()
	for way in [0, 1024, 2048, 3072]:
		var run := EnemyAi.clear_run(w, c, way, reach, atk.half_width_m)
		var to := c + Kin.dir(way) * reach
		for p in mine:
			if hit.has(p):
				continue
			var f := Collide.sweep_vs_obb(c, to, atk.half_width_m, BossSignatures.pillar_obb(bs, p))
			if f >= 0.0 and f * reach <= run + REACH_SLACK_M:
				hit.append(p)
	if hit.is_empty():
		return 0
	hit.sort()
	var stun := false
	var gone: Array[Obb] = []
	for j in range(hit.size() - 1, -1, -1):
		var p := hit[j]
		var at := center(bs, p)
		gone.append(BossSignatures.pillar_obb(bs, p))
		bs.remove_pillar(p)
		var stuns := _count_break(w, i)
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
		e.effect_id = SHATTER
		e.amount = 1 if stuns else 0
		stun = stun or stuns
	w.remove_barriers(gone)
	BossSignatures.set_nav_extra(w)
	_point(w, id)
	if stun:
		_stun(w, i)
	return hit.size()


## A break of boss i's: true when it stuns (fewer than stuns_per_phase stuns yet this phase), counted.
static func _count_break(w: World, i: int) -> bool:
	var bs := w.bosses
	var e := bs.quake_of(w.actors.ids[i])
	var q := BossAi.table_of(w, i).quake
	if e < 0 or q == null or bs.quake_stuns[e] >= q.stuns_per_phase:
		return false
	bs.quake_stuns[e] += 1
	return true


## Boss i reels: its attack ends and it stands STAGGERED for the stun (BossAi.think counts it down, then it walks
## again after its after-stagger pause).
static func _stun(w: World, i: int) -> void:
	var a := w.actors
	var bs := w.bosses
	var b := BossAi.entry_of(w, i)
	var q := BossAi.table_of(w, i).quake
	bs.attack[b] = -1
	bs.stagger_t[b] = q.stun_ticks
	a.lock_len[i] = 0.0
	a.state[i] = BossAi.STAGGERED
	a.state_t[i] = 0
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = STUN
	e.amount = q.stun_ticks


## True while boss i is stunned by a broken pillar.
static func stunned(w: World, i: int) -> bool:
	if not BossAi.is_boss_kind(w.actors.kinds[i]) or w.actors.state[i] != BossAi.STAGGERED:
		return false
	var b := BossAi.entry_of(w, i)
	return b >= 0 and BossAi.table_of(w, i).quake != null and w.bosses.stagger_t[b] > 0


## The per mille of a hit boss i takes now (Damage): stun_permille while stunned, else 1000.
static func taken_permille(w: World, i: int) -> int:
	return BossAi.table_of(w, i).quake.stun_permille if stunned(w, i) else 1000


## The stuns boss `boss_id` has had this phase (0 without an entry).
static func stuns_of(w: World, boss_id: int) -> int:
	var e := w.bosses.quake_of(boss_id)
	return w.bosses.quake_stuns[e] if e >= 0 else 0


# --- the hint and the end of the fight -----------------------------------------------------------------------------


## The hint points at each of boss `boss_id`'s standing quake pillars, and at nothing once none stands.
static func _point(w: World, boss_id: int) -> void:
	w.objectives.clear(ObjectiveMarkers.GATEKEEPER_PILLAR)
	for k in pillars_of(w, boss_id):
		w.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, center(w.bosses, k))


## BossSignatures.on_boss_gone (its pillars already sunk): its entry goes and the hint clears.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var e := w.bosses.quake_of(boss_id)
	if e < 0:
		return
	w.bosses.remove_quake(e)
	w.objectives.clear(ObjectiveMarkers.GATEKEEPER_PILLAR)
