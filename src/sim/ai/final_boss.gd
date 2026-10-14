class_name FinalBoss
extends RefCounted
## v0.8.0 FB1 (owner O16-O17: "a final boss … this would have 3 phases, with different combat in each one";
## FINAL_BOSS.md F1, F3; SIM_CONTRACTS "The final boss"): one fight, three bodies (World.final_fight, a FinalFight).
## - Each body is a boss (its own actor kind, table and model; BossAi runs it). Its segment of the boss bar is its
##   HP: no hit takes a body before the last below 1 HP (clamp_damage, through BossGates.clamp_damage; the dev panel's
##   Kill boss too), so a body never dies before its time.
## - When a body before the last is down to 1 HP it shatters (tick phase 9, advance): it stops, stands still and
##   can't be hurt (state SHATTER, invulnerable) for the fight's shatter_ticks (1.5 s as shipped), and every hostile
##   shot is cleared the tick it begins and every tick it lasts (and any queued that tick). Then it leaves as a
##   defeated boss (BOSS_DEFEATED: the Codex counts it) and the next body rises where it stood (World.spawn_boss: the
##   boss rise, invulnerable for the intro).
## - The last body's death wins the fight (`won`; WorldReader.outcome 1 in the final arena).
## - A save is taken at each body's start (RunSaver: the arena's entry, then each phase_tick), so a resumed fight
##   starts at the current body's beginning.
## While the fight runs (not won, the player alive) its clock counts run time (the arena has no spawner to count it).
## Pure: no stream is drawn.

## BossAi state of a shattering body: after BossAi.GATE (6) and BossSignatures' egg states (7-9), which the views
## also read off the state alone.
const SHATTER := 10
## STATUS_APPLY effect ids for the views and the sound: a body shatters (amount = the phase it ends), a body rises
## (amount = the phase it begins).
const EFFECT_SHATTER := &"final_shatter"
const EFFECT_RISE := &"final_rise"


## Starts the fight in `w` (setup, or between ticks): body `phase` (0 = the first) rises at `at`.
static func begin(
	w: World, tables: PackedInt32Array, shatter_ticks: int, at: Vector2, phase: int = 0
) -> void:
	w.final_fight = FinalFight.create(tables, shatter_ticks)
	_spawn(w, clampi(phase, 0, tables.size() - 1), at)


## The actor index of the body fighting now, or -1.
static func body_index(w: World) -> int:
	if w.final_fight == null or w.final_fight.body_id < 0:
		return -1
	return w.actors.index_of(w.final_fight.body_id)


## Actor i is the final fight's current body.
static func is_body(w: World, i: int) -> bool:
	return w.final_fight != null and w.actors.ids[i] == w.final_fight.body_id


## A body is shattering now.
static func shattering(w: World) -> bool:
	return w.final_fight != null and w.final_fight.shatter_t > 0


## Damage._apply (through BossGates.clamp_damage): a body before the last keeps 1 HP, whoever hits it.
static func clamp_damage(w: World, i: int, amount: int) -> int:
	var f := w.final_fight
	if f == null or f.last_phase() or w.actors.ids[i] != f.body_id:
		return amount
	return mini(amount, maxi(0, w.actors.hp[i] - 1))


## Tick phase 9, before the dead leave: the clock, the shatter, the next body, the win.
static func advance(w: World) -> void:
	var f := w.final_fight
	if f == null or f.won:
		return
	if not w.player_dead():
		w.run_ticks += 1  # the fight's time counts in the run's (no spawner counts it here)
	var i := body_index(w)
	if i < 0:
		return
	var a := w.actors
	if f.shatter_t > 0:
		f.shatter_t -= 1
		a.invuln[i] = maxi(a.invuln[i], 2)
		clear_shots(w)
		if f.shatter_t == 0:
			_next(w, i)
		return
	if a.dead[i] == 1:
		if f.last_phase():
			f.won = true
			f.won_tick = w.tick
		else:  # only a world's own write can take a body before its time: the next one rises at once
			_spawn(w, f.phase + 1, a.pos(i))
		return
	if not f.last_phase() and a.hp[i] <= 1:
		_shatter(w, i)


