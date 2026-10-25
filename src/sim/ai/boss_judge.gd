class_name BossJudge
extends RefCounted
## v0.9.0 NB3 (owner Q24, "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N3; SIM_CONTRACTS §10l): the
## Clockwork Judge's signature, your echo, and its Verdict.
## - The recording: while a Judge lives it keeps where the player stood, one point every echo_gap_ticks (on ticks that
##   are a multiple of it), the last echo_points of them (BossStore.echo_*): the last 3 s, a point per 0.25 s.
## - The echo (move `echo`, shielded, on the boss's cadence: BossTide.due, every sig_every_ticks start to start): as it
##   starts the recording locks into the path (BossStore.path_*), the points within radius_m + the player's radius +
##   echo_safe_m of where the player stands then left out (it never strikes where you stand at its start); the whole
##   path shows through the windup (0.8 s); then a ghost strike lands on each point in the order walked, one every
##   echo_gap_ticks (point k on active tick k × echo_gap_ticks), a disc radius_m wide. One echo at a time: it is an
##   attack, and the next is a cadence away.
## - The Verdict (move `verdict`): a square square_half_m each way follows the player's exact position until the lock,
##   then holds; a pendulum strike drops on it the tick the windup ends.
## Pure: no stream is drawn here; everything follows from the clock and positions.

## What state()'s "phase" says: no echo, the path showing (the windup), the ghosts striking (its active time).
const NONE := 0
const SHOW := 1
const REPLAY := 2

const M := BossAttackTable.Move


static func is_move(move: int) -> bool:
	return move == M.ECHO or move == M.VERDICT


## Tick phase 3, every live boss: a Judge records the player's position (the first Judge to think owns the echo).
static func record(w: World, i: int, t: BossTable) -> void:
	if t.echo_points <= 0:
		return
	var bs := w.bosses
	var id := w.actors.ids[i]
	if bs.echo_boss != id:
		if bs.echo_boss >= 0 and w.actors.index_of(bs.echo_boss) >= 0:
			return  # one echo at a time: another Judge records
		bs.clear_echo()
		bs.echo_boss = id
	if w.player_dead() or w.tick % t.echo_gap_ticks != 0:
		return
	var p := w.player_pos()
	var xs := bs.echo_x
	var ys := bs.echo_y
	xs.append(p.x)
	ys.append(p.y)
	while xs.size() > t.echo_points:
		xs.remove_at(0)
		ys.remove_at(0)
	bs.echo_x = xs
	bs.echo_y = ys


## BossAi.start_attack (after the lock): an echo locks its path (the safe spot left out); a Verdict's square starts on
## the player. Any other attack leaves no path behind.
static func on_start(w: World, i: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	if bs.echo_boss == w.actors.ids[i] and not bs.path_k.is_empty():
		bs.path_x = PackedFloat32Array()
		bs.path_y = PackedFloat32Array()
		bs.path_k = PackedInt32Array()
	if atk.move == M.VERDICT:
		bs.set_pt(BossAi.entry_of(w, i), 0, w.player_pos())
		return
	if atk.move != M.ECHO or bs.echo_boss != w.actors.ids[i]:
		return
	var p := w.player_pos()
	var keep := atk.radius_m + w.player.radius_m + atk.echo_safe_m
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var pk := PackedInt32Array()
	for k in bs.echo_x.size():
		var c := Vector2(bs.echo_x[k], bs.echo_y[k])
		if Kin.length(c - p) < keep:
			continue
		px.append(c.x)
		py.append(c.y)
		pk.append(k)
	bs.path_x = px
	bs.path_y = py
	bs.path_k = pk


## Tick phase 3, a Verdict winding up: its square follows the player until the lock.
static func track_verdict(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	if w.player_dead() or w.actors.state_t[i] >= atk.windup_ticks - atk.lock_ticks:
		return
	w.bosses.set_pt(b, 0, w.player_pos())


## The Verdict's square round c.
static func square_of(c: Vector2, half: float) -> Obb:
	return AttackShapes.lane(c - Vector2(half, 0.0), 0, half * 2.0, half)


## Tick phase 6, active tick st: the echo's points due now strike; the Verdict drops on its first.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var bs := w.bosses
	var p := w.player_pos()
	var pr := w.player.radius_m
	if atk.move == M.VERDICT:
		if st == 0 and Collide.circle_vs_obb(p, pr, verdict_square(w, i, atk)) != Vector2.ZERO:
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, bs.pt(b, 0))
		return
	if bs.echo_boss != w.actors.ids[i]:
		return
	for m in bs.path_k.size():
		if bs.path_k[m] * atk.echo_gap_ticks != st:
			continue
		var c := Vector2(bs.path_x[m], bs.path_y[m])
		bs.hit[b] = 0
		if AttackShapes.disc_touches(c, atk.radius_m, p, pr):
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)


