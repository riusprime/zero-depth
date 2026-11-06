class_name BossInterphase
extends RefCounted
## v0.9.5 BH6 (owner, 2026-10-25: "for phase 3, here is where the spice comes ... some interphases to him where he
## dissapears and then he makes different kind of patterns, with rays, balls, and thing that come out of the ground that
## make you dodge for about 15 seconds, this should feel like a 6/10 difficulty not impossible and then he comes
## back and the fight continues, I liked the darkness ability of the newer boss so we could also reuse that";
## BOSSES_HARD.md rows HC4, HC5): The Fallen vanishes twice.
## - The trigger (think, phase 3): when its HP falls to the first (66 %) and then the second (33 %) threshold of
##   InterphaseTable it finishes the move it is on (at most finish_ticks, 1 s; the move is cut then), vanishes in a
##   burst of violet runes (the STATUS_APPLY EFFECT_VANISH), and for `ticks` (15 s) the arena runs one pattern set.
##   The body stands in FinalBoss.INTERPHASE: untargetable (invulnerable, hidden, no clamp), its HP frozen. The pace
##   leaves the time out (FinalPace: no window, no bucket, no meter second; FinalFight.ip_total counts it).
## - The set (named stream `boss:interphase`, RngStream.derive by the floor, loop, interphase and a draw counter): drawn
##   with no repeat of the last interphase's set. RAYS: ip.beam_count thin beams from the arena's centre to its edge,
##   shown still for the telegraph then turning at beam_turn_milli, and a ground eruption under the hero every
##   erupt_ticks (never where a beam sweeps within 0.5 s of its strike). RAIN: ball rings from four points on the edge,
##   alternating the pairs (N, S then E, W) every rain_ticks, each ring a fan of rain_balls with two gaps of
##   rain_gap_slots; and lines of ground spikes walking across the arena every spike_ticks with one gap. LIGHTS OUT:
##   the Lantern Shade's darkness (four lanterns on the edge, the hero's own light, a lantern relit by walking near;
##   WorldReader.boss_light shows it through BossShade.state), slow drifting balls (never more than dark_balls alive)
##   and eruptions every dark_erupt_ticks.
## - Fair (the BH2 hard rules): every hit is a carrier attack's damage (15), every telegraph the carrier's windup (at
##   least 0.8 s), at most one interphase hit lands in any grace_ticks, a ball never spawns within SAFE_M of the hero,
##   there is always a gap (the rain's, the spike line's, the beams' wedges, between the eruptions).
## - The return: the shots go, the room relights, a ring of slam_m shows at the arena's centre for the return carrier's
##   windup (1 s), then it slams back down there (the carrier's damage) and the fight goes on where it was.
## Hazards that are not projectiles are sim state in FinalFight (er_*, sl_*, lamp_t), saved and hashed. Pure: integer
## angles (Kin), draws only from the named stream.

const SET_RAYS := 0
const SET_RAIN := 1
const SET_DARK := 2
const SETS := 3
const STAGE_NONE := 0
const STAGE_WAIT := 1
const STAGE_VANISHED := 2
const STAGE_RETURN := 3
## BossAi state of the vanished body (after FinalBoss.SHATTER).
const STATE := 11
## STATUS_APPLY effect ids for the views and the sound: it vanishes (amount: the set), the beams go live, an eruption
## strikes, the dark falls, a ring of balls leaves, a spike line starts to walk, it slams back.
const EFFECT_VANISH := &"fallen_vanish"
const EFFECT_BEAMS := &"fallen_rays"
const EFFECT_ERUPT := &"fallen_erupt"
const EFFECT_DARK := &"fallen_dark"
const EFFECT_RAIN := &"fallen_rain"
const EFFECT_LINE := &"fallen_line"
const EFFECT_RETURN := &"fallen_return"
## The balls' look (the Prism's orb: FireballViews).
const BALL_LOOK := &"crown_orb"
## After an interphase no other begins for this long (ticks).
const COOLDOWN_TICKS := 300
## Balls never spawn within this of the hero's edge, and the arena's edge a ring is fired from.
const SAFE_M := 4.0
## The arena's radius when no wall is found round its centre (a test world), and its most.
const FALLBACK_R := 12.0
const MAX_R := 20.0
## The spike line walks between these shares of the radius either side of the centre; its middle sits within
## +-OFF_SHARE of the radius across.
const LINE_SHARE := 0.85
const OFF_SHARE := 0.55
## An eruption's burst stays in the state this many ticks after it strikes (the view's burst).
const BURST_TICKS := 8
## Eruptions keep clear of beams for this many ticks either side of their strike (0.5 s in all).
const OVERLAP_TICKS := 15
## The slots of a ring and which two runs of them are the gaps, by variant.
const GAP_RUNS := [[3, 10], [6, 13]]

