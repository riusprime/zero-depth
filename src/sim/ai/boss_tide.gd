class_name BossTide
extends RefCounted
## v0.9.0 NB1 (owner Q24, "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N1; SIM_CONTRACTS §10j): the
## Tidecaller's signature, The Pull, and its Undertow.
## - The Pull: a `tide` attack (shielded) rings its bell through its windup; then for tide_pull_ticks the whole room
##   pulls the player toward the boss (the pull's speed added to the player's own step, so running away is slower and
##   coming in faster) while its Tide Rings fire (the attack's pattern, only inside the pull) and every shot of the
##   boss bends toward it; then for tide_push_ticks the room pushes out, and no ring spawns.
## - Fair: the drift is never faster than MAX_MPS; it never presses the player deeper toward a wall than WALL_MARGIN_M
##   (the step is tried whole, then along each axis, and left out when every way presses closer), so it never drives
##   the player into a corner or pins them on a wall; the pull stops BODY_GAP_M short of the boss's body; a dashing
##   or dead player isn't moved.
## - Cadence: a boss whose table has sig_every_ticks performs its phase's first `tide` attack every sig_every_ticks
##   (start to start; a phase may also open with it), not by the weighted pick; the next due tick is BossStore's sig
##   list (one entry per such boss, created the first time it may attack).
## - The Undertow: a `marks` attack with drag_m drags a player within drag_reach_m of each struck circle drag_m
##   toward its centre (never past it, by the same wall rule).
## Pure: no stream is drawn here; everything follows from the attack's clock and positions.

## The fastest the room may ever move the player (BOSSES_4_5.md: 1.5 m/s; v0.9.5 BH4: 2.2). Each tide attack sets its
## own cap in data (max_mps, at most this): cap_of.
const MAX_MPS := BossSchemas.TIDE_MAX_MPS
## The drift never brings the player closer than this to a wall (beyond where they already are).
const WALL_MARGIN_M := 0.6
## The pull stops this short of the boss's body.
const BODY_GAP_M := 0.3
## What WorldReader.boss_tide's "phase" says: no tide, pulling in, pushing out.
const NONE := 0
const PULL := 1
const PUSH := 2
## v0.9.0 NB3: due() while the signature is due but the boss's cooldown still runs.
const HOLD := -2

const M := BossAttackTable.Move


## v0.9.5 BH4 (T1): the most tide attack `atk` moves the player a tick (its data's max_mps, else MAX_MPS).
static func cap_of(atk: BossAttackTable) -> float:
	return atk.tide_max if atk.tide_max > 0.0 else MAX_MPS / SimTick.TICKS_PER_SECOND


## True for an attack the cadence starts (so the weighted pick leaves it out).
static func on_cadence(t: BossTable, atk: BossAttackTable) -> bool:
	return t.sig_every_ticks > 0 and is_cadence(atk)


## v0.9.0 NB3: the moves a cadence starts: the Tidecaller's Pull and the Clockwork Judge's echo (BossJudge).
static func is_cadence_move(move: int) -> bool:
	return move == M.TIDE or move == M.ECHO


## v0.9.0 NB4: the attacks a cadence starts: those moves, and the Lantern Shade's Lights Out (a pattern with
## dark_ticks: BossShade).
static func is_cadence(atk: BossAttackTable) -> bool:
	return atk != null and (is_cadence_move(atk.move) or atk.dark_ticks > 0)


## The phase's signature: its first `tide` attack (an index into the table's attacks), or -1.
static func signature_of(t: BossTable, phase: int) -> int:
	if phase < 0 or phase >= t.phase_attacks.size():
		return -1
	for k in t.phase_attacks[phase]:
		if is_cadence(t.attacks[k]):
			return k
	return -1


## Tick phase 3, boss i pursuing: its signature's index when the cadence says it is due now and its cooldown `cd` is
## over, else -1. The first call starts the clock (the first one sig_first_ticks on). v0.9.0 NB3: HOLD when it is
## due but the cooldown still runs: the punish and the gap-closer wait for it (a far player can't starve the cadence).
static func due(w: World, i: int, b: int, t: BossTable, cd: int = 0) -> int:
	if t.sig_every_ticks <= 0 or w.player_dead():
		return -1
	var bs := w.bosses
	var id := w.actors.ids[i]
	var k := bs.sig_of(id)
	if k < 0:
		bs.sig_boss.append(id)
		bs.sig_due.append(w.tick + t.sig_first_ticks)
		k = bs.sig_boss.size() - 1
	if w.tick < bs.sig_due[k]:
		return -1
	var sig := signature_of(t, bs.phase[b])
	return HOLD if sig >= 0 and cd > 0 else sig


## BossAi.start_attack: a `tide` attack starting (by the cadence or as a phase's entry) sets the next one's due tick
## (v0.9.0 NB3: an `echo` too).
static func on_start(w: World, i: int, atk: BossAttackTable) -> void:
	BossShade.on_start(w, i, atk)  # v0.9.0 NB4: a Lights Out sets when the dark falls
	if not is_cadence(atk):
		return
	var t := BossAi.table_of(w, i)
	var k := w.bosses.sig_of(w.actors.ids[i])
	if t.sig_every_ticks > 0 and k >= 0:
		w.bosses.sig_due[k] = w.tick + t.sig_every_ticks


## World._remove_dead (through BossSignatures.on_boss_gone): its cadence goes with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var k := w.bosses.sig_of(boss_id)
	if k >= 0:
		w.bosses.remove_sig(k)


