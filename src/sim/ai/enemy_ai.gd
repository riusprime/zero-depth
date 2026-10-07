class_name EnemyAi
extends RefCounted
## The v0.1.0 behaviours (owner Q3, 2026-10-06): Charger, Warden, Needle. A Warden turns only while it
## walks: once it starts a slam it is committed, so baiting the slam opens its back (the way to flank it).
## Each enemy is a small state machine in ActorStore (state, state_t, facing, lock_*, cd, fire_cd, windup, pick).
## think() runs in tick phase 3, move() in phase 5, resolve() in phase 6. Every attack's area comes from one function
## here, which the telegraph view also draws (EI-07): charge_lane, slam_disc, burst_lines, bolt_lanes, rune_disc,
## bomb_disc.
## v0.3.5 AI (owner F4-F6): each windup's length is drawn per attack (the ai:enemy stream); aimed shots lead the
## player by its velocity and keep tracking until the last COMMIT_TICKS of the windup; a charge turns toward the
## player at a limited rate; the Needle's burst fans out; enemies spread around the player instead of stacking.
## Two new kinds: the Arc Caster (a fast bolt, a 3-bolt spread, a rune that erupts under you) and the Bomb Drone
## (lobs a bomb whose circle fills until it lands). The drone hovers only in the view: here it is a ground body.
## v0.4.0 EN, six horde kinds: the Swarmer (a tiny Charger whose charge is a short lunge bite), the Splitter (swipes a
## disc ahead of it; dies into Splitlings, which swipe too and never split), the Shield Bearer (blocks from the front,
## turns slowly, bashes a short lane), the Mender (keeps away and heals hurt allies through a beam, no attack), the
## Mine Layer (drops mines; Mines) and the Sniper (a 60-tick line, a hit down it, then a walk to a new spot). Their
## shapes: swipe_disc, bash_lane, snipe_lane, Mines.telegraph.

enum State { SPAWN, MOVE, WINDUP, ACTIVE, RECOVER }

## The Arc Caster's spells (ActorStore.pick).
enum Spell { BOLT, SPREAD, RUNE }

const STRAFE_PERMILLE := 600
## Kinds that keep a distance band (_keeps_away).
const KEEP_AWAY: Array[int] = [
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE,
	ActorStore.Kind.MENDER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.SNIPER,
]
## Aimed windups stop tracking the player this many ticks before they fire (starting value, as the bosses').
const COMMIT_TICKS := 12
## Enemies closer than this to each other push apart while they walk (starting value).
const SPREAD_RADIUS_M := 1.6
const SPREAD_WEIGHT := 1.2
## Melee walkers inside this distance swing out to the side their id picks, so a pack surrounds the player.
const FLANK_RANGE_M := 6.0
const FLANK_MIN_M := 2.0
const FLANK_PERMILLE := 450
## A charge touches the player within this much of contact: the collision pass (phase 5) has already pushed the
## two bodies exactly apart before the hit check (phase 6), so an exact test missed by a rounding error (v0.3.5 AI).
const CONTACT_SLOP_M := 0.02
## v0.4.0 EN (starting values). A Sniper's line stops following the player this many ticks before it fires.
const SNIPE_COMMIT_TICKS := 24
## After a shot a Sniper walks, this much faster, to a spot 45-90 degrees around the player (1/4096 turns), until it
## is within RELOCATE_DONE_M of it or RELOCATE_MAX_TICKS have passed.
const RELOCATE_SPEED_PERMILLE := 1500
const RELOCATE_MIN_TURN := 512
const RELOCATE_MAX_TURN := 1024
const RELOCATE_DONE_M := 0.5
const RELOCATE_MAX_TICKS := 150
## A Mender without a patient looks for one every this many ticks (staggered by its id).
const MEND_SCAN_TICKS := 15
## A Splitter's halves appear this far to either side of where it died.
const SPLIT_OFFSET_M := 0.45


static func is_enemy_kind(kind: int) -> bool:
	return kind >= ActorStore.Kind.CHARGER


## The behaviour an actor kind runs: its own, except the Hive Lens's drones (v0.4.0 BO), which run the Needle's.
static func behaviour_of(kind: int) -> int:
	return ActorStore.Kind.NEEDLE if kind == ActorStore.Kind.LENS_DRONE else kind


