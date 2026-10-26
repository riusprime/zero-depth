class_name VoidShots
extends RefCounted
## v0.9.0 VP (owner C §6.4: "The player fires miniature black-hole projectiles. These projectiles travel in the aiming
## direction … nearby enemies experience a weak gravitational pull toward its trajectory. The projectile causes damage
## in a small area around itself. The gravitational effect is subtle … Enemies can still pursue and attack normally";
## §8 "a subtle pull that changes slightly the trajectory of enemies"; Q10 "No pull on them"; PLAN C54–C58, C70;
## ATTACK_FORMS.md F4): the Void form, the Gun's shot as a slow black hole (AttackSpec.void_mm, set by the Void card,
## data/modifiers/gun_void.tres). It replaces the v0.8.0 floor black hole (BlackHoles, deleted with it).
## - The shot: the Gun's bolt, one every 0.6 s at 0.6 × the orbs' speed, as far as an orb flies. It passes through
##   enemies (World's projectile pass skips them: is_void_projectile); a wall or the end of its flight ends it.
## - The aura: every enemy within void_mm (1.0 m; the area stat scales it; centre to the enemy's edge) takes the shot's
##   damage the tick it comes in, then every void_tick_ticks (0.2 s: 5 a second) while it stays in. The wait is per
##   shot and enemy (ModifierState.void_*), so a Twin's two shots each hit, and a shot passing by hits a standing enemy
##   twice. The hit is the shot's own (Attacks.land: its elements, its On Hit and On Kill hooks), each tick of a shot
##   its own root (as the Laser's ticks), fed on the "feeding" hits only (Laser's fair rule: the aura's tick over the
##   Gun's own orb period, at most every hit: 12 / 9, so every hit feeds, 5 a second at most on one enemy, under the
##   orbs' 6.7).
## - The pull: each tick an enemy within void_pull_mm (3 m) of a shot is drawn toward the shot's path (the line it
##   flies along, never a point) at up to void_pull_mmps (1.0 m/s), weaker with distance (none at the reach). It never
##   stacks: the pulls of every shot on one enemy add, then the sum is capped at the strongest one's top speed. Heavies
##   (a body of HEAVY_RADIUS_M or more) get HEAVY_PERMILLE of it; bosses, elites and enemies still spawning in none.
##   The separation push: the pull never draws an enemy toward a neighbour within SEP_M of its edge, and pushes them
##   apart as they close, so a crowd lines up along the path instead of bunching. The step is small (≤ 1/60 m), so
##   the walls' push in the next collision pass keeps every body out of them; the AI moves and attacks as before.
## Pure (EI-02): integer and float maths, no randomness (EI-05), the one clock (EI-03).

## A body this big or bigger is a heavy (Shield Bearer, Warden, Splitter): half the pull.
const HEAVY_RADIUS_M := 0.5
const HEAVY_PERMILLE := 500
## The pull stops this close to the path (m).
const PATH_GAP_M := 0.15
## The separation's reach past two bodies' edges (m).
const SEP_M := 0.3
## The aura's hit counter (ModifierRuntime.count): the feeding hits read it.
const COUNT_KEY := "#void"
## A hit that doesn't feed lands as this spec: no statuses, no hooks (made once, never written).
static var _bare: AttackSpec = null


static func _bare_spec() -> AttackSpec:
	if _bare == null:
		_bare = AttackSpec.new()
		_bare.id = &"void_bare"
	return _bare


## `s` is a Void shot (the Void form's).
static func is_void(s: AttackSpec) -> bool:
	return s != null and s.void_mm > 0