## A body before the last ran out of its segment: it shatters.
static func _shatter(w: World, i: int) -> void:
	var f := w.final_fight
	var a := w.actors
	var b := BossAi.entry_of(w, i)
	var bs := w.bosses
	bs.attack[b] = -1
	bs.stagger_t[b] = 0
	bs.meter[b] = 0
	bs.gate_t[b] = 0
	bs.exposed_t[b] = 0
	a.lock_len[i] = 0.0
	a.state[i] = SHATTER
	a.state_t[i] = 0
	a.invuln[i] = maxi(a.invuln[i], f.shatter_ticks + 2)
	f.shatter_t = f.shatter_ticks
	clear_shots(w)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = EFFECT_SHATTER
	e.amount = f.phase


## The shatter ran out: the body leaves (as a defeated boss) and the next one rises where it stood.
static func _next(w: World, i: int) -> void:
	var f := w.final_fight
	var at := w.actors.pos(i)
	w.actors.dead[i] = 1
	_spawn(w, f.phase + 1, at)


static func _spawn(w: World, phase: int, at: Vector2) -> void:
	var f := w.final_fight
	f.phase = phase
	f.phase_tick = w.tick
	f.shatter_t = 0
	f.body_id = w.spawn_boss(f.tables[phase], at)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, f.body_id, f.body_id, f.body_id, at)
	e.effect_id = EFFECT_RISE
	e.amount = phase


## Every hostile shot on the floor and queued this tick goes (the shatter's clean slate).
static func clear_shots(w: World) -> void:
	var p := w.projectiles
	var gone := PackedInt32Array()
	for k in p.size():
		if p.team[k] != ActorStore.TEAM_PLAYER:
			gone.append(k)
	if not gone.is_empty():
		p.remove_sorted(gone)
	w.drop_pending_hostile()


## The dev panel and the Playground (between ticks): the body of `phase` takes over now, where the current one stands
## (the current one leaves with no kill: ENEMY_DISSOLVED).
static func jump(w: World, phase: int) -> void:
	var f := w.final_fight
	if f == null or f.won:
		return
	var i := body_index(w)
	var at := w.actors.pos(i) if i >= 0 else Vector2.ZERO
	if i >= 0:
		var id := w.actors.ids[i]
		var e := w.emit_event(SimEvent.Kind.ENEMY_DISSOLVED, id, id, id, at)
		e.amount = w.actors.kinds[i]
		var b := w.bosses.index_of(id)
		if b >= 0:
			w.bosses.remove(b)
			BossSignatures.on_boss_gone(w, id)
		w.actors.remove_sorted(PackedInt32Array([i]))
		if w.boss_id == id:
			w.boss_id = -1
	clear_shots(w)
	_spawn(w, clampi(phase, 0, f.tables.size() - 1), at)


## 0..1000: how far the shatter has run (0 when none).
static func shatter_permille(w: World) -> int:
	var f := w.final_fight
	if f == null or f.shatter_t <= 0:
		return 0
	return clampi((f.shatter_ticks - f.shatter_t) * 1000 / maxi(1, f.shatter_ticks), 0, 1000)


## Segment k's fill, 0..1000: a body already shattered is empty, the body fighting is its HP (empty while it
## shatters, filling with its rise), a body still to come is full.
static func segment_permille(w: World, k: int) -> int:
	var f := w.final_fight
	if f == null:
		return 0
	if k < f.phase or f.won:
		return 0
	if k > f.phase:
		return 1000
	var i := body_index(w)
	if i < 0 or f.shatter_t > 0:
		return 0
	var a := w.actors
	var fill := clampi(a.hp[i] * 1000 / maxi(1, a.max_hp[i]), 0, 1000)
	if a.state[i] == EnemyAi.State.SPAWN:
		fill = (
			fill * clampi(a.state_t[i] * 1000 / maxi(1, w.tuning.boss_intro_ticks), 0, 1000) / 1000
		)
	return fill
