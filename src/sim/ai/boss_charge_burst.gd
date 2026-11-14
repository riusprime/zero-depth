class_name BossChargeBurst
extends RefCounted
## A charge that bursts where it ends: an option of the `charge` move any boss may take (BossAttackTable
## burst_radius_m > 0). The run itself is BossAi's (the locked lane, the body's contact hit). On the tick the run
## stops (its length spent, or cut short by a wall when it locked) a burst is armed on the body's spot; burst_ticks
## later it hits a hero within burst_radius_m of that spot for the attack's damage, once, whatever the boss does by
## then. A dash's i-frames avoid it, as any hit. The pending bursts live in BossStore (cb_*), run in tick phase 6
## (BossSignatures.advance) and go with their boss or when the hero is dead. Pure: no stream is drawn.
## The view reads the lane and the end circle through the wind-up (telegraph: the end follows the aim until the
## lane locks) and the armed bursts after it (rows).

## STATUS_APPLY, source the boss: a burst was armed (pos = its centre, amount = ticks until it bursts) and it burst
## (pos = its centre, target the hero, amount = the HP it cost, 0 when it missed).
const ARMED := &"charge_burst_armed"
const BURST := &"charge_burst"
const S := EnemyAi.State


## True when attack `atk` is a charge that bursts.
static func bursts(atk: BossAttackTable) -> bool:
	return atk != null and atk.move == BossAttackTable.Move.CHARGE and atk.burst_radius_m > 0.0


## Where boss i's charge ends: the body's centre at the end of its locked lane (during the wind-up the lane follows
## the aim, so this does too; during the run it stays put).
static func end_of(w: World, i: int) -> Vector2:
	var a := w.actors
	if a.state[i] == S.ACTIVE:
		return a.pos(i) + Kin.dir(a.lock_a[i]) * maxf(a.lock_len[i], 0.0)
	return Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(a.lock_a[i]) * maxf(a.lock_len[i], 0.0)


## BossAi.telegraph for a charge: its lane, and for one that bursts "burst" {center, radius}.
static func telegraph(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var out := {"shape": &"lane", "obb": EnemyAi.charge_lane(w, i)}
	if bursts(atk):
		out["burst"] = {"center": end_of(w, i), "radius": atk.burst_radius_m}
	return out


## Tick phase 6: a charge whose run stopped this tick arms its burst; a burst whose time has come hits.
static func advance(w: World) -> void:
	var bs := w.bosses
	var a := w.actors
	if w.player_dead():
		for k in range(bs.cb_boss.size() - 1, -1, -1):
			bs.remove_burst(k)
		return
	for b in bs.size():
		var i := a.index_of(bs.ids[b])
		if i < 0 or a.state[i] != S.ACTIVE or a.lock_len[i] > 0.0 or bs.attack[b] < 0:
			continue
		var atk := BossAi.attack_of(w, i)
		if not bursts(atk) or bs.cb_boss.has(bs.ids[b]):
			continue
		arm(w, i, bs.attack[b], a.pos(i))
	for k in range(bs.cb_boss.size() - 1, -1, -1):
		if bs.cb_at[k] <= w.tick:
			_burst(w, k)


## Arms a burst of boss i's attack `attack` (an index) at `at`.
static func arm(w: World, i: int, attack: int, at: Vector2) -> void:
	var bs := w.bosses
	var atk := BossAi.table_of(w, i).attacks[attack]
	var id := w.actors.ids[i]
	bs.cb_boss.append(id)
	bs.cb_attack.append(attack)
	bs.cb_at.append(w.tick + atk.burst_ticks)
	bs.cb_x.append(at.x)
	bs.cb_y.append(at.y)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = ARMED
	e.amount = atk.burst_ticks


static func _burst(w: World, k: int) -> void:
	var bs := w.bosses
	var id := bs.cb_boss[k]
	var attack := bs.cb_attack[k]
	var c := Vector2(bs.cb_x[k], bs.cb_y[k])
	bs.remove_burst(k)
	var i := w.actors.index_of(id)
	if i < 0:
		return
	var atk := BossAi.table_of(w, i).attacks[attack]
	var p := w.player_pos()
	var cost := 0
	if AttackShapes.disc_touches(c, atk.burst_radius_m, p, w.player.radius_m):
		var dmg := BossAi.powered(w, i, atk.damage)
		cost = Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, c, p)
		if w.player_dead() and w.killer_attack < 0:
			w.killer_attack = attack
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], c)
	e.effect_id = BURST
	e.amount = cost


## BossSignatures.on_boss_gone: its pending bursts go with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	for k in range(bs.cb_boss.size() - 1, -1, -1):
		if bs.cb_boss[k] == boss_id:
			bs.remove_burst(k)


## WorldReader.boss_charge_bursts: the bursts armed, oldest first.
static func rows(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.cb_boss.size():
		var i := w.actors.index_of(bs.cb_boss[k])
		if i < 0:
			continue
		var atk := BossAi.table_of(w, i).attacks[bs.cb_attack[k]]
		(
			out
			. append(
				{
					"boss": i,
					"centre": Vector2(bs.cb_x[k], bs.cb_y[k]),
					"radius": atk.burst_radius_m,
					"left": bs.cb_at[k] - w.tick,
					"progress":
					clampi(
						1000 - (bs.cb_at[k] - w.tick) * 1000 / maxi(1, atk.burst_ticks), 0, 1000
					),
				}
			)
		)
	return out
