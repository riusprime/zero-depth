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
## v0.8.0 FB2 (owner F7, "Phase-by-phase mix": "her HP is set from your measured damage per second so she always lasts
## about 60 s however strong you are"): the fight measures the player's damage per second (note_damage, advance:
## FinalFight's meter) while a body that can be hurt is fought (not rising, gated or shattering, the player alive),
## except a body whose own HP comes from the meter (BossTable.dps_hp: the Prism). As such a body rises its HP is set
## from the meter (dps_hp_of; SIM_CONTRACTS "The final boss").
## v0.8.0 FB3 (owner F6, F7 "Nemesis takes its HP and damage from your own build, an even duel"): as a mimic body
## rises it reads the player's build (NemesisBuild.prepare: its weapon, hit, combo, shot and cards; its HP from the
## build), and while it fights the fight records the player's path and dashes (BossNemesis.record).
## Pure: no stream is drawn.

## BossAi state of a shattering body: after BossAi.GATE (6) and BossSignatures' egg states (7-9), which the views
## also read off the state alone.
const SHATTER := 10
## v0.9.5 BH6: BossAi state of the Fallen vanished in an interphase (BossInterphase.STATE).
const INTERPHASE := BossInterphase.STATE
## STATUS_APPLY effect ids for the views and the sound: a body shatters (amount = the phase it ends), a body rises
## (amount = the phase it begins).
const EFFECT_SHATTER := &"final_shatter"
const EFFECT_RISE := &"final_rise"


## Starts the fight in `w` (setup, or between ticks): body `phase` (0 = the first) rises at `at`.
static func begin(
	w: World, tables: PackedInt32Array, shatter_ticks: int, at: Vector2, phase: int = 0
) -> void:
	w.final_fight = FinalFight.create(tables, shatter_ticks)
	w.final_fight.home = at  # v0.8.0 FB2: the Prism floats back here
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


## Damage._apply (through BossGates.clamp_damage): a body before the last keeps 1 HP, whoever hits it. v0.8.0 N2: a
## hit not the world's own (owner_id != 0) goes through FinalPace first (The Fallen's window, the rate cap).
static func clamp_damage(w: World, i: int, amount: int, owner_id: int = 0) -> int:
	var f := w.final_fight
	if f == null or w.actors.ids[i] != f.body_id:
		return amount
	if f.ip_stage >= BossInterphase.STAGE_VANISHED and owner_id != 0:
		return 0  # v0.9.5 BH6: vanished, its HP is frozen (the world's own hit, the dev panel's Kill boss, still lands)
	if not f.last_phase():
		amount = mini(amount, maxi(0, w.actors.hp[i] - 1))
	return FinalPace.cap_hit(w, amount, owner_id)


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
	if measuring(w, i):  # v0.8.0 FB2: a measured tick of the fight (the meter's second runs on)
		f.dps_t += 1
		if f.dps_t >= SimTick.TICKS_PER_SECOND:
			f.close_second()
	var a := w.actors
	if f.shatter_t == 0 and a.dead[i] == 0:
		var t := w.boss_tables[f.tables[f.phase]]
		FinalPace.advance(w, i, t)  # v0.8.0 N2: its HP from the meter, its bucket, The Fallen's window cues
		if t.mimic:
			BossNemesis.record(w, i)  # v0.8.0 FB3: the echo of the player's path, their dashes
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
	var t := w.boss_tables[f.tables[phase]]
	if w.loop > 1:  # v0.9.5 BH1 (Q11, HC7): a looped run meets softer bodies (80 per mille per loop finished)
		var j := w.actors.index_of(f.body_id)
		var pm := w.actors.power[j] if w.actors.power[j] > 0 else 1000
		w.actors.power[j] = maxi(1, pm * FinalPace.damage_ease_permille(w) / 1000)
	if t.dps_hp and not t.pace:  # v0.8.0 FB2 (F7): her HP from the player's measured damage per second
		var i := w.actors.index_of(f.body_id)
		var hp := dps_hp_of(w, t)
		w.actors.max_hp[i] = hp
		w.actors.hp[i] = hp
	if t.mimic:  # v0.8.0 FB3 (F6, F7): the Nemesis reads the build; its HP from it
		NemesisBuild.prepare(w, w.actors.index_of(f.body_id), t, true)
	FinalPace.rise(w, w.actors.index_of(f.body_id), t)  # v0.8.0 N2 (O41): its HP from the meter, a fresh bucket
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


# --- v0.8.0 FB2: the damage meter (owner F7) ------------------------------------------------------------------------


## True while tick-phase-9's tick counts in the meter: the fight runs, the player lives, and body i can be hurt (not
## rising, gated or shattering) and is not itself measured against (BossTable.dps_hp).
static func measuring(w: World, i: int) -> bool:
	var f := w.final_fight
	if f == null or f.won or w.player_dead() or i < 0 or f.shatter_t > 0:
		return false
	if f.ip_stage >= BossInterphase.STAGE_VANISHED:
		return false  # v0.9.5 BH6: the interphase's seconds are not fought: the meter holds
	var s := w.actors.state[i]
	if s == EnemyAi.State.SPAWN or s == BossAi.GATE or s == SHATTER or w.actors.dead[i] == 1:
		return false
	return not w.boss_tables[f.tables[f.phase]].dps_hp


## Damage._apply: the player's hit (or damage over time) of `amount` on another actor counts while the meter runs.
static func note_damage(w: World, amount: int) -> void:
	if amount > 0 and measuring(w, body_index(w)):
		w.final_fight.dps_acc += amount


## [damage, seconds] the meter holds for table t (its last dps_seconds closed seconds).
static func measured(w: World, t: BossTable) -> Array[int]:
	if w.final_fight == null:
		return [0, 0]
	return w.final_fight.measured(t.dps_seconds)


## A dps_hp body's HP (owner F7): with at least dps_min_seconds measured, dps × dps_target_ticks / 60 ×
## window_permille / 1000 (dps = the damage over the seconds measured), else its table's hp; clamped to
## dps_hp_min..dps_hp_max. Integer maths (64-bit), so the same meter always gives the same HP.
## v0.8.0 N2 (owner O41): a paced body's is FinalPace's (its time at the measured rate from a square root).
static func dps_hp_of(w: World, t: BossTable) -> int:
	if t.pace:
		return FinalPace.hp_for(FinalPace.measured_milli(w, t), t, FinalPace.ease_permille(w))
	var m := measured(w, t)
	var hp := t.hp
	if m[1] > 0 and m[1] >= t.dps_min_seconds:
		hp = (
			m[0] * t.dps_target_ticks * t.window_permille / (m[1] * SimTick.TICKS_PER_SECOND * 1000)
		)
	return clampi(hp, t.dps_hp_min, maxi(t.dps_hp_min, t.dps_hp_max))