# --- reads -----------------------------------------------------------------------------------------------------


## The Fallen's interphase table for the current body, or null.
static func table_of(w: World) -> InterphaseTable:
	var t := FinalPace.table(w)
	return t.interphase if t != null else null


## True while the body is vanished or returning.
static func active(w: World) -> bool:
	return w.final_fight != null and w.final_fight.ip_stage >= STAGE_VANISHED


## The arena's radius from its centre to the ring's inner face (the least wall run in sixteen ways).
static func arena_radius(w: World) -> float:
	var home := w.final_fight.home
	var best := 99.0
	for k in 16:
		best = minf(best, EnemyAi.clear_run(w, home, k * 256, 60.0, 0.05))
	return FALLBACK_R if best > 50.0 else minf(best, MAX_R)


## Interphase `k` (0 first) is the next to come, or -1.
static func next_index(f: FinalFight, ip: InterphaseTable) -> int:
	for k in ip.thresholds.size():
		if f.ip_done & (1 << k) == 0:
			return k
	return -1


static func _rng(w: World, f: FinalFight) -> RngStream:
	f.ip_n += 1
	return RngStream.derive(
		w.seed_value, "boss:interphase:%d:%d:%d:%d" % [w.floor_index, w.loop, f.ip_done, f.ip_n]
	)


static func _windup(t: BossTable, k: int) -> int:
	return t.attacks[k].windup_ticks if k >= 0 else 48


# --- the trigger: tick phase 3 ----------------------------------------------------------------------------------


## BossAi.think: true when body i is in an interphase (BossAi then does nothing else this tick).
static func think(w: World, i: int, b: int, t: BossTable) -> bool:
	var ip := t.interphase
	var f := w.final_fight
	if ip == null or f == null or not FinalBoss.is_body(w, i):
		return false
	var a := w.actors
	if f.ip_stage >= STAGE_VANISHED:
		a.invuln[i] = maxi(a.invuln[i], 2)
		return true
	var s := a.state[i]
	if s == EnemyAi.State.SPAWN or s == BossAi.GATE or s == FinalBoss.SHATTER or a.dead[i] == 1:
		return false
	if f.ip_stage == STAGE_NONE:
		var k := next_index(f, ip)
		if k < 0 or w.tick < f.ip_a or w.player_dead():
			return false
		if a.hp[i] * 1000 > ip.thresholds[k] * a.max_hp[i]:
			return false
		f.ip_stage = STAGE_WAIT
		f.ip_t = 0
	f.ip_t += 1
	if s == EnemyAi.State.MOVE or f.ip_t >= ip.finish_ticks:
		_vanish(w, i, b, t, ip)
		return true
	return false


static func _vanish(w: World, i: int, b: int, t: BossTable, ip: InterphaseTable) -> void:
	var f := w.final_fight
	var a := w.actors
	var k := next_index(f, ip)
	var rng := _rng(w, f)
	var pick := rng.range_int(0, SETS - 1 if f.ip_prev < 0 else SETS - 2)
	if f.ip_prev >= 0 and pick >= f.ip_prev:
		pick += 1  # the last set is left out of the draw
	f.ip_done |= 1 << k
	f.ip_prev = pick
	f.ip_stage = STAGE_VANISHED
	f.ip_dir = 1 if rng.range_int(0, 1) == 0 else -1
	f.ip_angle0 = rng.range_int(0, 4095)
	f.ip_r = arena_radius(w)
	f.ip_grace = w.tick
	set_up(w, t, ip, f, pick)
	f.rd_pending = 0
	f.rd_t = 0
	f.dash_t = 0
	f.dash_due = -1
	f.copying = false
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = EFFECT_VANISH
	e.amount = pick
	w.bosses.attack[b] = -1
	w.bosses.hit[b] = 0
	a.lock_len[i] = 0.0
	a.state[i] = STATE
	a.state_t[i] = 0
	a.invuln[i] = maxi(a.invuln[i], 2)
	a.set_pos(i, f.home)
	FinalBoss.clear_shots(w)