## Chargers, the Brood Mother's hatchlings (v0.3.0 C, a small Charger) and Swarmers (v0.4.0 EN) run the charge.
static func _charges(kind: int) -> bool:
	return (
		kind == ActorStore.Kind.CHARGER
		or kind == ActorStore.Kind.HATCHLING
		or kind == ActorStore.Kind.SWARMER
	)


## Kinds that keep a distance band and shoot, lob, heal or lay mines from it (v0.3.5 AI, v0.4.0 EN).
static func _keeps_away(kind: int) -> bool:
	return kind in KEEP_AWAY


## Kinds that turn at a limited rate while they walk and hold their facing once they attack (v0.4.0 EN).
static func _turns_slowly(kind: int) -> bool:
	return kind == ActorStore.Kind.WARDEN or kind == ActorStore.Kind.SHIELD_BEARER


## Kinds whose hits are softened or blocked by the direction they come from (Damage.target_mult).
static func armoured(kind: int) -> bool:
	return kind == ActorStore.Kind.WARDEN or kind == ActorStore.Kind.SHIELD_BEARER


## The Mender (v0.4.0 EN): the target to kill first. The view marks it.
static func is_priority(kind: int) -> bool:
	return kind == ActorStore.Kind.MENDER


## True while actor i's windup aims a shot that still follows the player (it commits COMMIT_TICKS before it fires).
## A Sniper's line (v0.4.0 EN) follows until SNIPE_COMMIT_TICKS before the shot.
static func tracking(w: World, i: int) -> bool:
	var a := w.actors
	var sniper := a.kinds[i] == ActorStore.Kind.SNIPER
	var commit := SNIPE_COMMIT_TICKS if sniper else COMMIT_TICKS
	if a.state[i] != State.WINDUP or a.state_t[i] >= a.windup[i] - commit:
		return false
	return (
		sniper
		or behaviour_of(a.kinds[i]) == ActorStore.Kind.NEEDLE
		or (a.kinds[i] == ActorStore.Kind.ARC_CASTER and a.pick[i] != Spell.RUNE)
	)


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
			if _turns_slowly(a.kinds[i]):
				a.facing[i] = Kin.turn_toward(a.facing[i], aim, t.turn_rate)
			else:
				a.facing[i] = aim
			if a.kinds[i] == ActorStore.Kind.MENDER:
				_mend(w, i)  # v0.4.0 EN: heals instead of attacking.
				return
			if a.kinds[i] == ActorStore.Kind.SNIPER and a.pick[i] == 1:
				_end_relocation(a, i)
			# A Needle backs off before it shoots; the others attack as soon as they're in range.
			var too_close := behaviour_of(a.kinds[i]) == ActorStore.Kind.NEEDLE and dist < t.flee_distance_m
			if (
				alive
				and a.cd[i] == 0
				and dist <= t.attack_range_m
				and not too_close
				and _may_attack(w, i)
			):
				_start_windup(w, i, aim)
		State.WINDUP:
			if tracking(w, i) and alive:
				_aim(w, i)
			if a.state_t[i] >= a.windup[i]:
				_enter(a, i, State.ACTIVE)
				a.fire_cd[i] = 0
		State.ACTIVE:
			var done := false
			match behaviour_of(a.kinds[i]):
				ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
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
				if a.kinds[i] == ActorStore.Kind.SNIPER:
					_plan_relocation(w, i)


## Whether a horde kind may start its attack now (v0.4.0 EN; always true for the others): a Shield Bearer only at a
## player in front of it, a Mine Layer below its mine count, a Sniper once it has relocated.
static func _may_attack(w: World, i: int) -> bool:
	var a := w.actors
	match a.kinds[i]:
		ActorStore.Kind.SHIELD_BEARER:
			var aim := Kin.angle_of(w.player_pos() - a.pos(i))
			return Kin.angle_diff(aim, a.facing[i]) <= w.enemy_table(a.kinds[i]).front_half_arc
		ActorStore.Kind.MINE_LAYER:
			return Mines.count_of(w, a.ids[i]) < w.enemy_table(a.kinds[i]).max_mines
		ActorStore.Kind.SNIPER:
			return a.pick[i] == 0
	return true


