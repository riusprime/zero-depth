class_name BossDuel
extends RefCounted
## The Warlord's Duel (BossWarlordTable duel_*; BossFightStore.wl_du_*, wl_fence_at): its signature, cast through
## BossWarlord's rhythm.
## - The cast (duel_cast_ticks): javelins fall in a ring; the boss stands and starts nothing.
## - The cage: a circle centred on the midpoint between the boss and the hero as the cast ends, moved inward until the
##   whole circle is inside the boss room (ROOM_GAP_M from its edge; a room too small for it gets a smaller cage).
##   Its fence closes linearly from duel_radius_m to duel_end_radius_m over duel_ticks. While it stands (and through
##   the recall's warning) neither can leave: a hero whose body crosses the fence is moved back onto it (BossTide.shift,
##   the Pull's rule: never deeper toward a wall), the boss's body likewise (set back on its line to the centre), and
##   the boss's charge is cut short at the fence (its lane locks there; its burst still happens where it stops).
##   A hero within fence_touch_m of the fence loses fence_hit per mille of its max HP (SafeArea ONCE: armour and the
##   dash's invulnerability apply), at most once every fence_every_ticks (the first fence_every_ticks after the cage
##   closes are free, so a hero the cage drags in can step off it). The boss's front shield is down (Damage, its
##   front arc takes the normal share) and it starts only the duel's attacks (BossWarlord.may_use).
## - The recall: duel_ticks after the cage closed, recall_warn_ticks of warning on the centre's recall_radius_m; then
##   the javelins fly back through it: a hero touching it loses recall_hit per mille (ONCE). Then the cage is gone and
##   the next duel is due duel_gap_ticks later.
## Pure: no stream is drawn.

const CAST := 1
const CAGE := 2
const RECALL := 3
## The cage keeps this far inside the boss room's edge (m).
const ROOM_GAP_M := 0.25
## A charge locked at the fence still runs this far (m), so its run ends on a tick of its own and its burst arms.
const MIN_RUN_M := 0.01
## STATUS_APPLY effects, source the boss. CAST_EV: the cast begins (amount = its ticks). START: the cage closes (pos =
## its centre, amount = its ticks). END: it is gone (amount_applied = 1 after its recall, 0 cut short). FENCE: the
## fence hurt the hero (target the hero, pos = where, amount = the HP it cost). WARN: the recall's warning (pos = the
## centre, amount = its ticks). RECALL_EV: the javelins came back (target the hero, amount = the HP it cost, 0 a miss).
const CAST_EV := &"warlord_duel_cast"
const START := &"warlord_duel_start"
const END := &"warlord_duel_end"
const FENCE := &"warlord_fence_touch"
const WARN := &"warlord_recall_warn"
const RECALL_EV := &"warlord_recall"
## The damage effect ids.
const FENCE_EFFECT := &"boss_warlord_fence"
const RECALL_EFFECT := &"boss_warlord_recall"