## Starts set `pick` from its first tick: the hazards cleared and the set's two clocks (ip_a, ip_b) and lanterns set.
## (Public for the tests, which run each set by itself.)
static func set_up(w: World, t: BossTable, ip: InterphaseTable, f: FinalFight, pick: int) -> void:
	f.ip_set = pick
	f.ip_t = 0
	_clear_hazards(f)
	match pick:
		SET_RAYS:
			f.ip_a = 30
		SET_RAIN:
			f.ip_a = _windup(t, ip.atk_rain)
			f.ip_b = 120
			_schedule_lines(w, t, ip, f)
		_:
			f.ip_a = 60
			f.ip_b = 90
			var lit := PackedInt32Array()
			lit.resize(4)
			lit.fill(ip.lamp_ticks)
			f.lamp_t = lit
	FinalBoss.clear_shots(w)


## The Rain's spike lines, all drawn at the set's start (the stream) so that no ball is ever fired into one: the nth
## walks from stage tick 120 + n x spike_ticks plus the telegraph, while it can still cross before the 15 s end.
static func _schedule_lines(w: World, t: BossTable, ip: InterphaseTable, f: FinalFight) -> void:
	var tw := _windup(t, ip.atk_rain)
	var st := f.ip_b
	while st + tw + _line_ticks(ip, f) < ip.ticks:
		_add_line(w, ip, f, w.tick + st + tw)
		st += ip.spike_ticks


static func _clear_hazards(f: FinalFight) -> void:
	f.er_x = PackedFloat32Array()
	f.er_y = PackedFloat32Array()
	f.er_t = PackedInt32Array()
	f.sl_x = PackedFloat32Array()
	f.sl_y = PackedFloat32Array()
	f.sl_a = PackedInt32Array()
	f.sl_t = PackedInt32Array()
	f.sl_len = PackedFloat32Array()
	f.sl_off = PackedFloat32Array()
	f.sl_hit = PackedInt32Array()
	f.lamp_t = PackedInt32Array()


# --- the interphase: tick phase 6 -------------------------------------------------------------------------------


## BossSignatures.advance: the set's hazards run, then the return.
static func advance(w: World) -> void:
	var f := w.final_fight
	if f == null or f.ip_stage < STAGE_VANISHED:
		return
	var i := FinalBoss.body_index(w)
	var ip := table_of(w)
	if i < 0 or ip == null:
		return
	var t := BossAi.table_of(w, i)
	w.actors.invuln[i] = maxi(w.actors.invuln[i], 2)
	f.ip_total += 1
	if f.ip_stage == STAGE_VANISHED:
		_run(w, i, t, ip, f)
		f.ip_t += 1
		if f.ip_t >= ip.ticks:
			_begin_return(w, f)
	else:
		f.ip_t += 1
		if f.ip_t >= _windup(t, ip.atk_return):
			_slam(w, i, t, ip, f)


static func _run(w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight) -> void:
	var st := f.ip_t
	match f.ip_set:
		SET_RAYS:
			_rays(w, i, t, ip, f, st)
		SET_RAIN:
			_rain(w, i, t, ip, f, st)
		_:
			_dark(w, i, t, ip, f, st)
	_erupts(w, i, t, ip, f)


# --- rays -------------------------------------------------------------------------------------------------------


## Beam j's angle (1/4096 turns) at stage tick st: still through the telegraph, then turning.
static func beam_angle(ip: InterphaseTable, f: FinalFight, t: BossTable, j: int, st: int) -> int:
	var live := maxi(0, st - _windup(t, ip.atk_rays))
	var turned := live * ip.beam_turn_milli / 1000 * f.ip_dir
	return (f.ip_angle0 + turned + j * 4096 / maxi(1, ip.beam_count)) & 4095


static func beam_obb(ip: InterphaseTable, f: FinalFight, t: BossTable, j: int, st: int) -> Obb:
	return AttackShapes.lane(f.home, beam_angle(ip, f, t, j, st), f.ip_r, ip.beam_half_m)