## A relocating Sniper (v0.4.0 EN) is done once within RELOCATE_DONE_M of its spot or after RELOCATE_MAX_TICKS.
static func _end_relocation(a: ActorStore, i: int) -> void:
	var near := Kin.length(Vector2(a.lock_x[i], a.lock_y[i]) - a.pos(i)) <= RELOCATE_DONE_M
	if near or a.state_t[i] >= RELOCATE_MAX_TICKS:
		a.pick[i] = 0


## A Sniper's next spot (v0.4.0 EN): around the player by 45-90 degrees (a side drawn from ai:enemy), in the middle
## of its distance band. pick = 1 while it walks there.
static func _plan_relocation(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var turn := w.rng_enemy.range_int(RELOCATE_MIN_TURN, RELOCATE_MAX_TURN)
	if w.rng_enemy.chance_permille(500):
		turn = -turn
	var ang := (Kin.angle_of(a.pos(i) - p) + turn) & 4095
	var spot := p + Kin.dir(ang) * ((t.keep_min_m + t.keep_distance_m) * 0.5)
	a.lock_x[i] = spot.x
	a.lock_y[i] = spot.y
	a.pick[i] = 1


## The Mender (v0.4.0 EN): keeps its patient (pick) while it is alive, hurt and within heal_range_m, else looks for
## the most hurt ally in range every MEND_SCAN_TICKS; heals it heal_amount every heal_period_ticks (HEAL event).
static func _mend(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var j := a.index_of(a.pick[i]) if a.pick[i] > 0 else -1
	if j >= 0 and (a.dead[j] == 1 or a.hp[j] >= a.max_hp[j] or not _near(a, i, j, t.heal_range_m)):
		j = -1
	if j < 0 and (w.tick + a.ids[i]) % MEND_SCAN_TICKS == 0:
		j = _patient(w, i, t.heal_range_m)
	if j < 0:
		a.pick[i] = 0
		return
	if a.pick[i] != a.ids[j]:
		a.pick[i] = a.ids[j]
		a.cd[i] = t.heal_period_ticks  # a new beam takes a full period to land its first heal
	if a.cd[i] > 0:
		return
	a.cd[i] = t.heal_period_ticks
	var add := mini(t.heal_amount, a.max_hp[j] - a.hp[j])
	a.hp[j] += add
	var e := w.emit_event(SimEvent.Kind.HEAL, a.ids[i], a.ids[i], a.ids[j], a.pos(j))
	e.amount = add
	e.amount_applied = add


static func _near(a: ActorStore, i: int, j: int, r: float) -> bool:
	var d := a.pos(j) - a.pos(i)
	return absf(d.x) <= r and absf(d.y) <= r and Kin.length(d) <= r


## The most hurt (lowest HP share) normal enemy within r of Mender i, other than itself; -1 when none is hurt.
static func _patient(w: World, i: int, r: float) -> int:
	var a := w.actors
	var best := -1
	var best_share := 1000
	for j in range(1, a.size()):
		if j == i or a.dead[j] == 1 or a.hp[j] >= a.max_hp[j] or not is_enemy_kind(a.kinds[j]):
			continue
		if BossAi.is_boss_kind(a.kinds[j]) or not _near(a, i, j, r):
			continue
		var share := a.hp[j] * 1000 / maxi(1, a.max_hp[j])
		if share < best_share:
			best = j
			best_share = share
	return best


## A dying Splitter (v0.4.0 EN) splits into split_count Splitlings beside where it fell (they arrive in phase 9).
static func on_death(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	if t == null or t.split_count <= 0 or w.enemy_table(ActorStore.Kind.SPLITLING) == null:
		return
	var side := Kin.dir((a.facing[i] + 1024) & 4095)
	for k in t.split_count:
		var off := (k - (t.split_count - 1) * 0.5) * 2.0 * SPLIT_OFFSET_M
		w.queue_enemy(ActorStore.Kind.SPLITLING, a.pos(i) + side * off)


static func move(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var at := a.pos(i)
	# Items (v0.2.0 J): a Frost Core slow scales both the walk and the charge (1.0 when not slowed).
	var slow := ItemProcs.slow_factor(w, i)
	var hovering := a.kinds[i] == ActorStore.Kind.BOMB_DRONE and a.state[i] == State.WINDUP
	if a.state[i] == State.MOVE and a.kinds[i] == ActorStore.Kind.SNIPER and a.pick[i] == 1:
		_relocate(w, i, t, slow)
		return
	if a.state[i] == State.MOVE or hovering:
		var to := w.player_pos() - at
		var dist := Kin.length(to)
		if dist <= 0.0001 or w.player_dead():
			return
		var dir := to / dist
		var side := 1.0 if a.ids[i] % 2 == 0 else -1.0
		if behaviour_of(a.kinds[i]) == ActorStore.Kind.NEEDLE:
			if dist < t.flee_distance_m:
				dir = -dir
			elif dist <= t.keep_distance_m + 1.0:
				dir = Vector2(-dir.y, dir.x) * side * (STRAFE_PERMILLE / 1000.0)
		elif _keeps_away(a.kinds[i]):
			if dist < t.keep_min_m:
				dir = -dir
			elif dist <= t.keep_distance_m:
				dir = Vector2(-dir.y, dir.x) * side * (STRAFE_PERMILLE / 1000.0)
		elif dist <= t.radius_m + w.player.radius_m + 0.1:
			return
		elif dist > FLANK_MIN_M and dist < FLANK_RANGE_M:
			dir = _unit(dir + Vector2(-dir.y, dir.x) * side * (FLANK_PERMILLE / 1000.0))
		dir = _unit(dir + spread_push(w, i) * SPREAD_WEIGHT) * Kin.length(dir)
		a.set_pos(i, at + steer(w, at, dir, t.radius_m) * (t.speed * slow))
	elif a.state[i] == State.ACTIVE:
		if _charges(a.kinds[i]) and a.lock_len[i] > 0.0:
			# v0.3.5 AI (F4): the charge bends toward the player, at most charge_turn a tick.
			if t.charge_turn > 0 and not w.player_dead():
				var want := Kin.angle_of(w.player_pos() - at)
				a.lock_a[i] = Kin.turn_toward(a.lock_a[i], want, t.charge_turn)
				a.facing[i] = a.lock_a[i]
			var step := minf(t.charge_speed * slow, a.lock_len[i])
			a.lock_len[i] -= step
			a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)


## A Sniper walking to its next spot (v0.4.0 EN), RELOCATE_SPEED_PERMILLE of its speed.
static func _relocate(w: World, i: int, t: EnemyTable, slow: float) -> void:
	var a := w.actors
	var at := a.pos(i)
	var to := Vector2(a.lock_x[i], a.lock_y[i]) - at
	var d := Kin.length(to)
	if d <= 0.0001:
		return
	var step := minf(t.speed * slow * RELOCATE_SPEED_PERMILLE / 1000.0, d)
	a.set_pos(i, at + steer(w, at, to / d, t.radius_m) * step)


## The push that keeps enemy i off the other normal enemies near it: the sum, over each one closer than
## SPREAD_RADIUS_M, of the direction away from it weighted by how close it is (0 when alone).
static func spread_push(w: World, i: int) -> Vector2:
	var a := w.actors
	var at := a.pos(i)
	var push := Vector2.ZERO
	for j in range(1, a.size()):
		if j == i or a.dead[j] == 1 or not is_enemy_kind(a.kinds[j]):
			continue
		var d := at - a.pos(j)
		if absf(d.x) >= SPREAD_RADIUS_M or absf(d.y) >= SPREAD_RADIUS_M:
			continue
		var l := Kin.length(d)
		if l >= SPREAD_RADIUS_M:
			continue
		if l <= 0.0001:  # stacked exactly: the higher id steps aside, along +x or -x
			push += Vector2(1.0 if a.ids[i] > a.ids[j] else -1.0, 0.0)
			continue
		push += d / l * (1.0 - l / SPREAD_RADIUS_M)
	return push


static func _unit(v: Vector2) -> Vector2:
	var l := Kin.length(v)
	return v / l if l > 0.0001 else Vector2.ZERO


static func resolve(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] != State.ACTIVE or w.player_dead() or Engines.frozen(w, i):
		return
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var pr := w.player.radius_m
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			var reach := t.radius_m + pr + CONTACT_SLOP_M
			if a.fire_cd[i] == 0 and Kin.length(p - a.pos(i)) <= reach:
				a.fire_cd[i] = 1
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.WARDEN:
			if a.state_t[i] == 0:
				var disc := slam_disc(w, i)
				if AttackShapes.disc_touches(disc[0], disc[1], p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_AREA)
		ActorStore.Kind.NEEDLE:
			if a.fire_cd[i] < t.burst_count and a.state_t[i] % t.burst_gap_ticks == 0:
				var k := a.fire_cd[i]
				a.fire_cd[i] += 1
				var ang := burst_angle(t, a.lock_a[i], k)
				_fire(w, i, ang, t.bolt_speed, t.bolt_radius_m, t.bolt_life_ticks, t.damage)
		ActorStore.Kind.ARC_CASTER:
			if a.state_t[i] != 0:
				return
			match a.pick[i]:
				Spell.BOLT:
					_fire(
						w,
						i,
						a.lock_a[i],
						t.bolt_speed,
						t.bolt_radius_m,
						t.bolt_life_ticks,
						t.damage
					)
				Spell.SPREAD:
					for k in t.spread_count:
						var ang := fan_angle(a.lock_a[i], k, t.spread_count, t.spread_angle)
						_fire(
							w,
							i,
							ang,
							t.spread_speed,
							t.spread_radius_m,
							t.spread_life_ticks,
							t.damage
						)
				Spell.RUNE:
					var d := rune_disc(w, i)
					if AttackShapes.disc_touches(d[0], d[1], p, pr):
						_hit_player(w, i, t.damage, SimEvent.TAG_AREA, d[0])
		ActorStore.Kind.BOMB_DRONE:
			if a.state_t[i] == 0:
				var d := bomb_disc(w, i)
				if AttackShapes.disc_touches(d[0], d[1], p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_AREA, d[0])
		_:
			if a.state_t[i] == 0:
				_resolve_horde(w, i, t, p, pr)


## The horde kinds' hits (v0.4.0 EN), on their active tick.
static func _resolve_horde(w: World, i: int, t: EnemyTable, p: Vector2, pr: float) -> void:
	match w.actors.kinds[i]:
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var d := swipe_disc(w, i)
			if AttackShapes.disc_touches(d[0], d[1], p, pr):
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.SHIELD_BEARER:
			if Collide.circle_vs_obb(p, pr, bash_lane(w, i)) != Vector2.ZERO:
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.SNIPER:
			if Collide.circle_vs_obb(p, pr, snipe_lane(w, i)) != Vector2.ZERO:
				_hit_player(w, i, t.damage, SimEvent.TAG_PROJECTILE)
		ActorStore.Kind.MINE_LAYER:
			Mines.drop(w, i)


static func _fire(
	w: World, i: int, angle: int, speed: float, r: float, life: int, damage: int
) -> void:
	var a := w.actors
	var dir := Kin.dir(angle)
	var muzzle := Vector2(a.lock_x[i], a.lock_y[i]) + dir * (a.radius[i] + r + 0.05)
	w.queue_projectile(
		a.ids[i],
		ActorStore.TEAM_ENEMY,
		muzzle,
		dir * speed,
		damage,
		r,
		life,
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


## The rest of a charge in progress (v0.3.5 AI): from where the body is now along its (steered) heading, to its
## front at the end of the run. The view keeps drawing it, so a charge that bends shows where it is going.
static func running_lane(w: World, i: int) -> Obb:
	var a := w.actors
	return AttackShapes.lane(a.pos(i), a.lock_a[i], a.lock_len[i] + a.radius[i], a.radius[i])


## [center, radius] of a Warden's slam.
static func slam_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).slam_radius_m]


## Shot k of `count` fanned `step` apart around `aim`: centred, k = 0 in the middle when count is odd.
static func fan_angle(aim: int, k: int, count: int, step: int) -> int:
	return (aim + (2 * k - (count - 1)) * step / 2) & 4095


## The angle of shot k of a Needle's burst (v0.3.5 AI): the first down the middle, then one to each side.
static func burst_angle(t: EnemyTable, aim: int, k: int) -> int:
	var off := (k + 1) / 2 * (1 if k % 2 == 1 else -1)
	return (aim + off * t.burst_spread) & 4095


## The lines a Needle's burst flies down (one per shot), as wide as its bolts, each cut short by walls.
static func burst_lines(w: World, i: int) -> Array[Obb]:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var out: Array[Obb] = []
	var seen := PackedInt32Array()
	for k in t.burst_count:
		var ang := burst_angle(t, a.lock_a[i], k)
		if seen.has(ang):
			continue
		seen.append(ang)
		out.append(_shot_lane(w, i, ang, t.bolt_speed * t.bolt_life_ticks, t.bolt_radius_m))
	return out


## The Arc Caster's bolt line, or its spread's lines (v0.3.5 AI), cut short by walls.
static func bolt_lanes(w: World, i: int) -> Array[Obb]:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var out: Array[Obb] = []
	if a.pick[i] == Spell.SPREAD:
		for k in t.spread_count:
			var ang := fan_angle(a.lock_a[i], k, t.spread_count, t.spread_angle)
			out.append(
				_shot_lane(w, i, ang, t.spread_speed * t.spread_life_ticks, t.spread_radius_m)
			)
	else:
		out.append(_shot_lane(w, i, a.lock_a[i], t.bolt_speed * t.bolt_life_ticks, t.bolt_radius_m))
	return out


static func _shot_lane(w: World, i: int, angle: int, length: float, r: float) -> Obb:
	var a := w.actors
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(angle) * a.radius[i]
	return AttackShapes.lane(start, angle, maxf(_clear_run(w, start, angle, length, r), 0.01), r)


## [center, radius] of the Arc Caster's rune (v0.3.5 AI): where the player stood when it was cast.
static func rune_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).rune_radius_m]


