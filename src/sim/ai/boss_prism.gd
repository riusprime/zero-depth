class_name BossPrism
extends RefCounted
## v0.8.0 FB2 (owner O17: "rays that go in a cross and turn with her in the middle around the room so you have to move
## away … a lot of small balls … quick, fast attacks that you also have to dodge"; FINAL_BOSS.md F5, F7 "Phase-by-phase
## mix"; SIM_CONTRACTS "The final boss"): the Prism, the final boss's second body, and its `cross` attack.
## - She floats: she glides back to the fight's centre (FinalFight.home) at her speed and stays there (drift).
## - Her shards orbit her (shard_pos: BossTable.shard_count of them, shard_orbit_m out, turning with the world's tick)
##   and are what fires.
## - The Cross (`cross`): `count` beams in a plus from her edge to the walls (EnemyAi.clear_run). Through its windup
##   (the spin-up) thin aim lines show where they will open, re-aimed every tick so the player stands midway between
##   two arms (never on one). Then they turn a quarter turn every quarter ticks, the way opposite to her last Cross's
##   (the first one's way from the ai stream), reversing every reverse_ticks, for spin_ticks, hurting a player one
##   touches once every burn_ticks. The quarter is set as the windup begins from her HP: quarter_ticks at full HP down
##   to fast_quarter_ticks at none, so the Cross speeds up as she weakens. She is shielded through the windup and the
##   spin (BossDodge.shielded); then the beams go out for the window (window_ticks, the rest of the active time) and
##   her shield is down: the only time she can be hurt.
## - Orbs: while the beams turn, the attack's pattern fires again every orb_every_ticks (from orb_every_ticks on) from
##   shard (volley % shards), aimed at the player, through BulletPatterns.fire (its fairness: no shot spawns on the
##   player or in a wall; its caps). They carry LATE_CAUSE + the attack (the recap names the orbs).
## - Fast shots: every bolt_every_ticks over the whole active time (spin and window) a shard locks an aim line at the
##   player for the bolt attack's lock_ticks (0.4 s as shipped), then fires a fast bolt down it (the bolt attack's
##   speed, radius, range and damage; it carries that attack, so the recap names the bolt). No bolt fires while the
##   player stands within BOLT_SAFE_M of its shard.
## One shape function each (beam_at, shard_pos, bolt line), drawn and hit alike (EI-07). Pure: integer angles (Kin),
## the ai stream only for the first Cross's way.

## A body's shards' fast bolts look like this (FireballViews; the orbs' look is their pattern's).
const BOLT_LOOK := &"crown_bolt"
## The orbs' recap cause: BossSignatures.LATE_CAUSE + the attack (its late_cause_key).
const ORB_CAUSE := BossSignatures.LATE_CAUSE
## No bolt fires while the player's edge is this close to its shard (m).
const BOLT_SAFE_M := 1.0
## BossStore points of a Cross in progress: the bolt's shard (its origin) in point BOLT_AT; the bolt's angle (x) and
## the active tick it began aiming (y, -1 none) in BOLT_AIM; the spin's quarter ticks (x) in QUARTER.
const BOLT_AT := 0
const BOLT_AIM := 1
const QUARTER := 7


## True for a body that floats (a table with a Cross).
static func floats(w: World, i: int) -> bool:
	return BossAi.table_of(w, i).floats_home


# --- the body -----------------------------------------------------------------------------------------------------


## Tick phase 5 (BossAi.move): she glides toward the fight's centre (her own position without a fight), never past it.
static func drift(w: World, i: int, slow: float) -> void:
	var a := w.actors
	var s := a.state[i]
	if s == EnemyAi.State.SPAWN or s == BossAi.GATE or s == FinalBoss.SHATTER:
		return
	var home := w.final_fight.home if w.final_fight != null else a.pos(i)
	var at := a.pos(i)
	var to := home - at
	var dist := Kin.length(to)
	var speed := BossAi.table_of(w, i).speed * slow
	if dist <= 0.0001 or speed <= 0.0:
		return
	a.set_pos(i, at + to * (minf(speed, dist) / dist))