## Boss i's tide now: NONE, PULL or PUSH (its `tide` attack's active time: the pull, then the push).
static func phase_of(w: World, i: int) -> int:
	if w.actors.state[i] != EnemyAi.State.ACTIVE:
		return NONE
	var atk := BossAi.attack_of(w, i)
	if atk == null or atk.move != M.TIDE:
		return NONE
	var st := w.actors.state_t[i]
	if st < atk.tide_pull_ticks:
		return PULL
	return PUSH if st < atk.tide_pull_ticks + atk.tide_push_ticks else NONE


## The drift the room gives the player this tick (metres): toward boss i in the pull, away in the push, capped at
## MAX_MPS, the pull stopping BODY_GAP_M short of its body. Zero when there is no tide, or for a dashing or dead player.
static func drift_of(w: World, i: int) -> Vector2:
	var ph := phase_of(w, i)
	if ph == NONE or w.player_dead() or w.is_dashing():
		return Vector2.ZERO
	var atk := BossAi.attack_of(w, i)
	var to := w.actors.pos(i) - w.player_pos()
	var d := Kin.length(to)
	if d <= 0.0001:
		return Vector2.ZERO
	var most := cap_of(atk)
	if ph == PULL:
		var gap := d - w.actors.radius[i] - w.player.radius_m - BODY_GAP_M
		return to * (clampf(minf(atk.tide_pull, most), 0.0, maxf(gap, 0.0)) / d)
	return -to * (minf(atk.tide_push, most) / d)


## Tick phase 5, boss i's `tide` attack active: the room moves the player (the wall rule: shift()), and in the pull the
## boss's shots bend toward it.
static func move(w: World, i: int, atk: BossAttackTable) -> void:
	shift(w, drift_of(w, i))
	if phase_of(w, i) == PULL and atk.tide_bend > 0:
		bend(w, i, atk.tide_bend)


## Tick phase 6: the Tide Rings fire (the attack's pattern) only while the pull is on; none spawn in the push.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	if st < atk.tide_pull_ticks:
		BossDodge.resolve_pattern(w, i, b, atk, st)


## Moves the player by `d` unless that presses them deeper toward a wall (within WALL_MARGIN_M of one) than they are:
## the whole step, else its x part, else its y part, else nothing. Returns the step taken.
static func shift(w: World, d: Vector2) -> Vector2:
	if d == Vector2.ZERO:
		return d
	var p := w.player_pos()
	var now := press(w, p)
	for step: Vector2 in [d, Vector2(d.x, 0.0), Vector2(0.0, d.y)]:
		if step == Vector2.ZERO:
			continue
		var deep := press(w, p + step)
		if deep <= 0.0 or deep <= now:
			w.actors.set_pos(0, p + step)
			return step
	return Vector2.ZERO


## How far a circle of the player's radius plus WALL_MARGIN_M at p reaches into the deepest wall it touches (0 = clear
## of every wall by the margin).
static func press(w: World, p: Vector2) -> float:
	var r := w.player.radius_m + WALL_MARGIN_M
	var deepest := 0.0
	for k in w.walls_near(Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0)):
		deepest = maxf(deepest, Kin.length(Collide.circle_vs_obb(p, r, w.walls[k])))
	return deepest


## Turns every live shot of boss i toward it by up to `step` (1/4096 turns), keeping its speed (the rings bend with
## the pull).
static func bend(w: World, i: int, step: int) -> void:
	var ps := w.projectiles
	var id := w.actors.ids[i]
	var at := w.actors.pos(i)
	var vx := ps.vel_x
	var vy := ps.vel_y
	var turned := false
	for k in ps.size():
		if ps.owner[k] != id:
			continue
		var v := Vector2(vx[k], vy[k])
		var speed := Kin.length(v)
		if speed <= 0.0:
			continue
		var heading := Kin.angle_of(v)
		var nxt := Kin.turn_toward(
			heading, Kin.angle_of(at - Vector2(ps.pos_x[k], ps.pos_y[k])), step
		)
		if nxt == heading:
			continue
		var nv := Kin.dir(nxt) * speed
		vx[k] = nv.x
		vy[k] = nv.y
		turned = true
	if turned:
		ps.vel_x = vx
		ps.vel_y = vy


## Tick phase 6, an Undertow circle at c struck: a player within drag_reach_m of its centre is dragged drag_m toward
## it (never past it; the wall rule), unless dashing.
static func undertow(w: World, atk: BossAttackTable, c: Vector2) -> void:
	if atk.drag_m <= 0.0 or w.player_dead() or w.is_dashing():
		return
	var to := c - w.player_pos()
	var d := Kin.length(to)
	if d <= 0.0001 or d > atk.drag_reach_m:
		return
	shift(w, to * (minf(atk.drag_m, d) / d))


## The view's read (WorldReader.boss_tide): {} with no tide; else "phase" (PULL or PUSH), "progress" (0..1000 of that
## part), "speed" (m/s now), "centre" (the boss) and "windup" (true while the bell rings, before the pull).
static func state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	if atk == null or atk.move != M.TIDE:
		return {}
	var a := w.actors
	if a.state[i] == EnemyAi.State.WINDUP:
		return {
			"phase": NONE,
			"windup": true,
			"progress": clampi(a.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000),
			"speed": 0.0,
			"centre": a.pos(i),
		}
	var ph := phase_of(w, i)
	if ph == NONE:
		return {}
	var st := a.state_t[i]
	var from := 0 if ph == PULL else atk.tide_pull_ticks
	var span := atk.tide_pull_ticks if ph == PULL else atk.tide_push_ticks
	var speed := minf(atk.tide_pull if ph == PULL else atk.tide_push, cap_of(atk))
	return {
		"phase": ph,
		"windup": false,
		"progress": clampi((st - from) * 1000 / maxi(1, span), 0, 1000),
		"speed": speed * SimTick.TICKS_PER_SECOND,
		"centre": a.pos(i),
	}