## [center, radius] of the Bomb Drone's bomb (v0.3.5 AI): where the player stood when it was lobbed.
static func bomb_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).slam_radius_m]


## [center, radius] of a Splitter's (or Splitling's) swipe (v0.4.0 EN): reach_m ahead of it when it wound up.
static func swipe_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).slam_radius_m]


## A Shield Bearer's bash (v0.4.0 EN): a lane from its centre along its locked facing, reach_m past its body.
static func bash_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]), a.lock_a[i], a.radius[i] + t.reach_m, t.lane_half_m
	)


## A Sniper's line (v0.4.0 EN): reach_m from its muzzle along its aim, lane_half_m wide, cut short by walls.
static func snipe_lane(w: World, i: int) -> Obb:
	var t := w.enemy_table(w.actors.kinds[i])
	return _shot_lane(w, i, w.actors.lock_a[i], t.reach_m, t.lane_half_m)


## What the view draws for actor i: {} or {"shape": &"lane"|&"lanes"|&"disc", ..., "progress": 0..1000}. The new
## kinds (v0.3.5 AI) add "style": &"bolt", &"rune" or &"bomb", and a bomb its "from" (the drone).
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	if BossAi.is_boss_kind(a.kinds[i]):
		return BossAi.telegraph(w, i)  # Bosses (v0.3.0 C).
	if not is_enemy_kind(a.kinds[i]):
		return {}
	if a.state[i] == State.ACTIVE and _charges(a.kinds[i]) and a.lock_len[i] > 0.0:
		return {"shape": &"lane", "obb": running_lane(w, i), "progress": 1000}
	if a.kinds[i] == ActorStore.Kind.MINE_LAYER:
		return Mines.telegraph(w, a.ids[i])  # v0.4.0 EN: its armed mines; the drop itself hurts nobody
	if a.state[i] != State.WINDUP:
		return {}
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, a.windup[i]), 0, 1000)
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			return {"shape": &"lane", "obb": charge_lane(w, i), "progress": progress}
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var s := swipe_disc(w, i)
			return {"shape": &"disc", "center": s[0], "radius": s[1], "progress": progress}
		ActorStore.Kind.SHIELD_BEARER:
			return {
				"shape": &"lane", "obb": bash_lane(w, i), "progress": progress, "style": &"bash"
			}
		ActorStore.Kind.SNIPER:
			return {
				"shape": &"lane", "obb": snipe_lane(w, i), "progress": progress, "style": &"snipe"
			}
		ActorStore.Kind.WARDEN:
			var d := slam_disc(w, i)
			return {"shape": &"disc", "center": d[0], "radius": d[1], "progress": progress}
		ActorStore.Kind.NEEDLE:
			return {"shape": &"lanes", "obbs": burst_lines(w, i), "progress": progress}
		ActorStore.Kind.ARC_CASTER:
			if a.pick[i] == Spell.RUNE:
				var r := rune_disc(w, i)
				return {
					"shape": &"disc",
					"center": r[0],
					"radius": r[1],
					"progress": progress,
					"style": &"rune"
				}
			var lanes := bolt_lanes(w, i)
			if lanes.size() == 1:
				return {"shape": &"lane", "obb": lanes[0], "progress": progress, "style": &"bolt"}
			return {"shape": &"lanes", "obbs": lanes, "progress": progress, "style": &"bolt"}
		ActorStore.Kind.BOMB_DRONE:
			var b := bomb_disc(w, i)
			return {
				"shape": &"disc",
				"center": b[0],
				"radius": b[1],
				"progress": progress,
				"style": &"bomb",
				"from": a.pos(i)
			}
	return {}