## Shard k's place at tick `tick`: shard_orbit_m from her centre, at its share of the turn plus the orbit's turn.
static func shard_pos(w: World, i: int, k: int, tick: int) -> Vector2:
	var t := BossAi.table_of(w, i)
	var n := maxi(1, t.shard_count)
	var ang := (tick * t.shard_turn_milli / 1000 + k * 4096 / n) & 4095
	return w.actors.pos(i) + Kin.dir(ang) * t.shard_orbit_m


## Every shard's place now.
static func shards(w: World, i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in BossAi.table_of(w, i).shard_count:
		out.append(shard_pos(w, i, k, w.tick))
	return out


# --- the Cross ----------------------------------------------------------------------------------------------------


## BossAi._lock, as the windup begins: the way it will turn (opposite to the last Cross's), its quarter from her HP,
## the arms aimed off the player, no bolt aiming.
static func lock(w: World, i: int, b: int) -> void:
	var bs := w.bosses
	var atk := BossAi.attack_of(w, i)
	if bs.span[b] == 1 or bs.span[b] == -1:
		bs.span[b] = -bs.span[b]
	else:
		bs.span[b] = 1 if w.rng_ai.range_int(0, 1) == 0 else -1
	bs.pts_x[b * BossStore.MAX_PTS + QUARTER] = quarter_of(w, i, atk)
	bs.pts_y[b * BossStore.MAX_PTS + BOLT_AIM] = -1.0
	keep_away(w, i)


## Each windup tick (BossAi.think): the arms keep the player midway between two of them, wherever they go; she faces
## the player.
static func keep_away(w: World, i: int) -> void:
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	if w.player_dead():
		return
	var aim := Kin.angle_of(w.player_pos() - a.pos(i))
	a.lock_a[i] = (aim + 2048 / maxi(1, atk.count)) & 4095
	a.facing[i] = aim


## The spin's quarter (ticks a quarter turn) for her HP now: quarter_ticks at full HP down to fast_quarter_ticks at
## none (integer).
static func quarter_of(w: World, i: int, atk: BossAttackTable) -> int:
	var a := w.actors
	var slow := atk.quarter_ticks
	var fast := atk.fast_quarter_ticks if atk.fast_quarter_ticks > 0 else slow
	return maxi(1, fast + (slow - fast) * clampi(a.hp[i], 0, a.max_hp[i]) / maxi(1, a.max_hp[i]))


## The quarter of the Cross in progress (set as its windup began).
static func quarter(w: World, i: int) -> int:
	return maxi(1, int(w.bosses.pts_x[BossAi.entry_of(w, i) * BossStore.MAX_PTS + QUARTER]))


## Arm 0's angle `st` active ticks in (st = 0: where the windup aimed it): a quarter turn every quarter along span's
## way, back the other way every reverse_ticks (an integer triangle wave, as the Gaze's).
static func angle_at(w: World, i: int, st: int) -> int:
	var atk := BossAi.attack_of(w, i)
	var period := maxi(1, atk.reverse_ticks)
	var into := st % period
	var along := into if (st / period) % 2 == 0 else period - into
	var turn := w.bosses.span[BossAi.entry_of(w, i)] * along * 1024 / quarter(w, i)
	return (w.actors.lock_a[i] + turn) & 4095


## Arm k's angle when arm 0's is `ang`.
static func arm_angle(atk: BossAttackTable, ang: int, k: int) -> int:
	return (ang + k * 4096 / maxi(1, atk.count)) & 4095


## The beam along angle `ang`: from her edge, as far as length_m unless a wall stops it.
static func beam_at(w: World, i: int, ang: int) -> Obb:
	var atk := BossAi.attack_of(w, i)
	var start := w.actors.pos(i) + Kin.dir(ang) * w.actors.radius[i]
	var run := EnemyAi.clear_run(w, start, ang, atk.length_m, atk.half_width_m)
	return AttackShapes.lane(start, ang, maxf(run, 0.01), atk.half_width_m)


## Every beam on spin tick `st`.
static func beams(w: World, i: int, st: int) -> Array[Obb]:
	var atk := BossAi.attack_of(w, i)
	var ang := angle_at(w, i, st)
	var out: Array[Obb] = []
	for k in atk.count:
		out.append(beam_at(w, i, arm_angle(atk, ang, k)))
	return out


## True while boss i's Cross is in its window (beams out, shield down).
static func in_window(w: World, i: int) -> bool:
	var atk := BossAi.attack_of(w, i)
	return (
		atk != null
		and atk.move == BossAttackTable.Move.CROSS
		and w.actors.state[i] == EnemyAi.State.ACTIVE
		and w.actors.state_t[i] >= atk.spin_ticks
	)


## Tick phase 6 (BossAi.resolve): while the beams turn they hurt a player one touches (at most once every
## burn_ticks; the hurt iframes still apply) and the orbs fly; over the whole active time the bolts aim and fire.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	if st >= atk.active_ticks:
		return
	if st < atk.spin_ticks:
		if st % atk.burn_ticks == 0:
			w.bosses.hit[b] = 0
		for o in beams(w, i, st):
			if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, o) != Vector2.ZERO:
				BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, o.center)
				break
		_orbs(w, i, atk, st)
	_bolts(w, i, b, atk, st)