static func _rays(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, st: int
) -> void:
	var tw := _windup(t, ip.atk_rays)
	if st == tw:
		_cue(w, i, EFFECT_BEAMS, ip.beam_count)
	if st >= tw and not w.player_dead():
		for j in ip.beam_count:
			var box := beam_obb(ip, f, t, j, st)
			if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box) != Vector2.ZERO:
				_hit(w, i, t, ip, f, ip.atk_rays, w.player_pos())
				break
	var erw := _windup(t, ip.atk_erupt)
	if st >= f.ip_a and st + erw + OVERLAP_TICKS < ip.ticks and not w.player_dead():
		var spot := _free_spot(w, t, ip, f, st, erw)
		if spot.x < 1.0e8:
			_add_erupt(f, spot, w.tick + erw)
			f.ip_a = st + ip.erupt_ticks
		else:
			f.ip_a = st + 6


## The eruption's place: under the hero, else nudged (1.5 m, then 3 m, eight ways) off the beams' sweep, else none
## (x = 1e9). It keeps inside the arena and clear of every beam for OVERLAP_TICKS either side of the strike.
static func _free_spot(
	w: World, t: BossTable, ip: InterphaseTable, f: FinalFight, st: int, erw: int
) -> Vector2:
	var p := w.player_pos()
	var r := ip.erupt_m + w.player.radius_m
	var tries: Array[Vector2] = [p]
	for ring in [1.5, 3.0]:
		for k in 8:
			tries.append(p + Kin.dir(k * 512) * ring)
	for c in tries:
		if Kin.length(c - f.home) > f.ip_r - 1.0:
			continue
		if f.ip_set == SET_RAYS and not _beams_clear(ip, f, t, c, r, st + erw):
			continue
		if not _balls_clear(w, c, r, erw):
			continue
		return c
	return Vector2(1.0e9, 1.0e9)


## True when no ball on the floor, flying on as it does, touches the disc (c, r) in the 0.5 s round the strike (erw
## ticks on).
static func _balls_clear(w: World, c: Vector2, r: float, erw: int) -> bool:
	var p := w.projectiles
	for k in p.size():
		if (
			p.team[k] == ActorStore.TEAM_PLAYER
			or k >= p.look.size()
			or p.look[k] != String(BALL_LOOK)
		):
			continue
		var from := Vector2(p.pos_x[k], p.pos_y[k])
		var vel := Vector2(p.vel_x[k], p.vel_y[k])
		for tt in [erw - OVERLAP_TICKS, erw, erw + OVERLAP_TICKS]:
			if Kin.length(from + vel * tt - c) <= r + p.radius[k]:
				return false
	return true


## True when no live beam touches the disc (c, r) in the 0.5 s round stage tick `strike`.
static func _beams_clear(
	ip: InterphaseTable, f: FinalFight, t: BossTable, c: Vector2, r: float, strike: int
) -> bool:
	var tw := _windup(t, ip.atk_rays)
	var tt := strike - OVERLAP_TICKS
	while tt <= strike + OVERLAP_TICKS:
		if tt >= tw:
			for j in ip.beam_count:
				if Collide.circle_vs_obb(c, r, beam_obb(ip, f, t, j, tt)) != Vector2.ZERO:
					return false
		tt += 3
	return true


static func _add_erupt(f: FinalFight, at: Vector2, strike: int) -> void:
	f.er_x.append(at.x)
	f.er_y.append(at.y)
	f.er_t.append(strike)


## Eruptions strike on their tick (the carrier's damage inside erupt_m), stay BURST_TICKS, then go.
static func _erupts(w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight) -> void:
	for k in range(f.er_t.size() - 1, -1, -1):
		var at := Vector2(f.er_x[k], f.er_y[k])
		if w.tick == f.er_t[k]:
			_cue(w, i, EFFECT_ERUPT, 1, at)
			if (
				not w.player_dead()
				and AttackShapes.disc_touches(at, ip.erupt_m, w.player_pos(), w.player.radius_m)
			):
				_hit(w, i, t, ip, f, ip.atk_erupt, at)
		elif w.tick > f.er_t[k] + BURST_TICKS:
			f.er_x.remove_at(k)
			f.er_y.remove_at(k)
			f.er_t.remove_at(k)


# --- rain -------------------------------------------------------------------------------------------------------


## The four points a ring is fired from (north, east, south, west), inset from the edge; and their inward heading.
static func ring_point(f: FinalFight, ip: InterphaseTable, k: int) -> Vector2:
	return f.home + Kin.dir(k * 1024) * (f.ip_r - ip.rain_inset_m)