static func _start_windup(w: World, i: int, aim: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	_enter(a, i, State.WINDUP)
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]
	a.lock_a[i] = aim
	a.lock_len[i] = 0.0
	a.pick[i] = 0
	# v0.3.5 AI (F4): the windup's length is drawn per attack, never under the data's telegraph.
	a.windup[i] = t.windup_ticks
	if t.windup_max_ticks > t.windup_ticks:
		a.windup[i] = w.rng_enemy.range_int(t.windup_ticks, t.windup_max_ticks)
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			a.lock_len[i] = _clear_run(w, a.pos(i), aim, t.charge_distance_m, t.radius_m)
		ActorStore.Kind.NEEDLE, ActorStore.Kind.SNIPER:
			_aim(w, i)
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var c := a.pos(i) + Kin.dir(aim) * t.reach_m
			a.lock_x[i] = c.x
			a.lock_y[i] = c.y
		ActorStore.Kind.SHIELD_BEARER:
			a.lock_a[i] = a.facing[i]  # it bashes the way its shield faces
		ActorStore.Kind.ARC_CASTER:
			a.pick[i] = maxi(0, w.rng_enemy.pick_weighted(t.spell_weights))
			if a.pick[i] == Spell.RUNE:
				a.windup[i] = t.rune_windup_ticks
				a.lock_x[i] = w.player_pos().x
				a.lock_y[i] = w.player_pos().y
			else:
				_aim(w, i)
		ActorStore.Kind.BOMB_DRONE:
			a.lock_x[i] = w.player_pos().x
			a.lock_y[i] = w.player_pos().y