## The orb volley running at spin tick st: [volley, its tick] (volley -1 before the first).
static func orb_volley(atk: BossAttackTable, st: int) -> Array[int]:
	if atk.pattern == null or atk.orb_every_ticks <= 0 or st < atk.orb_every_ticks:
		return [-1, 0]
	return [st / atk.orb_every_ticks - 1, st % atk.orb_every_ticks]


static func _orbs(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	var v := orb_volley(atk, st)
	if v[0] < 0:
		return
	var kw := BulletPatterns.wave_at(atk.pattern, v[1])
	if kw < 0:
		return
	var n := maxi(1, BossAi.table_of(w, i).shard_count)
	var c := shard_pos(w, i, v[0] % n, w.tick)
	BulletPatterns.fire(
		w,
		i,
		atk.pattern,
		kw,
		c,
		Kin.angle_of(w.player_pos() - c),
		atk.pattern.radius_m + BulletPatterns.MUZZLE_M,
		BossAi.powered(w, i, atk.damage),
		ORB_CAUSE + w.bosses.attack[BossAi.entry_of(w, i)]
	)


## The bolt attack of a Cross (null when it has none).
static func bolt_attack_of(w: World, i: int, atk: BossAttackTable) -> BossAttackTable:
	if atk.bolt_attack < 0 or atk.bolt_every_ticks <= 0:
		return null
	return BossAi.table_of(w, i).attacks[atk.bolt_attack]


static func _bolts(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var bolt := bolt_attack_of(w, i, atk)
	if bolt == null:
		return
	var bs := w.bosses
	var aim_t := int(bs.pts_y[b * BossStore.MAX_PTS + BOLT_AIM])
	var lock := maxi(1, bolt.lock_ticks)
	if aim_t >= 0 and st == aim_t + lock:
		_fire_bolt(w, i, b, atk, bolt)
		bs.pts_y[b * BossStore.MAX_PTS + BOLT_AIM] = -1.0
		return
	var every := atk.bolt_every_ticks
	if st < every or st % every != 0 or st + lock >= atk.active_ticks or w.player_dead():
		return
	var n := maxi(1, BossAi.table_of(w, i).shard_count)
	var at := shard_pos(w, i, (st / every) % n, w.tick)
	bs.set_pt(b, BOLT_AT, at)
	bs.pts_x[b * BossStore.MAX_PTS + BOLT_AIM] = Kin.angle_of(w.player_pos() - at)
	bs.pts_y[b * BossStore.MAX_PTS + BOLT_AIM] = st


## The bolt down its locked line, from its shard; none while the player stands on the shard.
static func _fire_bolt(
	w: World, i: int, b: int, atk: BossAttackTable, bolt: BossAttackTable
) -> void:
	var at := w.bosses.pt(b, BOLT_AT)
	var safe := BOLT_SAFE_M + w.player.radius_m
	var d := w.player_pos() - at
	if d.x * d.x + d.y * d.y < safe * safe or not EnemyAi.clear_of_walls(w, at, bolt.radius_m):
		return
	var dir := Kin.dir(int(w.bosses.pts_x[b * BossStore.MAX_PTS + BOLT_AIM]))
	w.queue_projectile(
		w.actors.ids[i],
		ActorStore.TEAM_ENEMY,
		at,
		dir * bolt.speed,
		BossAi.powered(w, i, bolt.damage),
		bolt.radius_m,
		bolt.bolt_life_ticks,
		SimEvent.TAG_PROJECTILE
	)
	w.set_pending_look(BOLT_LOOK)
	w.set_pending_cause(atk.bolt_attack)


## The bolt aiming now: {} or {"from" (its shard), "to" (where its line meets a wall, or its range), "angle",
## "progress" (0..1000 of the aim), "shard" (its index)}.
static func bolt_state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	if atk == null or atk.move != BossAttackTable.Move.CROSS:
		return {}
	if w.actors.state[i] != EnemyAi.State.ACTIVE:
		return {}
	var bolt := bolt_attack_of(w, i, atk)
	var b := BossAi.entry_of(w, i)
	var aim_t := int(w.bosses.pts_y[b * BossStore.MAX_PTS + BOLT_AIM])
	if bolt == null or aim_t < 0:
		return {}
	var at := w.bosses.pt(b, BOLT_AT)
	var ang := int(w.bosses.pts_x[b * BossStore.MAX_PTS + BOLT_AIM])
	var run := EnemyAi.clear_run(w, at, ang, bolt.speed * bolt.bolt_life_ticks, bolt.radius_m)
	var n := maxi(1, BossAi.table_of(w, i).shard_count)
	return {
		"from": at,
		"to": at + Kin.dir(ang) * run,
		"angle": ang,
		"progress":
		clampi((w.actors.state_t[i] - aim_t) * 1000 / maxi(1, bolt.lock_ticks), 0, 1000),
		"shard": (aim_t / maxi(1, atk.bolt_every_ticks)) % n,
	}


## Boss i's Cross for the views: {} or {"winding" (the spin-up: thin aim lines), "window" (beams out, shield down),
## "progress" (0..1000 of the windup, the spin, or the window), "arms" ([from, to, hit] per beam: where it runs now,
## the aim line's in the windup; empty in the window), "angle" (arm 0's, 1/4096 turns), "half_width", "way" (+1 or
## -1), "quarter" (ticks a quarter turn), "speed" (0..1000: how much faster than at full HP), "orb_shard" (the shard
## firing orbs now, -1 none), "bolt" (bolt_state)}.
static func state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if (
		atk == null
		or atk.move != BossAttackTable.Move.CROSS
		or (s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE)
	):
		return {}
	var winding := s == EnemyAi.State.WINDUP
	var st := w.actors.state_t[i]
	var window := not winding and st >= atk.spin_ticks
	var progress := 0
	if winding:
		progress = st * 1000 / maxi(1, atk.windup_ticks)
	elif window:
		progress = (st - atk.spin_ticks) * 1000 / maxi(1, atk.window_ticks)
	else:
		progress = st * 1000 / maxi(1, atk.spin_ticks)
	var ang := w.actors.lock_a[i] if winding else angle_at(w, i, mini(st, atk.spin_ticks - 1))
	var arms: Array = []
	if not window:
		for k in atk.count:
			var o := beam_at(w, i, arm_angle(atk, ang, k))
			var d := Kin.dir(o.angle)
			arms.append(
				[
					o.center - d * o.half.x,
					o.center + d * o.half.x,
					o.half.x * 2.0 < atk.length_m - 0.01
				]
			)
	var q := quarter(w, i)
	var span := maxi(1, atk.quarter_ticks - atk.fast_quarter_ticks)
	var orb := -1
	if not winding and not window:
		var v := orb_volley(atk, st)
		if v[0] >= 0 and v[1] < atk.pattern.duration_ticks():
			orb = v[0] % maxi(1, BossAi.table_of(w, i).shard_count)
	return {
		"winding": winding,
		"window": window,
		"progress": clampi(progress, 0, 1000),
		"arms": arms,
		"angle": ang,
		"half_width": atk.half_width_m,
		"way": w.bosses.span[BossAi.entry_of(w, i)],
		"quarter": q,
		"speed": clampi((atk.quarter_ticks - q) * 1000 / span, 0, 1000),
		"orb_shard": orb,
		"bolt": bolt_state(w, i),
	}