static func _rain(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, st: int
) -> void:
	if st == f.ip_a and st + _windup(t, ip.atk_rain) < ip.ticks and not w.player_dead():
		var n := (st - _windup(t, ip.atk_rain)) / maxi(1, ip.rain_ticks)
		_ring(w, i, t, ip, f, n)
		f.ip_a = st + ip.rain_ticks
		_cue(w, i, EFFECT_RAIN, n % 2)
	var tw := _windup(t, ip.atk_rain)
	for k in f.sl_t.size():
		if w.tick == f.sl_t[k] - tw:
			_cue(w, i, EFFECT_LINE, 1)
	_lines(w, i, t, ip, f)


## The pair of points ring n leaves from: north and south, then east and west.
static func ring_pair(n: int) -> Array[int]:
	if n % 2 == 0:
		return [0, 2]
	return [1, 3]


## The slot indices of a ring that are gaps, for ring n (the runs alternate every second ring).
static func gap_slots(ip: InterphaseTable, n: int) -> Array[int]:
	var runs: Array = GAP_RUNS[(n / 2) % GAP_RUNS.size()]
	var out: Array[int] = []
	for start: int in runs:
		for s in ip.rain_gap_slots:
			out.append(start + s)
	return out


## The angle of slot s of ring n from point k: a half circle opening toward the arena's centre.
static func slot_angle(ip: InterphaseTable, k: int, s: int) -> int:
	var inward := (k * 1024 + 2048) & 4095
	return (inward - 1024 + 2048 * s / maxi(1, ip.rain_balls - 1)) & 4095


static func _ring(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, n: int
) -> void:
	var gaps := gap_slots(ip, n)
	var life := int(f.ip_r * 2.0 / ip.rain_speed) + 30
	var dmg := BossAi.powered(w, i, t.attacks[ip.atk_rain].damage)
	var p := w.player_pos()
	for k in ring_pair(n):
		var from := ring_point(f, ip, k)
		for s in ip.rain_balls:
			if gaps.has(s):
				continue
			var ang := slot_angle(ip, k, s)
			var at := from + Kin.dir(ang) * (ip.rain_radius_m + 0.1)
			if Kin.length(at - p) < SAFE_M * 0.5 + w.player.radius_m:
				continue
			var vel := Kin.dir(ang) * ip.rain_speed
			if crosses_line(w.tick, f, ip, at, vel, ip.rain_radius_m, life):
				continue  # a spike line walks over its path within 0.5 s of its passing: no two sources on one spot
			_ball(w, i, at, vel, dmg, ip.rain_radius_m, life, ip.atk_rain)


## True when a ball launched at tick `from_tick` from `at` with `vel` (m per tick), radius r, living `life` ticks would
## be on a spike line's footprint within 0.5 s of it standing there (Rain schedules all its lines first).
static func crosses_line(
	from_tick: int,
	f: FinalFight,
	ip: InterphaseTable,
	at: Vector2,
	vel: Vector2,
	r: float,
	life: int
) -> bool:
	var margin := ip.spike_speed * OVERLAP_TICKS  # the line's own travel inside the half second
	var travel := _line_ticks(ip, f)
	var t := 0
	while t <= life:
		var tick := from_tick + t
		var p := at + vel * t
		for k in f.sl_t.size():
			if tick < f.sl_t[k] - OVERLAP_TICKS or tick > f.sl_t[k] + travel + OVERLAP_TICKS:
				continue
			var way := f.sl_a[k]
			var rel := p - Vector2(f.sl_x[k], f.sl_y[k])
			var along := rel.dot(Kin.dir(way)) - line_walked(ip, f, k, tick)
			if absf(along) > ip.spike_half_m + r + margin:
				continue
			var lateral := rel.dot(Kin.dir((way + 1024) & 4095))
			if absf(lateral - f.sl_off[k]) <= f.sl_len[k] * 0.5 + r:
				return true
		t += 12
	return false


static func _ball(
	w: World, i: int, at: Vector2, vel: Vector2, dmg: int, r: float, life: int, atk: int
) -> void:
	if not BulletPatterns.room(w):
		return
	w.queue_projectile(
		w.actors.ids[i], ActorStore.TEAM_ENEMY, at, vel, dmg, r, life, SimEvent.TAG_PROJECTILE
	)
	w.set_pending_look(BALL_LOOK)
	w.set_pending_cause(atk)