## BossWarlord: the cast begins now.
static func begin(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	fs.wl_du_stage = CAST
	fs.wl_du_from = w.tick
	BossWarlord.event(w, i, CAST_EV, w.actors.pos(i)).amount = wt.duel_cast_ticks


## Tick phase 6 (BossWarlord.advance): the cast ends, the cage closes and holds both in, the fence hurts, the recall
## warns and strikes.
static func advance(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	var t := w.tick - fs.wl_du_from
	match fs.wl_du_stage:
		CAST:
			if t >= wt.duel_cast_ticks:
				_close(w, i, wt)
		CAGE:
			if t >= wt.duel_ticks:
				fs.wl_du_stage = RECALL
				fs.wl_du_from = w.tick
				BossWarlord.event(w, i, WARN, centre(w)).amount = wt.recall_warn_ticks
		RECALL:
			if t >= wt.recall_warn_ticks:
				_recall(w, i, wt)
				end(w, i, wt, true)
				return
	if fs.wl_du_stage >= CAGE:
		_hold(w, i)
		_fence(w, i, wt)


## Where the cage would close now: the midpoint between boss i and the hero, moved inward until a circle of `r` is
## inside the boss room. Returns [centre, radius] (the radius smaller only in a room too small for it).
static func fit(w: World, i: int, r: float) -> Array:
	var c := (w.actors.pos(i) + w.player_pos()) * 0.5
	var room := w.bosses.arena
	if not room.has_area():
		return [c, r]
	var r_fit := minf(r, minf(room.size.x, room.size.y) * 0.5 - ROOM_GAP_M)
	var lo := room.position + Vector2.ONE * (r_fit + ROOM_GAP_M)
	var hi := room.end - Vector2.ONE * (r_fit + ROOM_GAP_M)
	c.x = clampf(c.x, lo.x, maxf(lo.x, hi.x))
	c.y = clampf(c.y, lo.y, maxf(lo.y, hi.y))
	return [c, maxf(r_fit, 0.0)]


static func _close(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	var f := fit(w, i, wt.duel_radius_m)
	var c: Vector2 = f[0]
	fs.wl_du_stage = CAGE
	fs.wl_du_from = w.tick
	fs.wl_du_x = c.x
	fs.wl_du_y = c.y
	fs.wl_du_r0 = float(f[1])
	fs.wl_du_r1 = minf(wt.duel_end_radius_m, fs.wl_du_r0)
	fs.wl_fence_at = w.tick + wt.fence_every_ticks
	BossWarlord.event(w, i, START, c).amount = wt.duel_ticks


## The cage's centre.
static func centre(w: World) -> Vector2:
	return Vector2(w.boss_fight.wl_du_x, w.boss_fight.wl_du_y)


## The fence's radius now (m): closing linearly through the cage, the last ring through the recall's warning.
static func radius(w: World, wt: BossWarlordTable) -> float:
	var fs := w.boss_fight
	if fs.wl_du_stage == RECALL:
		return fs.wl_du_r1
	var t := clampi(w.tick - fs.wl_du_from, 0, wt.duel_ticks)
	return fs.wl_du_r0 + (fs.wl_du_r1 - fs.wl_du_r0) * float(t) / float(wt.duel_ticks)


## Neither leaves: the boss's body and the hero's are kept inside the fence; the boss's charge locks at it.
static func _hold(w: World, i: int) -> void:
	var a := w.actors
	var wt := BossAi.table_of(w, i).warlord
	var c := centre(w)
	var r := radius(w, wt)
	var inner := maxf(r - a.radius[i], 0.0)
	var off := a.pos(i) - c
	var d := Kin.length(off)
	if d > inner:
		a.set_pos(i, c + off * (inner / d))
	var atk := BossAi.attack_of(w, i)
	if atk != null and atk.move == BossAttackTable.Move.CHARGE:
		var run := exit_of(a.pos(i), Kin.dir(a.lock_a[i]), c, inner)
		if a.state[i] == EnemyAi.State.WINDUP:  # A run of at least a step, so it stops (and bursts) in the cage
			run = maxf(run, MIN_RUN_M)
		a.lock_len[i] = minf(a.lock_len[i], run)
	if w.player_dead():
		return
	var p := w.player_pos()
	var room := maxf(r - w.player.radius_m, 0.0)
	var po := p - c
	var pd := Kin.length(po)
	if pd > room:
		BossTide.shift(w, c + po * (room / pd) - p)


## How far from p (inside the circle of `r` round c, or on it) a ray along the unit `dir` runs before it leaves the
## circle; 0 for a point past it (beyond a float's slack) or on it heading out.
static func exit_of(p: Vector2, dir: Vector2, c: Vector2, r: float) -> float:
	var v := p - c
	var b := v.dot(dir)
	var q := v.dot(v) - r * r
	if q > 0.0001:
		return 0.0
	return maxf(-b + sqrt(maxf(b * b - q, 0.0)), 0.0)


## A hero touching the fence (its body within fence_touch_m of it) is hurt, at most once every fence_every_ticks.
static func _fence(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	if w.player_dead() or w.tick < fs.wl_fence_at or not touching(w, wt):
		return
	fs.wl_fence_at = w.tick + wt.fence_every_ticks
	var cost := SafeArea.hurt(w, i, wt.fence_hit, SafeArea.Mode.ONCE, wt.fence_cause, FENCE_EFFECT)
	var e := BossWarlord.event(w, i, FENCE, w.player_pos())
	e.target_id = w.actors.ids[0]
	e.amount = cost


## True while the hero's body is within fence_touch_m of the fence.
static func touching(w: World, wt: BossWarlordTable) -> bool:
	var d := Kin.length(w.player_pos() - centre(w)) + w.player.radius_m
	return d >= radius(w, wt) - wt.fence_touch_m


## True while the hero's body touches the recall's centre zone.
static func in_zone(w: World, wt: BossWarlordTable) -> bool:
	return AttackShapes.disc_touches(
		centre(w), wt.recall_radius_m, w.player_pos(), w.player.radius_m
	)


static func _recall(w: World, i: int, wt: BossWarlordTable) -> void:
	var cost := 0
	if not w.player_dead() and in_zone(w, wt):
		cost = SafeArea.hurt(
			w, i, wt.recall_hit, SafeArea.Mode.ONCE, wt.recall_cause, RECALL_EFFECT
		)
	var e := BossWarlord.event(w, i, RECALL_EV, centre(w))
	e.target_id = w.actors.ids[0]
	e.amount = cost


## The duel ends (after its recall, or cut short): the cage is gone and the next one is due duel_gap_ticks later.
static func end(w: World, i: int, wt: BossWarlordTable, recalled: bool) -> void:
	var fs := w.boss_fight
	if fs.wl_du_stage == 0:
		return
	fs.wl_du_stage = 0
	fs.wl_du_from = -1
	fs.wl_fence_at = -1
	fs.wl_next = w.tick + wt.duel_gap_ticks
	BossWarlord.event(w, i, END, centre(w)).amount_applied = 1 if recalled else 0


## Damage.target_mult: boss `target` (an actor index) has its front shield down (its cage stands).
static func shield_down(w: World, target: int) -> bool:
	var fs := w.boss_fight
	return fs.wl_du_stage >= CAGE and fs.wl_boss >= 0 and w.actors.ids[target] == fs.wl_boss


## The read (BossWarlord.state's "duel"): {} with no duel; else "stage" (CAST, CAGE, RECALL), "cast" (0..1000 through
## the cast, -1 after), "centre" (during the cast where it would close now), "radius" (the fence now), "from_radius",
## "to_radius", "left" (ticks until the recall's warning, 0 through it), "progress" (0..1000 through the closing),
## "zone" ({} until the warning; else "centre", "radius", "warn" 0..1000), "shield_down", "touch_m", "touching" (the
## hero is within reach of the fence), "in_zone".
static func state(w: World, i: int, wt: BossWarlordTable) -> Dictionary:
	var fs := w.boss_fight
	if fs.wl_du_stage == 0:
		return {}
	var t := w.tick - fs.wl_du_from
	if fs.wl_du_stage == CAST:
		var f := fit(w, i, wt.duel_radius_m)
		return {
			"stage": CAST,
			"cast": clampi(t * 1000 / maxi(1, wt.duel_cast_ticks), 0, 1000),
			"centre": f[0],
			"radius": f[1],
			"from_radius": f[1],
			"to_radius": minf(wt.duel_end_radius_m, float(f[1])),
			"left": wt.duel_ticks,
			"progress": 0,
			"zone": {},
			"shield_down": false,
			"touch_m": wt.fence_touch_m,
			"touching": false,
			"in_zone": false,
		}
	var zone := {}
	if fs.wl_du_stage == RECALL:
		zone = {
			"centre": centre(w),
			"radius": wt.recall_radius_m,
			"warn": clampi(t * 1000 / maxi(1, wt.recall_warn_ticks), 0, 1000),
		}
	var cage := fs.wl_du_stage == CAGE
	return {
		"stage": fs.wl_du_stage,
		"cast": -1,
		"centre": centre(w),
		"radius": radius(w, wt),
		"from_radius": fs.wl_du_r0,
		"to_radius": fs.wl_du_r1,
		"left": maxi(0, wt.duel_ticks - t) if cage else 0,
		"progress": clampi(t * 1000 / maxi(1, wt.duel_ticks), 0, 1000) if cage else 1000,
		"zone": zone,
		"shield_down": true,
		"touch_m": wt.fence_touch_m,
		"touching": not w.player_dead() and touching(w, wt),
		"in_zone": not w.player_dead() and in_zone(w, wt),
	}
