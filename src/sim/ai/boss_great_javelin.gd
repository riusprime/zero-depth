class_name BossGreatJavelin
extends RefCounted
## v0.11.0 F9 (owner: "The Warlord throws a javelin into the arena. The javelin remains embedded in the ground and
## generates an earthquake-like effect, similar to the existing rock-based attack. It vibrates for a period before the
## boss recalls it. On its return path toward the boss, the javelin can damage the player."): a `great_javelin` attack.
## - The throw (BossAi, tick phase 6, as the windup ends): its line and landing follow the hero until the attack's lock,
##   held for the lock; then one large javelin (its own flight, so no shot-clearing card or cap can take it) flies at
##   the attack's speed to the point (or the first wall); touching the hero along the way, it hurts once (cause: the
##   attack's own). It passes through bodies.
## - It embeds great_embed_ticks: every great_pulse_ticks a ring of great_ring_m round it pulses (the Gatekeeper's quake
##   rule: warned great_warn_ticks, damage over time from the boss, great_pulse_permille of the hero's max HP, hero
##
##     only).
##   It is not a wall, and enemies path over it.
## - The recall: great_recall_warn_ticks of a telegraph line from it to where the boss stood when the line appeared,
##   then it flies back along that line (it hurts once, the attack's late cause), past the boss's edge (or the line's
##   end) it is gone; it never crumbles.
## - At most one is out per boss (may_use); while it is out the boss attacks with its other moves. The boss's death
##   clears it (on_boss_gone). Pure: no stream is drawn here.

## Its phases (BossStore.gj_phase).
const THROW := 0
const EMBEDDED := 1
const RECALL_WARN := 2
const RETURN := 3
## The DAMAGE effects (ReadableCause and the recap's cause).
const THROW_EFFECT := &"great_javelin_throw"
const RETURN_EFFECT := &"great_javelin_back"
const QUAKE_EFFECT := &"great_javelin_quake"
## Its muzzle's slack past the boss's edge, its shortest throw, and the landing mark's radius (m).
const MUZZLE_M := 0.05
const MIN_THROW_M := 1.0
const LANDING_M := 0.9
## A quake view's "half": where the ring starts growing from (m; a quake pillar's own half side at this scale).
const RING_INNER_M := 0.4


## BossAi._choose: boss i may start attack atk now: the Twin rule, and at most one great javelin out.
static func may_use(w: World, i: int, atk: BossAttackTable) -> bool:
	if atk.move == BossAttackTable.Move.GREAT_JAVELIN and is_out(w, w.actors.ids[i]):
		return false
	return BossTwin.may_use(w, i, atk)


## True while boss `boss_id` has a great javelin out.
static func is_out(w: World, boss_id: int) -> bool:
	return w.bosses.gj_boss.has(boss_id)


## [muzzle, the point it embeds, length m] of the throw boss i has locked: to its target (at most the range), stopped
## by the first wall, the same for the telegraph and the throw (EI-07).
static func path_of(w: World, i: int, atk: BossAttackTable) -> Array:
	var a := w.actors
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	var dir := Kin.dir(a.lock_a[i])
	var off := a.radius[i] + atk.radius_m + MUZZLE_M
	var muzzle := from + dir * off
	var want := Kin.length(w.bosses.pt(BossAi.entry_of(w, i), 0) - from) - off
	var run := EnemyAi.clear_run(
		w, muzzle, a.lock_a[i], clampf(want, MIN_THROW_M, atk.length_m), atk.radius_m
	)
	return [muzzle, muzzle + dir * run, run]


## The windup's line and landing mark (a `marks` telegraph: dull while they follow the hero, bright once locked), {}
## once
## thrown. BossDodge.pattern_telegraph.
static func telegraph(
	w: World, i: int, atk: BossAttackTable, windup: bool, progress: int
) -> Dictionary:
	if not windup:
		return {}
	var path := path_of(w, i, atk)
	var locked := w.actors.state_t[i] >= atk.windup_ticks - atk.lock_ticks
	var lane := AttackShapes.lane(path[0], w.actors.lock_a[i], path[2], atk.radius_m)
	var items: Array[Dictionary] = [
		{"shape": &"lanes", "obbs": [lane], "locked": locked, "progress": progress},
		{
			"shape": &"disc",
			"center": path[1],
			"radius": LANDING_M,
			"locked": locked,
			"progress": progress
		},
	]
	return {
		"shape": &"marks",
		"items": items,
		"progress": progress,
		"move": atk.move,
		"tracked": true,
		"locked": locked
	}


