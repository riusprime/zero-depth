class_name BossPickups
extends RefCounted
## Floor pickups a boss places for the hero: one disc each, BossStore.pk_* {id, boss, kind, amount, placed, ends,
## centre, radius}, oldest first.
## - The hero takes one when its circle touches the disc (checked every tick, oldest first, so two under its feet are
##   taken in the order they were placed); its effect lands once and the pickup goes.
## - One with a lifetime goes when its time is up; all of a boss's go with the boss, with the hero's death and when
##   the hero leaves the sealed arena (BossSlow.fight_over).
## - The cap (BossPickupTable.max_count, a boss): one more removes that boss's oldest.
## - Each tells the event log: BOSS_PICKUP_SPAWN, BOSS_PICKUP_TAKEN, BOSS_PICKUP_END (SimEvent). The events are for
##   the views and the tests; they never change state.
## It touches the hero only: never enemies, shots, walls or the flow field. Pure: no stream is drawn.

## BOSS_PICKUP_END's amount: its time ran out, the cap removed it, or its fight ended.
const END_EXPIRED := 0
const END_CAP := 1
const END_CLEARED := 2


## How many pickups boss `boss_id` has down.
static func count_of(w: World, boss_id: int) -> int:
	return w.bosses.pk_boss.count(boss_id)


## Boss `boss_id` places one pickup of table t at c. Its id (BOSS_PICKUP_SPAWN's target), or -1 without a table.
static func place(w: World, boss_id: int, t: BossPickupTable, c: Vector2) -> int:
	if t == null:
		return -1
	var bs := w.bosses
	while count_of(w, boss_id) >= maxi(1, t.max_count):
		_end(w, bs.pk_boss.find(boss_id), END_CAP)
	var id := bs.pk_next
	bs.pk_next += 1
	bs.pk_id.append(id)
	bs.pk_boss.append(boss_id)
	bs.pk_kind.append(t.kind)
	bs.pk_amount.append(t.amount)
	bs.pk_from.append(w.tick)
	bs.pk_until.append(w.tick + t.life_ticks if t.life_ticks > 0 else 0)
	bs.pk_x.append(c.x)
	bs.pk_y.append(c.y)
	bs.pk_r.append(t.radius_m)
	var e := w.emit_event(SimEvent.Kind.BOSS_PICKUP_SPAWN, boss_id, boss_id, id, c)
	e.amount = t.kind
	return id


## Tick phase 6 (BossSignatures.advance): the fight over, all go; else those past their time go and the hero takes
## the ones it touches.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.pk_x.is_empty():
		return
	if BossSlow.fight_over(w):
		_end_all(w, -1)
		return
	for k in range(bs.pk_x.size() - 1, -1, -1):
		if bs.pk_until[k] > 0 and bs.pk_until[k] <= w.tick:
			_end(w, k, END_EXPIRED)
	var p := w.player_pos()
	var k := 0
	while k < bs.pk_x.size():
		var c := Vector2(bs.pk_x[k], bs.pk_y[k])
		if Kin.length(c - p) <= bs.pk_r[k] + w.player.radius_m:
			_take(w, k, c)
		else:
			k += 1


## The hero takes pickup k: its effect, its event, and it goes.
static func _take(w: World, k: int, c: Vector2) -> void:
	var bs := w.bosses
	var applied := 0
	match bs.pk_kind[k]:
		BossPickupTable.Kind.RESTORE_ATTACK_SPEED:
			applied = BossSlow.give_back(w, bs.pk_amount[k])
	var e := w.emit_event(
		SimEvent.Kind.BOSS_PICKUP_TAKEN, bs.pk_boss[k], w.actors.ids[0], bs.pk_id[k], c
	)
	e.amount = bs.pk_amount[k]
	e.amount_applied = applied
	bs.remove_pickup(k)


## Pickup k goes untaken (`why`: END_*).
static func _end(w: World, k: int, why: int) -> void:
	var bs := w.bosses
	var c := Vector2(bs.pk_x[k], bs.pk_y[k])
	var e := w.emit_event(
		SimEvent.Kind.BOSS_PICKUP_END, bs.pk_boss[k], bs.pk_boss[k], bs.pk_id[k], c
	)
	e.amount = why
	bs.remove_pickup(k)


## Every pickup of boss `boss_id` goes (-1: every boss's).
static func _end_all(w: World, boss_id: int) -> void:
	var bs := w.bosses
	for k in range(bs.pk_x.size() - 1, -1, -1):
		if boss_id < 0 or bs.pk_boss[k] == boss_id:
			_end(w, k, END_CLEARED)


## BossSignatures.on_boss_gone: its pickups go at once.
static func on_boss_gone(w: World, boss_id: int) -> void:
	_end_all(w, boss_id)


## The pickups for the view: see WorldReader.boss_pickups.
static func rows(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.pk_x.size():
		(
			out
			. append(
				{
					"id": bs.pk_id[k],
					"kind": bs.pk_kind[k],
					"amount": bs.pk_amount[k],
					"centre": Vector2(bs.pk_x[k], bs.pk_y[k]),
					"radius": bs.pk_r[k],
					"age": w.tick - bs.pk_from[k],
					"left": bs.pk_until[k] - w.tick if bs.pk_until[k] > 0 else -1,
				}
			)
		)
	return out
