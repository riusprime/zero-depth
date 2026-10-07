class_name EnemyAi
extends RefCounted
## The v0.1.0 behaviours (owner Q3, 2026-10-06): Charger, Warden, Needle. A Warden turns only while it
## walks: once it starts a slam it is committed, so baiting the slam opens its back (the way to flank it).
## Each enemy is a small state machine in ActorStore (state, state_t, facing, lock_*, cd, fire_cd). think() runs
## in tick phase 3, move() in phase 5, resolve() in phase 6. Every attack's area comes from one function here,
## which the telegraph view also draws (EI-07): charge_lane, slam_disc, burst_line.

enum State { SPAWN, MOVE, WINDUP, ACTIVE, RECOVER }

const STRAFE_PERMILLE := 600


static func is_enemy_kind(kind: int) -> bool:
	return kind >= ActorStore.Kind.CHARGER


static func think(w: World, i: int) -> void:
	if Engines.frozen(w, i):  # Engines: a frozen enemy holds still, its state paused.
		return
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	a.state_t[i] += 1
	if a.cd[i] > 0:
		a.cd[i] -= 1
	var to_player := w.player_pos() - a.pos(i)
	var dist := Kin.length(to_player)
	var aim := Kin.angle_of(to_player)
	var alive := not w.player_dead()
	match a.state[i]:
		State.SPAWN:
			if a.state_t[i] >= SimTick.SPAWN_IN_TICKS:
				_enter(a, i, State.MOVE)
		State.MOVE:
			if a.kinds[i] == ActorStore.Kind.WARDEN:
				a.facing[i] = Kin.turn_toward(a.facing[i], aim, t.turn_rate)
			else:
				a.facing[i] = aim
			# A Needle backs off before it shoots; the others attack as soon as they're in range.
			var too_close := a.kinds[i] == ActorStore.Kind.NEEDLE and dist < t.flee_distance_m
			if alive and a.cd[i] == 0 and dist <= t.attack_range_m and not too_close:
				_start_windup(w, i, aim)
		State.WINDUP:
			if a.state_t[i] >= t.windup_ticks:
				_enter(a, i, State.ACTIVE)
				a.fire_cd[i] = 0
		State.ACTIVE:
			var done := false
			match a.kinds[i]:
				ActorStore.Kind.CHARGER:
					done = a.lock_len[i] <= 0.0
				ActorStore.Kind.NEEDLE:
					done = a.fire_cd[i] >= t.burst_count and a.state_t[i] >= t.active_ticks
				_:
					done = a.state_t[i] >= t.active_ticks
			if done:
				_enter(a, i, State.RECOVER)
		State.RECOVER:
			if a.state_t[i] >= t.recover_ticks:
				_enter(a, i, State.MOVE)
				a.cd[i] = t.cooldown_ticks


static func move(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var at := a.pos(i)
	# Items (v0.2.0 J): a Frost Core slow scales both the walk and the charge (1.0 when not slowed).
	var slow := ItemProcs.slow_factor(w, i)
	match a.state[i]:
		State.MOVE:
			var to := w.player_pos() - at
			var dist := Kin.length(to)
			if dist <= 0.0001 or w.player_dead():
				return
			var dir := to / dist
			if a.kinds[i] == ActorStore.Kind.NEEDLE:
				if dist < t.flee_distance_m:
					dir = -dir
				elif dist <= t.keep_distance_m + 1.0:
					var side := 1.0 if a.ids[i] % 2 == 0 else -1.0
					dir = Vector2(-dir.y, dir.x) * side * (STRAFE_PERMILLE / 1000.0)
			elif dist <= t.radius_m + w.player.radius_m + 0.1:
				return
			a.set_pos(i, at + steer(w, at, dir, t.radius_m) * (t.speed * slow))
		State.ACTIVE:
			if a.kinds[i] == ActorStore.Kind.CHARGER and a.lock_len[i] > 0.0:
				var step := minf(t.charge_speed * slow, a.lock_len[i])
				a.lock_len[i] -= step
				a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)


