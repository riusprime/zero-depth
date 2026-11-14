class_name BossRewind
extends RefCounted
## The Clockwork Judge's signature, the Rewind, and its own return (BossTimeTable; BossStore.time_*).
## - The trails: while the Judge lives, where the hero stood and where the Judge stood are kept, a point every
##   step_ticks (on ticks that are a multiple of it), the last `points` of them. A dead hero leaves no point.
## - The pale copy (copy_of): from rewind_phase on, where the hero stood trail_ticks ago (late_trail_ticks from
##   late_phase): the trail's point that many steps before its newest, its oldest while the trail is still short.
## - The Bell: bell_first_ticks into rewind_phase, then every bell_every_ticks from one cast's start to the next,
##   the Judge's bell is cast beside whatever it is doing (not an attack: its attacks go on); bell_cast_ticks later
##   it tolls and the hero is thrown to where the copy stands then. From late_phase it tolls late_tolls times,
##   toll_gap_ticks apart. A cast never begins during a phase gate or with the hero dead or outside the arena.
## - The throw (snap): a dash does not prevent it and it deals no damage. Never into a wall, a gear or the Judge's
##   body: when the copy's spot is taken the hero lands on the nearest free spot of free_spot's rings, and stays
##   where it is when there is none.
## - The Bell's Verdict: each toll brings a Verdict of its own (the size and damage of the Judge's `verdict` attack,
##   read from it; none when it has no such attack). Its square follows the copy while the toll is awaited, locks
##   where the copy stands at the toll, and drops bell_verdict_ticks after it: the hero is thrown onto the square and
##   has that long to leave it. It hits once, as a Verdict does (the same damage, tags and death cause), whatever the
##   Judge is doing then. The Judge's ordinary Verdict follows the hero, not the copy.
## - The Judge's return: once, in return_phase, with return_hp_permille of that phase's bar left and between two of
##   its attacks, it goes back to where it stood return_ticks ago (when that spot is free) and recovers
##   return_heal_permille of the bar, unless the hero is within return_near_m of its edge.
## Each tells the event log with a STATUS_APPLY (BELL, SNAP, BELL_VERDICT, RETURN): for the views and the tests,
## never read back.
## Pure: no stream is drawn; everything follows from the clock and the positions.

## STATUS_APPLY effects. BELL: a cast or a later toll's wait begins (source and target the Judge; amount = the ticks
## to the toll). SNAP: the hero was thrown (target the hero, pos = where it landed, amount = how far, mm).
## BELL_VERDICT: a Bell's Verdict dropped (target the hero, pos = its square's centre, amount = the HP it cost, 0 when
## it missed). RETURN: the Judge went back (pos = where it stands now, amount = the HP it recovered).
const BELL := &"judge_bell"
const SNAP := &"judge_rewind"
const BELL_VERDICT := &"judge_bell_verdict"
const RETURN := &"judge_return"
## A thrown hero keeps this much clear of walls and bodies.
const FREE_SLACK_M := 0.05
## free_spot looks on RINGS rings, RING_M apart, DIRS spots on each.
const RING_M := 0.5
const RINGS := 12
const DIRS := 16


## True while boss i's Rewind is on: its copy follows the hero and its Bell tolls.
static func active(w: World, i: int) -> bool:
	var tt := BossAi.table_of(w, i).time
	if tt == null or w.bosses.time_boss != w.actors.ids[i]:
		return false
	return w.bosses.phase[BossAi.entry_of(w, i)] >= tt.rewind_phase


## How far behind the hero the copy trails in `phase`, in ticks.
static func trail_of(tt: BossTimeTable, phase: int) -> int:
	return tt.late_trail_ticks if phase >= tt.late_phase else tt.trail_ticks


## Where the pale copy stands in `phase` (the hero itself before any point was kept).
static func copy_of(w: World, tt: BossTimeTable, phase: int) -> Vector2:
	return _back(
		w.bosses.time_px, w.bosses.time_py, trail_of(tt, phase) / tt.step_ticks, w.player_pos()
	)


## The attack a Bell's Verdict takes its square and damage from: the table's first `verdict` (an index into its
## attacks), or -1.
static func verdict_attack(t: BossTable) -> int:
	for k in t.attacks.size():
		if t.attacks[k].move == BossAttackTable.Move.VERDICT:
			return k
	return -1


## The point `steps` before the newest of a trail (its oldest when it is shorter; `none` when it is empty).
static func _back(
	xs: PackedFloat32Array, ys: PackedFloat32Array, steps: int, none: Vector2
) -> Vector2:
	if xs.is_empty():
		return none
	var k := maxi(0, xs.size() - 1 - steps)
	return Vector2(xs[k], ys[k])


