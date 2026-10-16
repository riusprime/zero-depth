class_name BossColossus
extends RefCounted
## v0.8.0 FB1 (owner O17: "big stone hands … a fast moving pace fight … melee attacks, jumps … the spikes that come out
## of the floor … throw big rocks"; FINAL_BOSS.md F4): the Colossus's own moves, beside the boss framework (BossAi calls
## them in its phases). Every strike shows locked for the attack's lock_ticks (0.5 s as shipped) before it lands, as
## every boss marker does (BOSS_FIGHTS.md rule 1); each has one shape function, drawn and hit alike (EI-07).
## - `combo`: `count` fist swings that follow the player, then a ground slam. Strike k (0 .. count - 1 a swing, `count`
##   the slam) lands strike_tick(k) = windup_ticks + k × mark_gap_ticks ticks into the attack. Before each strike the
##   boss turns to the player and steps toward it (at the attack's speed, never closer than half its reach) until
##   lock_ticks before the strike, then holds: the swing's arc (combo_arc) and the slam's circle round its feet
##   (combo_slam) are where it locked.
## - `spike_chase`: `count` lines of stone spikes that chase the player. Spike k of a line is laid at
##   windup_ticks - lock_ticks + k × mark_gap_ticks, step_m on from the one before toward where the player is then (the
##   first step_m out of the boss's edge along its line's angle, the lines `spread` apart round the aim), shows locked
##   for lock_ticks and erupts (a disc of radius_m). A line ends where its next spike would stand in a wall or behind
##   one. The laid spikes are BossStore points (a ring of MAX_PTS / count per line; the content checks that a spike
##   strikes before its slot is laid again); BossStore.span keeps, per line, the first spike that was not laid.
## - `spike_burst`: `count` rays of spikes out of the boss, aimed between the rays at the player; ring s (of `steps`)
##   stands step_m × s past the first ring (just outside the boss's edge), shows for lock_ticks and erupts at
##   windup_ticks + s × mark_gap_ticks; a spike in or behind a wall is left out.
## A leap with a pattern (its landing's shockwave ring) is BossAi's (resolve, M.LEAP).
## Pure: no stream is drawn here; angles are 1/4096 turns (Kin).

## BossStore.span's "never stopped" per line (8 bits a line).
const NO_STOP := 255

# --- combo --------------------------------------------------------------------------------------------------------


## The attack tick (BossDodge.attack_ticks) strike k lands on.
static func strike_tick(atk: BossAttackTable, k: int) -> int:
	return atk.windup_ticks + k * atk.mark_gap_ticks


## The strike pending at attack tick t (0 .. count, `count` the slam).
static func strike_at(atk: BossAttackTable, t: int) -> int:
	if t <= atk.windup_ticks:
		return 0
	var gap := maxi(1, atk.mark_gap_ticks)
	return mini(atk.count, (t - atk.windup_ticks + gap - 1) / gap)


## True while the pending strike still follows the player at attack tick t.
static func combo_tracking(atk: BossAttackTable, t: int) -> bool:
	return t < strike_tick(atk, strike_at(atk, t)) - atk.lock_ticks


## Tick phase 3 (WINDUP and ACTIVE): while the pending strike follows, the boss faces the player and the strike's
## place and aim (the actor's lock) follow it.
static func combo_think(w: World, i: int, atk: BossAttackTable, t: int) -> void:
	if w.player_dead() or not combo_tracking(atk, t):
		return
	var a := w.actors
	var aim := Kin.angle_of(w.player_pos() - a.pos(i))
	a.facing[i] = aim
	a.lock_a[i] = aim
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]


## Tick phase 5: while the pending strike follows, the boss steps toward the player (walls steer it), stopping half its
## reach from the player's edge.
static func combo_move(w: World, i: int, atk: BossAttackTable, slow: float) -> void:
	var a := w.actors
	var t := BossDodge.attack_ticks(w, i, atk)
	if w.player_dead() or atk.speed <= 0.0 or not combo_tracking(atk, t):
		return
	var at := a.pos(i)
	var to := w.player_pos() - at
	var dist := Kin.length(to)
	if dist <= a.radius[i] + w.player.radius_m + atk.reach_m * 0.5 or dist <= 0.0001:
		return
	a.set_pos(i, at + EnemyAi.steer(w, at, to / dist, a.radius[i]) * minf(atk.speed * slow, dist))
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]


## [center, own_r, angle, half_arc, reach] of the combo's swing where it locked (AttackShapes.arc_touches).
static func combo_arc(w: World, i: int) -> Array:
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	return [Vector2(a.lock_x[i], a.lock_y[i]), a.radius[i], a.lock_a[i], atk.half_arc, atk.reach_m]


## [center, radius] of the combo's ground slam: round the boss's feet where it locked.
static func combo_slam(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), BossAi.attack_of(w, i).radius_m]