static func _line_ticks(ip: InterphaseTable, f: FinalFight) -> int:
	return int(f.ip_r * 2.0 * LINE_SHARE / ip.spike_speed)


## A spike line: its first place (LINE_SHARE of the radius back from the centre along its way), its way (one of four,
## from the stream), where its middle sits across the arena (within OFF_SHARE of the radius), the tick it starts to
## walk. It is spike_len_m long, so the arena stays open either side of it.
static func _add_line(w: World, ip: InterphaseTable, f: FinalFight, walks_at: int) -> void:
	var rng := _rng(w, f)
	var way := rng.range_int(0, 3) * 1024
	var off := rng.range_int(-1000, 1000) / 1000.0 * OFF_SHARE * f.ip_r
	var start := f.home - Kin.dir(way) * (LINE_SHARE * f.ip_r)
	f.sl_x.append(start.x)
	f.sl_y.append(start.y)
	f.sl_a.append(way)
	f.sl_t.append(walks_at)
	f.sl_len.append(ip.spike_len_m)
	f.sl_off.append(off)
	f.sl_hit.append(0)


## Line k's box where it stands `walked` metres on (a one-box array).
static func line_boxes(ip: InterphaseTable, f: FinalFight, k: int, walked: float) -> Array[Obb]:
	var way := f.sl_a[k]
	var at := Vector2(f.sl_x[k], f.sl_y[k]) + Kin.dir(way) * walked
	var side := Kin.dir((way + 1024) & 4095)
	var out: Array[Obb] = []
	out.append(
		Obb.make(
			at + side * f.sl_off[k],
			Vector2(f.sl_len[k] * 0.5, ip.spike_half_m),
			(way + 1024) & 4095
		)
	)
	return out


## Metres line k has walked at `tick` (0 through its telegraph).
static func line_walked(ip: InterphaseTable, f: FinalFight, k: int, tick: int) -> float:
	return clampf((tick - f.sl_t[k]) * ip.spike_speed, 0.0, f.ip_r * 2.0 * LINE_SHARE)


static func _lines(w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight) -> void:
	for k in range(f.sl_t.size() - 1, -1, -1):
		if w.tick < f.sl_t[k]:
			continue
		var walked := line_walked(ip, f, k, w.tick)
		if f.sl_hit[k] == 0 and not w.player_dead():
			for box in line_boxes(ip, f, k, walked):
				if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box) != Vector2.ZERO:
					f.sl_hit[k] = 1
					_hit(w, i, t, ip, f, ip.atk_rain, box.center)
					break
		if walked >= f.ip_r * 2.0 * LINE_SHARE - 0.001:
			f.sl_x.remove_at(k)
			f.sl_y.remove_at(k)
			f.sl_a.remove_at(k)
			f.sl_t.remove_at(k)
			f.sl_len.remove_at(k)
			f.sl_off.remove_at(k)
			f.sl_hit.remove_at(k)


# --- lights out -------------------------------------------------------------------------------------------------


static func lamp_pos(f: FinalFight, ip: InterphaseTable, k: int) -> Vector2:
	return f.home + Kin.dir(k * 1024) * (f.ip_r - ip.lamp_inset_m)


static func _dark(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, st: int
) -> void:
	if st == 0:
		_cue(w, i, EFFECT_DARK, 1)
	var reach := ip.relight_m + w.player.radius_m
	for k in f.lamp_t.size():
		if not w.player_dead() and Kin.length(lamp_pos(f, ip, k) - w.player_pos()) <= reach:
			f.lamp_t[k] = ip.lamp_ticks
		elif f.lamp_t[k] > 0:
			f.lamp_t[k] -= 1
	var life := _dark_life(ip, f)
	if st == f.ip_a and not w.player_dead():
		if st < ip.ticks - 120:
			_dark_ball(w, i, t, ip, f, life)
		f.ip_a = st + maxi(1, life / maxi(1, ip.dark_balls))
	var erw := _windup(t, ip.atk_erupt)
	if st >= f.ip_b and st + erw + OVERLAP_TICKS < ip.ticks and not w.player_dead():
		var spot := _free_spot(w, t, ip, f, st, erw)
		if spot.x < 1.0e8:
			_add_erupt(f, spot, w.tick + erw)
			f.ip_b = st + ip.dark_erupt_ticks
		else:
			f.ip_b = st + 6