## Points actor i's shot at where the player will be when it arrives (v0.3.5 AI): the player's position plus its
## velocity for the shot's flight time, capped at lead_max_ticks; or where a dash in progress ends.
static func _aim(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var speed := t.spread_speed if a.pick[i] == Spell.SPREAD else t.bolt_speed
	a.lock_a[i] = lead_angle(w, a.pos(i), speed, t.lead_max_ticks)
	a.facing[i] = a.lock_a[i]


## The angle from `from` to the player led by its velocity for a shot at `speed` (metres per tick). A dashing
## player is aimed at where the dash ends (the same read as the bosses', BossChallenge.dash_landing).
static func lead_angle(w: World, from: Vector2, speed: float, max_ticks: int) -> int:
	if w.is_dashing() and not w.player_dead():
		return Kin.angle_of(BossChallenge.dash_landing(w) - from)
	var p := w.player_pos()
	var ticks := 0
	if speed > 0.0:
		ticks = mini(int(Kin.length(p - from) / speed), max_ticks)
	return Kin.angle_of(p + w.vel * ticks - from)


## How far a circle of radius r can travel from `from` along `angle` (up to `length`) before a wall.
static func _clear_run(w: World, from: Vector2, angle: int, length: float, r: float) -> float:
	var to := from + Kin.dir(angle) * length
	var best := 1.0
	for wall in w.walls:
		var hit := Collide.sweep_vs_obb(from, to, r, wall)
		if hit >= 0.0 and hit < best:
			best = hit
	return length * best


static func _hit_player(w: World, i: int, amount: int, tags: int, from := Vector2.INF) -> void:
	var a := w.actors
	var at := a.pos(i) if from == Vector2.INF else from
	Damage.hit(w, 0, amount, a.ids[i], a.ids[i], w.take_root(), tags, at, w.player_pos())


static func _enter(a: ActorStore, i: int, s: int) -> void:
	a.state[i] = s
	a.state_t[i] = 0