## Tick phase 6: strike k lands on active tick k × mark_gap_ticks (each strike may hit; the hurt iframes apply).
static func combo_resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var gap := maxi(1, atk.mark_gap_ticks)
	if st % gap != 0 or st / gap > atk.count:
		return
	w.bosses.hit[b] = 0
	var p := w.player_pos()
	var pr := w.player.radius_m
	if st / gap < atk.count:
		var c := combo_arc(w, i)
		if AttackShapes.arc_touches(c[0], c[1], c[2], c[3], c[4], p, pr):
			BossAi.hit_player(w, i, atk, SimEvent.TAG_MELEE, c[0])
		return
	var d := combo_slam(w, i)
	if AttackShapes.disc_touches(d[0], d[1], p, pr):
		BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, d[0])


## What the view draws for the pending strike: an &"arc" (a swing) or a &"disc" (the slam), "tracked", "locked" once
## it stopped following, "progress" over the strike's own time (from the strike before), "strike" (its index),
## "strikes" (count + 1) and "striking" on the tick it lands.
static func combo_telegraph(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var t := BossDodge.attack_ticks(w, i, atk)
	var k := strike_at(atk, t)
	var t0 := 0 if k == 0 else strike_tick(atk, k - 1)
	var span := maxi(1, strike_tick(atk, k) - t0)
	var out := {}
	if k < atk.count:
		var c := combo_arc(w, i)
		out = {
			"shape": &"arc",
			"center": c[0],
			"own_r": c[1],
			"angle": c[2],
			"half_arc": c[3],
			"reach": c[4],
		}
	else:
		var d := combo_slam(w, i)
		out = {"shape": &"disc", "center": d[0], "radius": d[1]}
	out["progress"] = clampi((t - t0) * 1000 / span, 0, 1000)
	out["move"] = atk.move
	out["tracked"] = true
	out["locked"] = not combo_tracking(atk, t)
	out["strike"] = k
	out["strikes"] = atk.count + 1
	out["striking"] = t == strike_tick(atk, k)
	return out


## A leap's landing (BossAi.resolve) fires its pattern's first wave from where it landed: the shockwave ring, its gap
## aimed at the player (BulletPatterns.fire never spawns a shot on the player).
static func leap_wave(w: World, i: int, atk: BossAttackTable, at: Vector2) -> void:
	var pat := atk.pattern
	BulletPatterns.fire(
		w,
		i,
		pat,
		0,
		at,
		Kin.angle_of(w.player_pos() - at),
		w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M,
		BossAi.orb_damage(w, i, atk)
	)


# --- spikes -------------------------------------------------------------------------------------------------------


## The attack tick spike k (of a chase line, or ring k of a burst) is laid and the tick it erupts.
static func spike_laid(atk: BossAttackTable, k: int) -> int:
	return atk.windup_ticks - atk.lock_ticks + k * atk.mark_gap_ticks


static func spike_erupts(atk: BossAttackTable, k: int) -> int:
	return atk.windup_ticks + k * atk.mark_gap_ticks


## A chase line's ring of BossStore points (MAX_PTS shared by the lines).
static func slots_per_line(atk: BossAttackTable) -> int:
	return BossStore.MAX_PTS / maxi(1, atk.count)


## The first spike of chase line j that was not laid (NO_STOP: none yet).
static func chase_stop(w: World, b: int, j: int) -> int:
	return (w.bosses.span[b] >> (8 * j)) & 255


## The angle chase line j starts along: the lines `spread` apart round the attack's aim.
static func chase_angle(atk: BossAttackTable, aim: int, j: int) -> int:
	return BossAi.lane_angle(atk, aim, j)


## BossAi._lock: no line has stopped yet.
static func spikes_lock(w: World, b: int) -> void:
	var all := 0
	for j in 3:  # at most two lines (content); three bytes keep the packed int positive
		all |= NO_STOP << (8 * j)
	w.bosses.span[b] = all


## Tick phase 3 (WINDUP and ACTIVE): at attack tick t the spikes due are laid, each step_m on from the one before
## toward the player (the first out of the boss's edge along its line); a line whose spike would stand in a wall or
## behind one stops there.
static func chase_think(w: World, i: int, b: int, atk: BossAttackTable, t: int) -> void:
	var gap := maxi(1, atk.mark_gap_ticks)
	var t0 := spike_laid(atk, 0)
	if t < t0 or (t - t0) % gap != 0:
		return
	var k := (t - t0) / gap
	if k >= atk.steps:
		return
	var a := w.actors
	var slots := slots_per_line(atk)
	for j in atk.count:
		if chase_stop(w, b, j) <= k:
			continue
		var from := a.pos(i)
		var to := Vector2.ZERO
		if k == 0:
			var ang := chase_angle(atk, a.lock_a[i], j)
			to = from + Kin.dir(ang) * (a.radius[i] + atk.step_m)
		else:
			from = w.bosses.pt(b, j * slots + (k - 1) % slots)
			var d := w.player_pos() - from
			var dist := Kin.length(d)
			to = from if dist < 0.0001 else from + d * (minf(atk.step_m, dist) / dist)
		var run := Kin.length(to - from)
		var blocked := not EnemyAi.clear_of_walls(w, to, 0.05)
		if not blocked and run > 0.0001:
			blocked = EnemyAi.clear_run(w, from, Kin.angle_of(to - from), run, 0.05) < run - 0.001
		if blocked:
			var bs := w.bosses
			bs.span[b] = (bs.span[b] & ~(255 << (8 * j))) | (k << (8 * j))
			continue
		w.bosses.set_pt(b, j * slots + k % slots, to)


## Spike k of chase line j (laid; check chase_stop first).
static func chase_spot(w: World, b: int, atk: BossAttackTable, j: int, k: int) -> Vector2:
	var slots := slots_per_line(atk)
	return w.bosses.pt(b, j * slots + k % slots)


## The angle of burst ray j: the rays evenly round the boss, the aim halfway between two of them.
static func burst_angle(atk: BossAttackTable, aim: int, j: int) -> int:
	return (aim + (j * 4096 + 2048) / maxi(1, atk.count)) & 4095


## Where spike s of burst ray j stands, from where the boss locked: [true, centre], or [false, _] when it would
## stand in a wall or behind one.
static func burst_spot(w: World, i: int, atk: BossAttackTable, j: int, s: int) -> Array:
	var a := w.actors
	var c := Vector2(a.lock_x[i], a.lock_y[i])
	var ang := burst_angle(atk, a.lock_a[i], j)
	var r := a.radius[i] + atk.radius_m * 0.75 + atk.step_m * s
	var at := c + Kin.dir(ang) * r
	if not EnemyAi.clear_of_walls(w, at, 0.05) or EnemyAi.clear_run(w, c, ang, r, 0.05) < r - 0.001:
		return [false, at]
	return [true, at]


## Every spike that erupts on attack tick t: centres.
static func spikes_erupting(
	w: World, i: int, b: int, atk: BossAttackTable, t: int
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var gap := maxi(1, atk.mark_gap_ticks)
	var t0 := spike_erupts(atk, 0)
	if t < t0 or (t - t0) % gap != 0:
		return out
	var k := (t - t0) / gap
	if k >= atk.steps:
		return out
	for c: Vector2 in _spikes_of(w, i, b, atk, k):
		out.append(c)
	return out


## The spikes of step k (a chase's k-th spike of each line still running, a burst's ring k).
static func _spikes_of(
	w: World, i: int, b: int, atk: BossAttackTable, k: int
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in atk.count:
		if atk.move == BossAttackTable.Move.SPIKE_CHASE:
			if chase_stop(w, b, j) > k:
				out.append(chase_spot(w, b, atk, j, k))
		else:
			var s := burst_spot(w, i, atk, j, k)
			if s[0]:
				out.append(s[1])
	return out


## Tick phase 6: the spikes of the step due erupt (each step may hit; the hurt iframes apply).
static func spikes_resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var spots := spikes_erupting(w, i, b, atk, atk.windup_ticks + st)
	if spots.is_empty():
		return
	w.bosses.hit[b] = 0
	var p := w.player_pos()
	for c: Vector2 in spots:
		if AttackShapes.disc_touches(c, atk.radius_m, p, w.player.radius_m):
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)
			return


## The spikes showing now (laid, not yet erupted; one erupting shows locked at progress 1000 on its tick): &"marks"
## with a disc item each, as BossDodge.marks_telegraph; a &"cast" (nothing on the ground) before the first is laid.
static func spikes_telegraph(w: World, i: int, b: int, atk: BossAttackTable) -> Dictionary:
	var t := BossDodge.attack_ticks(w, i, atk)
	var items: Array[Dictionary] = []
	var first := -1
	for k in atk.steps:
		var t1 := spike_erupts(atk, k)
		var t0 := t1 - atk.lock_ticks
		if t < t0 or t > t1:
			continue
		var pr := clampi((t - t0) * 1000 / maxi(1, atk.lock_ticks), 0, 1000)
		if first < 0:
			first = pr
		for c: Vector2 in _spikes_of(w, i, b, atk, k):
			items.append(
				{
					"shape": &"disc",
					"center": c,
					"radius": atk.radius_m,
					"locked": true,
					"progress": pr
				}
			)
	var windup := w.actors.state[i] == EnemyAi.State.WINDUP
	if items.is_empty():
		var p := clampi(w.actors.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
		return {
			"shape": &"cast", "ground": false, "progress": p if windup else 1000, "move": atk.move
		}
	return {
		"shape": &"marks",
		"items": items,
		"progress": first,
		"move": atk.move,
		"tracked": true,
		"locked": true
	}
