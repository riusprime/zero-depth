class_name ProjectileMoves
extends RefCounted
## v0.6.0 MX4 (the M-list's projectile behaviours; SIM_CONTRACTS §8b): what a player projectile's spec makes it do in
## flight, read once when it spawns (World._apply_spawns) into ProjectileStore's behaviour columns and run in its
## sweep (World._projectile_hits, tick phase 6):
## - pierce N (Edge Rounds): a hit passes through, N times (the Hot pierce and Pulse Gun's come first);
## - return (Boomerang): at half its life it turns back toward the player, passing through every enemy (each sweep
##   leaves it past the body it hit), and ends at the player;
## - homing (Seeker): each tick it turns at most `homing` (1/4096 turns) toward the nearest enemy within HOME_M;
## - orbit first (Orbit Rounds): it circles the player at ORBIT_R_M for orbit_ticks, starting from its aim, then
##   leaves along the aim it came round to (its life waits for the orbit).
## No trig (Kin), no randomness; the columns are hashed only once a projectile had a behaviour.

const HOME_M := 8.0
const ORBIT_R_M := 1.4
## A piercing projectile leaves the enemy this far past its edge (as Heat's pierce).
const CLEARANCE_M := 0.02


## Projectile `pi` just spawned (World._apply_spawns): its spec's behaviours into the store's columns.
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or p.spec_key[pi] == "":
		return
	var s := Modifiers.book(w).find(p.spec_key[pi])
	if s == null or (s.pierce <= 0 and s.returns <= 0 and s.homing <= 0 and s.orbit_ticks <= 0):
		return
	p.moves = true
	p.pierce_left[pi] = s.pierce
	p.ret[pi] = 1 if s.returns > 0 else 0
	p.home[pi] = s.homing
	p.speed[pi] = Kin.length(Vector2(p.vel_x[pi], p.vel_y[pi]))
	if s.orbit_ticks > 0:
		p.orbit_t[pi] = s.orbit_ticks
		p.orbit_n[pi] = s.orbit_ticks
		p.orbit_a[pi] = Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
		p.life[pi] += s.orbit_ticks
	p.life0[pi] = p.life[pi] - s.orbit_ticks


## Before projectile `pi`'s sweep: an orbiting one steps round the player (its velocity is this tick's chord), a
## homing one turns, a returning one heads for the player (and ends there).
static func steer(w: World, pi: int) -> void:
	var p := w.projectiles
	if not p.moves or pi >= p.ret.size():
		return
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	if p.orbit_n[pi] > 0:
		if p.orbit_t[pi] > 0:  # one step round: this tick's chord to the next point of the circle
			p.orbit_t[pi] -= 1
			var done := p.orbit_n[pi] - p.orbit_t[pi]
			var ang := (p.orbit_a[pi] + done * SimTick.ANGLE_UNITS / p.orbit_n[pi]) & 4095
			var chord := w.player_pos() + Kin.dir(ang) * ORBIT_R_M - at
			p.vel_x[pi] = chord.x
			p.vel_y[pi] = chord.y
			return
		var out := Kin.dir(p.orbit_a[pi]) * p.speed[pi]  # round once: it leaves along the aim it began on
		p.vel_x[pi] = out.x
		p.vel_y[pi] = out.y
		p.orbit_n[pi] = 0
	if p.ret[pi] == 1 and p.life[pi] * 2 <= p.life0[pi]:
		p.ret[pi] = 2
	if p.ret[pi] == 2:
		var to := w.player_pos() - at
		var d := Kin.length(to)
		if d <= w.player.radius_m + p.radius[pi] + p.speed[pi]:
			p.life[pi] = 1
		if d > 0.0:
			var v := to * (p.speed[pi] / d)
			p.vel_x[pi] = v.x
			p.vel_y[pi] = v.y
		return
	if p.home[pi] > 0:
		var best := _nearest(w, at)
		if best >= 0:
			var want := Kin.angle_of(w.actors.pos(best) - at)
			var cur := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
			var v := Kin.dir(Kin.turn_toward(cur, want, p.home[pi])) * p.speed[pi]
			p.vel_x[pi] = v.x
			p.vel_y[pi] = v.y


static func _nearest(w: World, at: Vector2) -> int:
	var a := w.actors
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(at, HOME_M):
		if a.invuln[i] > 0:
			continue
		var d := Kin.length(a.pos(i) - at)
		if best < 0 or d < best_d:
			best = i
			best_d = d
	return best


## Projectile `pi` (swept from `from`) just hit actor `k`: one with pierce left, or a returning one, goes on
## through, left just past the body's far edge (as Heat.pierce). True when it went through.
static func pierce(w: World, pi: int, k: int, from: Vector2) -> bool:
	var p := w.projectiles
	if not p.moves or pi >= p.ret.size() or p.team[pi] != ActorStore.TEAM_PLAYER:
		return false
	if p.pierce_left[pi] <= 0 and p.ret[pi] == 0:
		return false
	if p.ret[pi] == 0:
		p.pierce_left[pi] -= 1
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var speed := Kin.length(v)
	if speed <= 0.0:
		return false
	var dir := v / speed
	var c := w.actors.pos(k) - from
	var along := c.dot(dir)
	var reach := w.actors.radius[k] + p.radius[pi] + CLEARANCE_M
	var perp2 := maxf(0.0, c.dot(c) - along * along)
	var out := from + dir * (along + sqrt(maxf(0.0, reach * reach - perp2)))
	p.pos_x[pi] = out.x
	p.pos_y[pi] = out.y
	return true


## An enemy's angle seen from `origin` within `reach` (the nearest; Seeker's arcs snap to it), or `angle`.
static func snap_angle(w: World, origin: Vector2, angle: int, reach: float) -> int:
	var best := _nearest(w, origin)
	if best < 0 or Kin.length(w.actors.pos(best) - origin) > reach:
		return angle
	return Kin.angle_of(w.actors.pos(best) - origin)


## The behaviour columns, once a projectile had a behaviour (ModifierRuntime.hash_into).
static func hash_into(w: World, h: StateHasher) -> void:
	var p := w.projectiles
	if not p.moves:
		return
	for arr: PackedInt32Array in [
		p.pierce_left, p.ret, p.home, p.orbit_t, p.orbit_n, p.orbit_a, p.life0
	]:
		h.add_ints(arr)
	h.add_f32s(p.speed)
