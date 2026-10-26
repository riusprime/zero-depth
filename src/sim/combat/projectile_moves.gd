class_name ProjectileMoves
extends RefCounted
## v0.6.0 MX4 (the M-list's projectile behaviours; SIM_CONTRACTS §8b): what a player projectile's spec makes it do in
## flight, read once when it spawns (World._apply_spawns) into ProjectileStore's behaviour columns and run in its
## sweep (World._projectile_hits, tick phase 6):
## - pierce N (Edge Rounds): a hit passes through, N times (the Hot pierce and Pulse Gun's come first);
## - return (Boomerang; v0.9.0 AF2: the Glaive's disc, the card retired into it): at half its life it turns back
##   toward the player, passing through every enemy (each sweep leaves it past the body it hit), and ends at the
##   player;
## - homing (Seeker): each tick it turns at most `homing` (1/4096 turns) toward the nearest enemy within HOME_M (v0.9.0
##   AF2: a Seekers dart toward its own one of the enemies nearest the hero, Seekers.target);
## - orbit first (Orbit Rounds): it circles the player at ORBIT_R_M for orbit_ticks, starting from its aim, then
##   leaves along the aim it came round to (its life waits for the orbit).
## No trig (Kin), no randomness; the columns are hashed only once a projectile had a behaviour.

const HOME_M := 8.0
const ORBIT_R_M := 1.4
## A piercing projectile leaves the enemy this far past its edge (as Heat's pierce).
const CLEARANCE_M := 0.02


## Projectile `pi` just spawned (World._apply_spawns): its spec's behaviours into the store's columns.
static func on_spawn(w: World, pi: int, extra_pierce: int = 0) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or p.spec_key[pi] == "":
		return
	var s := Modifiers.book(w).find(p.spec_key[pi])
	if (
		s == null
		or (
			s.pierce + extra_pierce <= 0
			and s.returns <= 0
			and s.homing <= 0
			and s.orbit_ticks <= 0
			and not GunForms.moves(s)
		)
	):  # v0.6.5 WN3: spiral, mine
		return
	p.moves = true
	GunForms.on_spawn(w, pi, s)  # v0.6.5 WN3: before the orbit, so life0 counts the mine's wait
	p.pierce_left[pi] = s.pierce + extra_pierce  # v0.9.5 WB: the Wisps' shots pierce one more
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
	VoidMods.steer(w, pi)  # v0.9.5 FC3: a void's orbit, mine and homing
	LanceMods.steer(w, pi)  # v0.9.5 FC4: a lance's Homing
	if GlaiveMods.steer(w, pi):  # v0.9.5 FC6: a disc's Orbit lap and Mine hold set its velocity
		return
	if SeekerMods.steer(w, pi):  # v0.9.5 FC7: a dart's Orbit lap, Mine hold and Halo's straight flight
		return
	if GunForms.mine_waits(w, pi):  # v0.6.5 WN3: G12 Mine, still until touched
		return
	_steer(w, pi)
	GlaiveMods.steer_after(w, pi)  # v0.9.5 FC6: a disc's Homing, Ricochet's end
	GunForms.spiral_turn(w, pi)  # v0.6.5 WN3: G11 Spiral, after homing and the way back


static func _steer(w: World, pi: int) -> void:
	var p := w.projectiles
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
		elif p.life[pi] <= 1 and Glaive.is_disc(w, pi):
			p.life[pi] = 2  # v0.9.0 AF2: a Glaive disc's way home is not cut short (a pierce's push ate its life)
		if d > 0.0:
			var v := to * (p.speed[pi] / d)
			p.vel_x[pi] = v.x
			p.vel_y[pi] = v.y
		return
	if p.home[pi] > 0:
		var best := Seekers.target(w, pi)  # v0.9.0 AF2: a Seekers dart curves to its own enemy
		if best == Seekers.STRAIGHT:  # v0.9.5 FC7: no enemy left for it to seek
			return
		if best < 0:
			best = _nearest(w, at, HOME_M)
		if best >= 0:
			var want := Kin.angle_of(w.actors.pos(best) - at)
			var cur := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
			var v := Kin.dir(Kin.turn_toward(cur, want, p.home[pi])) * p.speed[pi]
			p.vel_x[pi] = v.x
			p.vel_y[pi] = v.y


## The nearest enemy whose body is within `r` of `at` (not invulnerable), or -1.
static func _nearest(w: World, at: Vector2, r: float) -> int:
	var a := w.actors
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(at, r):
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
	if p.ret[pi] == 1 and Glaive.is_disc(w, pi):  # v0.9.0 AF2: the push spends the disc's flight (it turns 7 m out)
		p.life[pi] = maxi(1, p.life[pi] - roundi(Kin.length(out - from) / speed))
	return true


## An enemy's angle seen from `origin` within `reach` (the nearest; Seeker's arcs snap to it), or `angle`. The search
## covers the reach itself, past HOME_M too (audit G-19); its centre must be within the reach (the search counts the
## body's radius).
static func snap_angle(w: World, origin: Vector2, angle: int, reach: float) -> int:
	var best := _nearest(w, origin, reach)
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
	for k in p.mine_t.size():  # v0.6.5 WN3: only once a projectile spiralled or waited
		if p.spiral[k] != 0 or p.mine_t[k] != 0:
			h.add_ints(p.spiral)
			h.add_ints(p.mine_t)
			break