static func _dark_life(ip: InterphaseTable, f: FinalFight) -> int:
	return int(f.ip_r * 1.5 / ip.dark_ball_speed)


static func _dark_ball(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, life: int
) -> void:
	var rng := _rng(w, f)
	var ang := rng.range_int(0, 4095)
	var at := f.home + Kin.dir(ang) * (f.ip_r - 0.8)
	var off := Vector2(rng.range_int(-2000, 2000), rng.range_int(-2000, 2000)) / 1000.0
	var to := w.player_pos() + off - at
	var d := Kin.length(to)
	if d < SAFE_M or Kin.length(at - w.player_pos()) < SAFE_M:
		return
	var dmg := BossAi.powered(w, i, t.attacks[ip.atk_dark].damage)
	_ball(w, i, at, to / d * ip.dark_ball_speed, dmg, ip.dark_ball_radius_m, life, ip.atk_dark)


## True when a disc of radius r at p is in the light of an interphase's Lights Out: within light_m of the hero or lamp_m
## of a lit lantern (always true outside one).
static func lit(w: World, p: Vector2, r: float = 0.0) -> bool:
	var f := w.final_fight
	var ip := table_of(w)
	if f == null or ip == null or f.ip_stage != STAGE_VANISHED or f.ip_set != SET_DARK:
		return true
	if not w.player_dead() and Kin.length(p - w.player_pos()) <= ip.light_m + r:
		return true
	for k in f.lamp_t.size():
		if f.lamp_t[k] > 0 and Kin.length(p - lamp_pos(f, ip, k)) <= ip.lamp_m + r:
			return true
	return false


# --- hits and cues ----------------------------------------------------------------------------------------------


## An interphase hit on the hero of carrier `atk`'s damage; none inside the grace of the last one or in a dash.
static func _hit(
	w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight, atk: int, from: Vector2
) -> void:
	if w.tick < f.ip_grace or w.player_dead() or w.is_dashing():
		return
	f.ip_grace = w.tick + ip.grace_ticks
	var id := w.actors.ids[i]
	var dmg := BossAi.powered(w, i, t.attacks[atk].damage)
	Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, from, w.player_pos())
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = atk


static func _cue(
	w: World, i: int, effect: StringName, amount: int, at: Vector2 = Vector2.ZERO
) -> void:
	var id := w.actors.ids[i]
	var e := w.emit_event(
		SimEvent.Kind.STATUS_APPLY, id, id, id, at if at != Vector2.ZERO else w.final_fight.home
	)
	e.effect_id = effect
	e.amount = amount


# --- the return -------------------------------------------------------------------------------------------------


static func _begin_return(w: World, f: FinalFight) -> void:
	f.ip_stage = STAGE_RETURN
	f.ip_t = 0
	_clear_hazards(f)
	FinalBoss.clear_shots(w)


static func _slam(w: World, i: int, t: BossTable, ip: InterphaseTable, f: FinalFight) -> void:
	var a := w.actors
	var b := BossAi.entry_of(w, i)
	if (
		not w.player_dead()
		and AttackShapes.disc_touches(f.home, ip.slam_m, w.player_pos(), w.player.radius_m)
	):
		_hit(w, i, t, ip, f, ip.atk_return, f.home)
	_cue(w, i, EFFECT_RETURN, 1)
	f.ip_stage = STAGE_NONE
	f.ip_t = 0
	f.ip_a = w.tick + COOLDOWN_TICKS
	a.set_pos(i, f.home)
	a.invuln[i] = 0
	EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)
	a.cd[i] = maxi(a.cd[i], 30)
	w.bosses.attack[b] = -1


# --- the view's read (WorldReader.final_interphase) -------------------------------------------------------------