## BossDodge.resolve_pattern, the attack's first active tick: it leaves the boss's hand (unless one is already out).
static func throw(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var a := w.actors
	if st != 0 or is_out(w, a.ids[i]):
		return
	var path := path_of(w, i, atk)
	var bs := w.bosses
	bs.gj_boss.append(a.ids[i])
	bs.gj_attack.append(bs.attack[b])
	bs.gj_phase.append(THROW)
	bs.gj_from.append(w.tick)
	bs.gj_life.append(int(float(path[2]) / maxf(atk.speed, 0.0001)) + 1)
	bs.gj_hit.append(0)
	bs.gj_a.append(a.lock_a[i])
	bs.gj_x.append(float(path[0].x))
	bs.gj_y.append(float(path[0].y))
	bs.gj_tox.append(float(path[1].x))
	bs.gj_toy.append(float(path[1].y))


## Tick phase 6 (BossSignatures.advance): each great javelin flies, quakes or waits; its boss gone, it is gone.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.gj_boss.is_empty():
		return
	for k in range(bs.gj_boss.size() - 1, -1, -1):
		var bi := w.actors.index_of(bs.gj_boss[k])
		if bi < 0 or w.actors.dead[bi] == 1:
			bs.remove_great_javelin(k)
			continue
		var atk := BossAi.table_of(w, bi).attacks[bs.gj_attack[k]]
		match bs.gj_phase[k]:
			THROW:
				_fly_out(w, bi, k, atk)
			EMBEDDED:
				_quake(w, bi, k, atk)
			RECALL_WARN:
				if w.tick - bs.gj_from[k] >= atk.great_recall_warn_ticks:
					_start_return(w, k, atk)
			RETURN:
				_fly_back(w, bi, k, atk)


## Where great javelin k is on tick `t` of its flight (along its line, from where it flew to where it ends).
static func flight_at(bs: BossStore, k: int, t: int) -> Vector2:
	var f := clampf(float(t) / maxf(1.0, float(bs.gj_life[k])), 0.0, 1.0)
	return Vector2(bs.gj_x[k], bs.gj_y[k]).lerp(Vector2(bs.gj_tox[k], bs.gj_toy[k]), f)


static func _fly_out(w: World, bi: int, k: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	var t := w.tick - bs.gj_from[k]
	if t <= 0:
		return  # spawned this tick (BossAi.resolve runs just before this)
	_strike(
		w, bi, k, atk, flight_at(bs, k, t - 1), flight_at(bs, k, t), THROW_EFFECT, bs.gj_attack[k]
	)
	if t >= bs.gj_life[k]:
		bs.gj_x[k] = bs.gj_tox[k]
		bs.gj_y[k] = bs.gj_toy[k]
		bs.gj_phase[k] = EMBEDDED
		bs.gj_from[k] = w.tick
		bs.gj_hit[k] = 0


## The pulses (BossQuake's rule), then the recall line when its embedded time is up.
static func _quake(w: World, bi: int, k: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	var age := w.tick - bs.gj_from[k]
	if age > 0 and age % atk.great_pulse_ticks == 0:
		_pulse(w, bi, k, atk)
	if age < atk.great_embed_ticks:
		return
	var at := Vector2(bs.gj_x[k], bs.gj_y[k])
	var to_boss := w.actors.pos(bi) - at
	var dist := Kin.length(to_boss)
	var back := maxf(dist - w.actors.radius[bi], 0.0)
	var end := at + (to_boss / maxf(dist, 0.0001)) * back
	bs.gj_tox[k] = end.x
	bs.gj_toy[k] = end.y
	bs.gj_phase[k] = RECALL_WARN
	bs.gj_from[k] = w.tick


static func _pulse(w: World, bi: int, k: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	if w.player_dead():
		return
	var at := Vector2(bs.gj_x[k], bs.gj_y[k])
	if not AttackShapes.disc_touches(at, atk.great_ring_m, w.player_pos(), w.player.radius_m):
		return
	var dmg := maxi(1, w.actors.max_hp[0] * atk.great_pulse_permille / 1000)
	var id := w.actors.ids[bi]
	Damage.tick_dot(w, 0, dmg, id, id, QUAKE_EFFECT)
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = bs.gj_attack[k]


static func _start_return(w: World, k: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	var run := Kin.length(Vector2(bs.gj_tox[k], bs.gj_toy[k]) - Vector2(bs.gj_x[k], bs.gj_y[k]))
	bs.gj_phase[k] = RETURN
	bs.gj_from[k] = w.tick
	bs.gj_life[k] = int(run / maxf(atk.great_recall_speed, 0.0001)) + 1
	bs.gj_hit[k] = 0


static func _fly_back(w: World, bi: int, k: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	var t := w.tick - bs.gj_from[k]
	var at := flight_at(bs, k, t)
	_strike(
		w,
		bi,
		k,
		atk,
		flight_at(bs, k, t - 1),
		at,
		RETURN_EFFECT,
		BossSignatures.LATE_CAUSE + bs.gj_attack[k]
	)
	if t >= bs.gj_life[k] or Kin.length(at - w.actors.pos(bi)) <= w.actors.radius[bi]:
		bs.remove_great_javelin(k)


## Touching the hero between `a` and `b` this tick, the flight hurts once (an i-framed hero is not touched).
static func _strike(
	w: World,
	bi: int,
	k: int,
	atk: BossAttackTable,
	a: Vector2,
	b: Vector2,
	effect: StringName,
	cause: int
) -> void:
	var bs := w.bosses
	if bs.gj_hit[k] == 1 or w.player_dead() or w.actors.invuln[0] > 0:
		return
	if (
		Collide.sweep_vs_circle(a, b, atk.radius_m, w.player_pos(), w.player.radius_m)
		== Collide.NO_HIT
	):
		return
	bs.gj_hit[k] = 1
	var id := w.actors.ids[bi]
	var dmg := BossAi.orb_damage(w, bi, atk)
	Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_PROJECTILE, a, w.player_pos(), effect)
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = cause


## World._remove_dead (BossSignatures.on_boss_gone): its javelin goes.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var k := w.bosses.gj_boss.find(boss_id)
	if k >= 0:
		w.bosses.remove_great_javelin(k)


# --- the views (EI-07) --------------------------------------------------------------------------------------------


## The great javelin of boss i for its view, or {}: {"phase", "from_tick" (its phase's), "at" (where it is, or flies
## from), "to" (where its flight ends), "life" (the flight's ticks), "angle" (1/4096 turns, the way it points), "ring",
## "shake" (0..1000, how hard it vibrates: resting, up as a pulse nears, full on the recall), "struck" (true on a
## pulse), "pulse" (the pulse's number)}.
static func view(w: World, i: int) -> Dictionary:
	var bs := w.bosses
	var k := bs.gj_boss.find(w.actors.ids[i])
	if k < 0:
		return {}
	var atk := BossAi.table_of(w, i).attacks[bs.gj_attack[k]]
	var phase := bs.gj_phase[k]
	var age := w.tick - bs.gj_from[k]
	var at := Vector2(bs.gj_x[k], bs.gj_y[k])
	var to := Vector2(bs.gj_tox[k], bs.gj_toy[k])
	var warn := _warn(atk, age) if phase == EMBEDDED else -1
	var shake := 0
	if phase == EMBEDDED:
		shake = 300 + 700 * maxi(warn, 0) / 1000
	elif phase == RECALL_WARN:
		shake = 1000
	return {
		"phase": phase,
		"from_tick": bs.gj_from[k],
		"at": at,
		"to": to,
		"life": bs.gj_life[k],
		"angle": bs.gj_a[k] if phase != RETURN else Kin.angle_of(to - at),
		"ring": atk.great_ring_m,
		"shake": shake,
		"pulse": age / maxi(1, atk.great_pulse_ticks),
		"struck": phase == EMBEDDED and age > 0 and age % atk.great_pulse_ticks == 0,
	}


## Ring growth 0..1000 over its warning, -1 outside it (the quake's rule, BossQuake.ring_state).
static func _warn(atk: BossAttackTable, age: int) -> int:
	var into := posmod(age, atk.great_pulse_ticks)
	var left := atk.great_pulse_ticks - into
	if age > 0 and into == 0:
		return 1000
	if left <= atk.great_warn_ticks:
		return clampi((atk.great_warn_ticks - left) * 1000 / maxi(1, atk.great_warn_ticks), 0, 1000)
	return -1


## The rings of the embedded great javelins, in BossQuake.ring_state's shape (StoneSpikeViews draws them as its quake
## pillars', without the spikes), "javelin" true. Each stays through its recall line, so its last pulse's flash
## finishes.
static func quake_rings(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.gj_boss.size():
		var phase := bs.gj_phase[k]
		var bi := w.actors.index_of(bs.gj_boss[k])
		if bi < 0 or phase == THROW or phase == RETURN:
			continue
		var atk := BossAi.table_of(w, bi).attacks[bs.gj_attack[k]]
		var rose := bs.gj_from[k] if phase == EMBEDDED else bs.gj_from[k] - atk.great_embed_ticks
		(
			out
			. append(
				{
					"center": Vector2(bs.gj_x[k], bs.gj_y[k]),
					"half": RING_INNER_M,
					"ring": atk.great_ring_m,
					"rose": rose,
					"pulse_ticks": atk.great_pulse_ticks,
					"warn_ticks": atk.great_warn_ticks,
					"javelin": true,
				}
			)
		)
	return out


## The recall line of boss i's great javelin, a &"lane" telegraph from it to the boss (filling toward the boss), or {}.
static func recall_line(w: World, i: int) -> Dictionary:
	var bs := w.bosses
	var k := bs.gj_boss.find(w.actors.ids[i])
	if k < 0 or bs.gj_phase[k] != RECALL_WARN:
		return {}
	var atk := BossAi.table_of(w, i).attacks[bs.gj_attack[k]]
	var at := Vector2(bs.gj_x[k], bs.gj_y[k])
	var to := Vector2(bs.gj_tox[k], bs.gj_toy[k]) - at
	return {
		"shape": &"lane",
		"obb": AttackShapes.lane(at, Kin.angle_of(to), Kin.length(to), atk.radius_m),
		"progress":
		clampi((w.tick - bs.gj_from[k]) * 1000 / maxi(1, atk.great_recall_warn_ticks), 0, 1000),
		"move": BossAttackTable.Move.GREAT_JAVELIN,
	}