## Tick phase 3 (BossTime.think), boss i in `phase`: the trails gain their point, and the Bell's cast begins when due.
static func think(w: World, i: int, tt: BossTimeTable, phase: int) -> void:
	var bs := w.bosses
	if w.tick % tt.step_ticks == 0:
		if not w.player_dead():
			_keep(bs.time_px, bs.time_py, w.player_pos(), tt.points)
		_keep(bs.time_bx, bs.time_by, w.actors.pos(i), tt.points)
	if phase < tt.rewind_phase:
		return
	if bs.time_bell_due < 0:
		bs.time_bell_due = w.tick + tt.bell_first_ticks
	if w.tick < bs.time_bell_due or bs.time_bell_at >= 0:
		return
	if w.actors.state[i] == BossAi.GATE or BossSlow.fight_over(w):
		return
	bs.time_bell_due = w.tick + tt.bell_every_ticks
	bs.time_tolls = (tt.late_tolls if phase >= tt.late_phase else 1) - 1
	_wait(w, i, tt.bell_cast_ticks)


static func _keep(xs: PackedFloat32Array, ys: PackedFloat32Array, p: Vector2, most: int) -> void:
	xs.append(p.x)
	ys.append(p.y)
	while xs.size() > most:
		xs.remove_at(0)
		ys.remove_at(0)


## The Bell tolls `ticks` from now.
static func _wait(w: World, i: int, ticks: int) -> void:
	var bs := w.bosses
	var id := w.actors.ids[i]
	bs.time_bell_from = w.tick
	bs.time_bell_at = w.tick + ticks
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = BELL
	e.amount = ticks
	e.amount_applied = bs.time_tolls


## Tick phase 6 (BossTime.advance), boss i alive and the fight on: a Bell's Verdict due drops; a toll due throws the
## hero and locks its Verdict's square on the copy; the Judge's return.
static func advance(w: World, i: int, t: BossTable) -> void:
	var bs := w.bosses
	var tt := t.time
	var phase := bs.phase[BossAi.entry_of(w, i)]
	if bs.time_bv_at >= 0 and w.tick >= bs.time_bv_at:
		_drop(w, i, t)
	if bs.time_bell_at >= 0 and w.tick >= bs.time_bell_at:
		var at := copy_of(w, tt, phase)
		snap(w, i, at)
		if verdict_attack(t) >= 0:
			bs.time_bv_x = at.x
			bs.time_bv_y = at.y
			bs.time_bv_at = w.tick + tt.bell_verdict_ticks
		if bs.time_tolls > 0:
			bs.time_tolls -= 1
			_wait(w, i, tt.toll_gap_ticks)
		else:
			_no_toll(w)
	_return(w, i, t, phase)


## The locked Bell's Verdict of boss i drops: the hero touching its square takes the `verdict` attack's damage, once.
static func _drop(w: World, i: int, t: BossTable) -> void:
	var bs := w.bosses
	var c := Vector2(bs.time_bv_x, bs.time_bv_y)
	bs.time_bv_at = -1
	var k := verdict_attack(t)
	if k < 0:
		return
	var atk := t.attacks[k]
	var id := w.actors.ids[i]
	var hp := w.actors.hp[0]
	var p := w.player_pos()
	var square := BossJudge.square_of(c, atk.square_half_m)
	if Collide.circle_vs_obb(p, w.player.radius_m, square) != Vector2.ZERO:
		var dmg := BossAi.powered(w, i, atk.damage)
		Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, c, p)
		if w.player_dead() and w.killer_attack < 0:
			w.killer_attack = k
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], c)
	e.effect_id = BELL_VERDICT
	e.amount = maxi(0, hp - w.actors.hp[0])


## No toll is awaited (the next cast keeps its own clock).
static func _no_toll(w: World) -> void:
	w.bosses.time_bell_at = -1
	w.bosses.time_bell_from = -1
	w.bosses.time_tolls = 0


## The fight ended: no toll is awaited and no Bell's Verdict hangs.
static func cancel(w: World) -> void:
	_no_toll(w)
	w.bosses.time_bv_at = -1


## The Bell's Verdict squares of boss i, the locked one first: each {"center", "half", "locked" (false while it
## follows the copy toward the toll), "left" (ticks until it drops)}.
static func squares(w: World, i: int, tt: BossTimeTable, phase: int) -> Array[Dictionary]:
	var bs := w.bosses
	var out: Array[Dictionary] = []
	var t := BossAi.table_of(w, i)
	var k := verdict_attack(t)
	if k < 0:
		return out
	var half := t.attacks[k].square_half_m
	if bs.time_bv_at >= 0:
		var c := Vector2(bs.time_bv_x, bs.time_bv_y)
		var left := maxi(0, bs.time_bv_at - w.tick)
		out.append({"center": c, "half": half, "locked": true, "left": left})
	if bs.time_bell_at >= 0:
		var wait := maxi(0, bs.time_bell_at - w.tick) + tt.bell_verdict_ticks
		out.append({"center": copy_of(w, tt, phase), "half": half, "locked": false, "left": wait})
	return out