## {} outside an interphase's vanished or returning stages; else "stage", "set", "t", "ticks" (the stretch),
## "center", "radius", "beams" ([{"from", "angle", "len", "half", "live"}]), "erupts" ([{"pos", "radius", "progress"
## (0..1000 of its telegraph), "striking"}]), "lines" ([{"obbs", "way", "progress", "moving", "walked"}]), "points"
## ([{"pos", "angle", "warn" (0..1000 of the telegraph before the next ring leaves it, -1 none)}]), "ret" ({"center",
## "radius", "progress"}
## in the return stage).
static func state(w: World) -> Dictionary:
	var f := w.final_fight
	var ip := table_of(w)
	if f == null or ip == null or f.ip_stage < STAGE_VANISHED:
		return {}
	var i := FinalBoss.body_index(w)
	var t := BossAi.table_of(w, i) if i >= 0 else null
	if t == null:
		return {}
	var out := {
		"stage": f.ip_stage,
		"set": f.ip_set,
		"t": f.ip_t,
		"ticks": ip.ticks,
		"center": f.home,
		"radius": f.ip_r,
		"beams": [],
		"erupts": [],
		"lines": [],
		"points": [],
		"ret": {},
	}
	if f.ip_stage == STAGE_RETURN:
		out["ret"] = {
			"center": f.home,
			"radius": ip.slam_m,
			"progress": clampi(f.ip_t * 1000 / maxi(1, _windup(t, ip.atk_return)), 0, 1000),
		}
		return out
	if f.ip_set == SET_RAYS:
		var tw := _windup(t, ip.atk_rays)
		for j in ip.beam_count:
			(
				out["beams"]
				. append(
					{
						"from": f.home,
						"angle": beam_angle(ip, f, t, j, f.ip_t),
						"len": f.ip_r,
						"half": ip.beam_half_m,
						"live": f.ip_t >= tw,
						"progress": clampi(f.ip_t * 1000 / maxi(1, tw), 0, 1000),
					}
				)
			)
	var erw := _windup(t, ip.atk_erupt)
	for k in f.er_t.size():
		(
			out["erupts"]
			. append(
				{
					"pos": Vector2(f.er_x[k], f.er_y[k]),
					"radius": ip.erupt_m,
					"progress": clampi(1000 - (f.er_t[k] - w.tick) * 1000 / maxi(1, erw), 0, 1000),
					"striking": w.tick >= f.er_t[k],
				}
			)
		)
	for k in f.sl_t.size():
		var tw := _windup(t, ip.atk_rain)
		if w.tick < f.sl_t[k] - tw:
			continue  # scheduled, not shown yet
		var walked := line_walked(ip, f, k, w.tick)
		(
			out["lines"]
			. append(
				{
					"obbs": line_boxes(ip, f, k, walked),
					"way": f.sl_a[k],
					"progress": clampi(1000 - (f.sl_t[k] - w.tick) * 1000 / maxi(1, tw), 0, 1000),
					"moving": w.tick >= f.sl_t[k],
					"walked": walked,
				}
			)
		)
	if f.ip_set == SET_RAIN:
		_points(t, ip, f, out)
	return out


static func _points(t: BossTable, ip: InterphaseTable, f: FinalFight, out: Dictionary) -> void:
	var tw := _windup(t, ip.atk_rain)
	var n := maxi(0, (f.ip_a - tw) / maxi(1, ip.rain_ticks))
	var left := f.ip_a - f.ip_t
	var warn := clampi(1000 - left * 1000 / maxi(1, tw), 0, 1000) if left <= tw else -1
	var pair := ring_pair(n)
	for k in 4:
		(
			out["points"]
			. append(
				{
					"pos": ring_point(f, ip, k),
					"angle": (k * 1024 + 2048) & 4095,
					"warn": warn if pair.has(k) else -1,
				}
			)
		)


## The light for the view in the shape of BossShade.state (WorldReader.boss_light) while Lights Out runs, else {}.
static func light(w: World) -> Dictionary:
	var f := w.final_fight
	var ip := table_of(w)
	if f == null or ip == null or f.ip_stage != STAGE_VANISHED or f.ip_set != SET_DARK:
		return {}
	var lamps: Array[Dictionary] = []
	for k in f.lamp_t.size():
		(
			lamps
			. append(
				{
					"pos": lamp_pos(f, ip, k),
					"lit": f.lamp_t[k] > 0,
					"left": f.lamp_t[k],
					"frac": clampf(float(f.lamp_t[k]) / maxf(1.0, ip.lamp_ticks), 0.0, 1.0),
				}
			)
		)
	return {
		"dark": true,
		"falling": -1,
		"dark_left": -1,
		"light_m": ip.light_m,
		"lamp_m": ip.lamp_m,
		"lamp_ticks": ip.lamp_ticks,
		"lamps": lamps,
		"boss": -1,
		"boss_lit": true,
	}