static func resolve(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] != State.ACTIVE or w.player_dead() or Engines.frozen(w, i):
		return
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var pr := w.player.radius_m
	match a.kinds[i]:
		ActorStore.Kind.CHARGER:
			if a.fire_cd[i] == 0 and Kin.length(p - a.pos(i)) <= t.radius_m + pr:
				a.fire_cd[i] = 1
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.WARDEN:
			if a.state_t[i] == 0:
				var disc := slam_disc(w, i)
				if AttackShapes.disc_touches(disc[0], disc[1], p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_AREA)
		ActorStore.Kind.NEEDLE:
			if a.fire_cd[i] < t.burst_count and a.state_t[i] % t.burst_gap_ticks == 0:
				a.fire_cd[i] += 1
				var dir := Kin.dir(a.lock_a[i])
				var muzzle := a.pos(i) + dir * (t.radius_m + t.bolt_radius_m + 0.05)
				w.queue_projectile(
					a.ids[i],
					ActorStore.TEAM_ENEMY,
					muzzle,
					dir * t.bolt_speed,
					t.damage,
					t.bolt_radius_m,
					t.bolt_life_ticks,
					SimEvent.TAG_PROJECTILE
				)


## Where to walk: `dir` when the straight line to the player is clear of walls (for a body of radius r), or
## else along the flow field (NavField). A Needle backing off or strafing (dir not toward the player) keeps dir
## unless a wall is right in front of it.
static func steer(w: World, at: Vector2, dir: Vector2, r: float) -> Vector2:
	var target := w.player_pos()
	var toward := Kin.length(target - at) > 0.0 and (target - at).dot(dir) > 0.0
	var probe := target if toward else at + dir * 1.0
	for wall in w.walls:
		if Collide.sweep_vs_obb(at, probe, r, wall) >= 0.0:
			var flow := w.nav.direction(at)
			return flow * Kin.length(dir) if flow != Vector2.ZERO else dir
	return dir


## The lane a Charger is about to run: its body's path from where it stands to its body's front at the end of
## the run (cut short by walls), as wide as its body.
static func charge_lane(w: World, i: int) -> Obb:
	var a := w.actors
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]),
		a.lock_a[i],
		maxf(a.lock_len[i], 0.0) + a.radius[i],
		a.radius[i]
	)


## [center, radius] of a Warden's slam.
static func slam_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).slam_radius_m]


## The line a Needle's burst flies down, as wide as its bolts, cut short by walls.
static func burst_line(w: World, i: int) -> Obb:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(a.lock_a[i]) * t.radius_m
	return AttackShapes.lane(start, a.lock_a[i], maxf(a.lock_len[i], 0.01), t.bolt_radius_m)


## What the view draws for actor i: {} or {"shape": &"lane"|&"disc", ..., "progress": 0..1000}.
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	if a.state[i] != State.WINDUP or not is_enemy_kind(a.kinds[i]):
		return {}
	var t := w.enemy_table(a.kinds[i])
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, t.windup_ticks), 0, 1000)
	match a.kinds[i]:
		ActorStore.Kind.CHARGER:
			return {"shape": &"lane", "obb": charge_lane(w, i), "progress": progress}
		ActorStore.Kind.WARDEN:
			var d := slam_disc(w, i)
			return {"shape": &"disc", "center": d[0], "radius": d[1], "progress": progress}
		ActorStore.Kind.NEEDLE:
			return {"shape": &"lane", "obb": burst_line(w, i), "progress": progress}
	return {}


static func _start_windup(w: World, i: int, aim: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	_enter(a, i, State.WINDUP)
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]
	a.lock_a[i] = aim
	match a.kinds[i]:
		ActorStore.Kind.CHARGER:
			a.lock_len[i] = _clear_run(w, a.pos(i), aim, t.charge_distance_m, t.radius_m)
		ActorStore.Kind.NEEDLE:
			var start := a.pos(i) + Kin.dir(aim) * t.radius_m
			a.lock_len[i] = _clear_run(
				w, start, aim, t.bolt_speed * t.bolt_life_ticks, t.bolt_radius_m
			)
		_:
			a.lock_len[i] = 0.0


## How far a circle of radius r can travel from `from` along `angle` (up to `length`) before a wall.
static func _clear_run(w: World, from: Vector2, angle: int, length: float, r: float) -> float:
	var to := from + Kin.dir(angle) * length
	var best := 1.0
	for wall in w.walls:
		var hit := Collide.sweep_vs_obb(from, to, r, wall)
		if hit >= 0.0 and hit < best:
			best = hit
	return length * best


static func _hit_player(w: World, i: int, amount: int, tags: int) -> void:
	var a := w.actors
	Damage.hit(w, 0, amount, a.ids[i], a.ids[i], w.take_root(), tags, a.pos(i), w.player_pos())


static func _enter(a: ActorStore, i: int, s: int) -> void:
	a.state[i] = s
	a.state_t[i] = 0