## Projectile `pi` is the player's Void shot (its own spec is one).
static func is_void_projectile(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return false
	return is_void(Attacks.projectile_spec(w, pi))


## The run's Gun shot is the Void now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_void(Modifiers.bolt(w))


## The aura's radius of `s` now (m): void_mm, the area stat on it.
static func aura_m(w: World, s: AttackSpec) -> float:
	return Stats.area(w, s.void_mm / 1000.0)


## The aura's radius of void projectile `sid` now (m): its own (v0.9.5 FC3: Big Shot's, Rapid Fire's, a mini's), the
## area stat on it.
static func aura_of(w: World, s: AttackSpec, sid: int) -> float:
	return Stats.area(w, VoidMods.aura_mm(w, s, sid) / 1000.0)


## The share of the aura's hits that feed statuses and hooks, per mille (Laser.feed_permille's rule on the aura tick).
static func feed_permille(w: World, s: AttackSpec) -> int:
	var orb := maxi(1, w.player.shot_period_ticks)
	return clampi(1000 * maxi(1, s.void_tick_ticks) / orb, 1, 1000)


## How much of the pull enemy `i` takes, per mille: none for a boss, an elite or one spawning in, half for a heavy.
static func pull_permille(w: World, i: int) -> int:
	var a := w.actors
	if a.invuln[i] > 0 or BossAi.is_boss_kind(a.kinds[i]):
		return 0
	if EliteAi.is_elite_kind(a.kinds[i]):  # v0.9.0 EL: an elite archetype
		return 0
	return HEAVY_PERMILLE if a.radius[i] >= HEAVY_RADIUS_M else 1000


## Tick phase 6 (ModifierRuntime.advance): the waits that are over leave; each Void shot's aura hits, then the pull.
static func advance(w: World) -> void:
	var s := w.mx
	for k in range(s.void_shot.size() - 1, -1, -1):
		if s.void_next[k] <= w.tick:
			s.void_shot.remove_at(k)
			s.void_foe.remove_at(k)
			s.void_next.remove_at(k)
	if w.player_dead() or not active(w):
		return
	var shots := _shots(w)
	if shots.is_empty():
		return
	for pi in shots:
		_aura(w, pi)
	var moves := steps(w, shots)
	var idx: PackedInt32Array = moves[0]
	var by: PackedVector2Array = moves[1]
	var a := w.actors
	for k in idx.size():
		a.set_pos(idx[k], a.pos(idx[k]) + by[k])


## The player's Void shots now (projectile indices, ascending).
static func _shots(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if is_void_projectile(w, pi):
			out.append(pi)
	return out


static func _waiting(s: ModifierState, shot: int, foe: int) -> bool:
	for k in s.void_shot.size():
		if s.void_shot[k] == shot and s.void_foe[k] == foe:
			return true
	return false


## Shot `pi`'s aura: every enemy in it that isn't waiting on this shot takes its hit (the class doc).
static func _aura(w: World, pi: int) -> void:
	var spec := Attacks.projectile_spec(w, pi)
	var p := w.projectiles
	var s := w.mx
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var sid := p.ids[pi]
	var wait := maxi(1, spec.void_tick_ticks)
	var pm := feed_permille(w, spec)
	var ctx: AttackContext = null
	for i in w.enemies_near(at, aura_of(w, spec, sid)):
		var aid := w.actors.ids[i]
		if _waiting(s, sid, aid):
			continue
		s.void_shot.append(sid)
		s.void_foe.append(aid)
		s.void_next.append(w.tick + wait)
		if ctx == null:
			var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
			var tags := SimEvent.TAG_AREA | SimEvent.TAG_PROJECTILE
			ctx = AttackContext.make(at, ang, p.damage[pi], w.take_root(), tags, &"")
			ctx.depth = spec.depth
			ctx.proc_pct = maxi(1, 100 >> spec.depth)
			ctx.secondary = (p.second_of(pi) & ProjectileStore.SECONDARY) != 0
		var pos := w.actors.pos(i)
		if Laser.feeds(ModifierRuntime.count(w, COUNT_KEY), pm):
			Attacks.land(w, spec, ctx, i, at, pos)
			continue
		var got := Attacks.land(w, _bare_spec(), ctx, i, at, pos)
		if got > 0 and w.actors.dead[i] == 1:
			Attacks.fire(w, spec, AttackSpec.Trigger.ON_KILL, ctx, pos)


## The pull's step on each enemy this tick from Void shots `shots` (pure: the tick applies it, the view leans by it):
## [actor indices ascending, each one's step (m)].
static func steps(w: World, shots: PackedInt32Array) -> Array:
	var a := w.actors
	var p := w.projectiles
	var sum := {}  # actor index -> the pulls added
	var top := {}  # actor index -> the strongest shot's top step on it (m a tick)
	for pi in shots:
		var spec := Attacks.projectile_spec(w, pi)
		var at := Vector2(p.pos_x[pi], p.pos_y[pi])
		var v := Vector2(p.vel_x[pi], p.vel_y[pi])
		var speed := Kin.length(v)
		var reach := VoidMods.pull_mm(w, spec, p.ids[pi]) / 1000.0
		var most := spec.void_pull_mmps / 1000.0 / SimTick.TICKS_PER_SECOND
		if reach <= 0.0 or most <= 0.0:
			continue
		var dir := v / speed if speed > 0.0 else Vector2.ZERO  # v0.9.5 FC3: a still void pulls toward its point
		for i in w.enemies_near(at, reach):
			var f := pull_permille(w, i)
			if f <= 0:
				continue
			var off := a.pos(i) - at
			var to_path := (dir * off.dot(dir) - off) if speed > 0.0 else -off  # to the nearest point of the path
			var d := Kin.length(to_path)
			if d <= PATH_GAP_M:
				continue
			var cap := most * f / 1000.0
			var near := clampf(1.0 - Kin.length(off) / (reach + a.radius[i]), 0.0, 1.0)
			var step := minf(cap * near, d - PATH_GAP_M)
			sum[i] = (sum.get(i, Vector2.ZERO) as Vector2) + to_path * (step / d)
			top[i] = maxf(float(top.get(i, 0.0)), cap)
	var idx := PackedInt32Array(sum.keys())
	idx.sort()
	var by := PackedVector2Array()
	for i in idx:
		by.append(_separate(w, i, sum[i], top[i]))
	return [idx, by]


## Enemy `i`'s pull `step` with the separation push (the class doc), capped at `cap` (m a tick).
static func _separate(w: World, i: int, step: Vector2, cap: float) -> Vector2:
	var a := w.actors
	var me := a.pos(i)
	for j in w.enemies_near(me, a.radius[i] + SEP_M):
		if j == i:
			continue
		var n := me - a.pos(j)
		var dn := Kin.length(n)
		var u := n / dn if dn > 0.0 else (Vector2.RIGHT if i < j else Vector2.LEFT)
		var inward := step.dot(u)
		if inward < 0.0:
			step -= u * inward
		var gap := a.radius[i] + a.radius[j] + SEP_M
		step += u * (cap * clampf((gap - dn) / gap, 0.0, 1.0))
	var size_m := Kin.length(step)
	return step * (cap / size_m) if size_m > cap else step


## The Void shots in flight for the views: [{id, pos, dir, aura (m), pull (m)}], in projectile order.
static func read(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active(w):
		return out
	var p := w.projectiles
	for pi in _shots(w):
		var spec := Attacks.projectile_spec(w, pi)
		var v := Vector2(p.vel_x[pi], p.vel_y[pi])
		var sp := Kin.length(v)
		(
			out
			. append(
				{
					"id": p.ids[pi],
					"pos": Vector2(p.pos_x[pi], p.pos_y[pi]),
					"dir": v / sp if sp > 0.0 else Vector2.RIGHT,
					"aura": aura_of(w, spec, p.ids[pi]),
					"pull": VoidMods.pull_mm(w, spec, p.ids[pi]) / 1000.0,
				}
			)
		)
	return out


## The enemies the pull draws now (the same steps the next tick applies): actor id -> its step (m a tick).
static func leans(w: World) -> Dictionary:
	var out := {}
	if not active(w):
		return out
	var moves := steps(w, _shots(w))
	var idx: PackedInt32Array = moves[0]
	var by: PackedVector2Array = moves[1]
	for k in idx.size():
		out[w.actors.ids[idx[k]]] = by[k]
	return out