## Throws the hero to `to` (or the nearest free spot to it) for boss i. Returns where it stands afterwards.
static func snap(w: World, i: int, to: Vector2) -> Vector2:
	if w.player_dead():
		return w.player_pos()
	var from := w.player_pos()
	var at := free_spot(w, i, to)
	w.actors.set_pos(0, at)
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], at)
	e.effect_id = SNAP
	e.amount = int(Kin.length(at - from) * 1000.0)
	return at


## The spot nearest `to` where the hero fits (is_free): `to` itself, else the first free spot on rings round it, RING_M
## apart, the nearer ring first and each from the same heading round; the hero's own place when none is free.
static func free_spot(w: World, i: int, to: Vector2) -> Vector2:
	if is_free(w, i, to):
		return to
	for ring in range(1, RINGS + 1):
		for d in DIRS:
			var p := to + Kin.dir(d * 4096 / DIRS) * (ring * RING_M)
			if is_free(w, i, p):
				return p
	return w.player_pos()


## True when the hero fits at p: clear of every wall (the gears are walls) and of boss i's body by FREE_SLACK_M, and
## inside the boss room when the fight has one.
static func is_free(w: World, i: int, p: Vector2) -> bool:
	var pr := w.player.radius_m + FREE_SLACK_M
	var room := w.bosses.arena
	if room.has_area() and not room.has_point(p):
		return false
	if Kin.length(p - w.actors.pos(i)) < w.actors.radius[i] + pr:
		return false
	return EnemyAi.clear_of_walls(w, p, pr)


## The Judge's own return (the class comment's rule), once.
static func _return(w: World, i: int, t: BossTable, phase: int) -> void:
	var bs := w.bosses
	var tt := t.time
	var a := w.actors
	if bs.time_back == 1 or phase != tt.return_phase or tt.return_hp_permille <= 0:
		return
	if a.state[i] != EnemyAi.State.MOVE:
		return
	var floor_pm := t.phase_threshold[phase + 1] if phase + 1 < t.phase_threshold.size() else 0
	var bar := t.phase_threshold[phase] - floor_pm  # The phase's bar, per mille of max HP
	var left := a.hp[i] * 1000 - floor_pm * a.max_hp[i]  # What is left of it, in thousandths of an HP
	if left * 1000 > bar * tt.return_hp_permille * a.max_hp[i]:
		return
	bs.time_back = 1
	var near := Kin.length(w.player_pos() - a.pos(i)) - a.radius[i] <= tt.return_near_m
	var to := _back(bs.time_bx, bs.time_by, tt.return_ticks / tt.step_ticks, a.pos(i))
	var clear := Kin.length(to - w.player_pos()) >= a.radius[i] + w.player.radius_m + FREE_SLACK_M
	if clear and EnemyAi.clear_of_walls(w, to, a.radius[i]):
		a.set_pos(i, to)
	var heal := 0
	if not near and not w.player_dead():
		heal = mini(a.max_hp[i] - a.hp[i], bar * tt.return_heal_permille * a.max_hp[i] / 1000000)
		a.hp[i] += heal
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = RETURN
	e.amount = heal


## The view's read (BossTime.state adds it): "rewind" (true while it is on), and then "copy" (where the pale copy
## stands), "trail" (how far behind it follows, ticks), "bell" (0..1000 toward the toll pending, -1 none), "bell_left"
## (ticks to it, -1 none), "tolls" (the tolls after it), "bell_in" (ticks until the next cast begins) and
## "bell_squares" (the Bell's Verdict squares: `squares`).
static func state(w: World, i: int) -> Dictionary:
	var bs := w.bosses
	if not active(w, i):
		return {"rewind": false}
	var tt := BossAi.table_of(w, i).time
	var phase := bs.phase[BossAi.entry_of(w, i)]
	var out := {
		"rewind": true,
		"copy": copy_of(w, tt, phase),
		"trail": trail_of(tt, phase),
		"bell": -1,
		"bell_left": -1,
		"tolls": bs.time_tolls,
		"bell_in": maxi(0, bs.time_bell_due - w.tick),
		"bell_squares": squares(w, i, tt, phase),
	}
	if bs.time_bell_at >= 0:
		var span := maxi(1, bs.time_bell_at - bs.time_bell_from)
		out["bell"] = clampi((w.tick - bs.time_bell_from) * 1000 / span, 0, 1000)
		out["bell_left"] = maxi(0, bs.time_bell_at - w.tick)
	return out