## The Verdict's square now (where it tracks or locked).
static func verdict_square(w: World, i: int, atk: BossAttackTable) -> Obb:
	return square_of(w.bosses.pt(BossAi.entry_of(w, i), 0), atk.square_half_m)


## What the view draws on the ground: the Verdict's square while it winds up (dull while it tracks, bright once
## locked: a &"lanes" telegraph of one square); the echo draws nothing here (WorldReader.boss_echo).
static func telegraph(w: World, i: int, atk: BossAttackTable, progress: int) -> Dictionary:
	if atk.move == M.ECHO:
		return {"shape": &"signature", "ground": false, "progress": progress, "move": atk.move}
	var a := w.actors
	if a.state[i] != EnemyAi.State.WINDUP:
		return {}
	var obbs: Array[Obb] = [verdict_square(w, i, atk)]
	return {
		"shape": &"lanes",
		"obbs": obbs,
		"progress": progress,
		"move": atk.move,
		"tracked": true,
		"locked": a.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
	}


## World._remove_dead (through BossSignatures.on_boss_gone): its echo goes with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.bosses.echo_boss == boss_id:
		w.bosses.clear_echo()


## The view's read (WorldReader.boss_echo): {} for any other actor; else "recording" (0..1000: how far into the last
## record window before the next echo is due; 1000 while one runs), "trail" (the points recorded, oldest first),
## "phase" (NONE, SHOW, REPLAY), and while an echo runs "progress" (0..1000 of that part), "t" (ticks since its
## windup began), "windup" (its ticks), "gap" (ticks between strikes), "radius", "path" (one {"pos", "k", "at" (the
## tick from the windup's start it strikes), "struck"} per point), and the Verdict's "verdict" {"center", "half",
## "locked", "progress"} while one winds up.
static func state(w: World, i: int) -> Dictionary:
	var a := w.actors
	var bs := w.bosses
	var id := a.ids[i]
	if bs.echo_boss != id:
		return {}
	var t := BossAi.table_of(w, i)
	var trail: Array[Vector2] = []
	for k in bs.echo_x.size():
		trail.append(Vector2(bs.echo_x[k], bs.echo_y[k]))
	var span := maxi(1, t.echo_points * t.echo_gap_ticks)
	var rec := 0
	var s := bs.sig_of(id)
	if s >= 0:
		rec = clampi((w.tick - (bs.sig_due[s] - span)) * 1000 / span, 0, 1000)
	var out := {"recording": rec, "trail": trail, "phase": NONE}
	var atk := BossAi.attack_of(w, i)
	var st := a.state[i]
	if atk == null or (st != EnemyAi.State.WINDUP and st != EnemyAi.State.ACTIVE):
		return out
	var into := a.state_t[i] if st == EnemyAi.State.WINDUP else atk.windup_ticks + a.state_t[i]
	if atk.move == M.VERDICT:
		if st == EnemyAi.State.WINDUP:
			out["verdict"] = {
				"center": bs.pt(BossAi.entry_of(w, i), 0),
				"half": atk.square_half_m,
				"locked": a.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
				"progress": clampi(a.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000),
			}
		return out
	if atk.move != M.ECHO:
		return out
	var path: Array[Dictionary] = []
	for m in bs.path_k.size():
		var at := atk.windup_ticks + bs.path_k[m] * atk.echo_gap_ticks
		(
			path
			. append(
				{
					"pos": Vector2(bs.path_x[m], bs.path_y[m]),
					"k": bs.path_k[m],
					"at": at,
					"struck": into >= at,
				}
			)
		)
	var winding := st == EnemyAi.State.WINDUP
	var total := atk.windup_ticks if winding else atk.active_ticks
	out["recording"] = 1000
	out["phase"] = SHOW if winding else REPLAY
	out["progress"] = clampi(a.state_t[i] * 1000 / maxi(1, total), 0, 1000)
	out["t"] = into
	out["windup"] = atk.windup_ticks
	out["gap"] = atk.echo_gap_ticks
	out["radius"] = atk.radius_m
	out["path"] = path
	return out
