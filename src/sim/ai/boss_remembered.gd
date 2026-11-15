class_name BossRemembered
extends RefCounted
## The Fallen remembers the run (BossTable.remembered, a FallenRememberedTable; BossFightStore.fl_*): it stays in the
## room and casts the mechanic of a boss killed in this run, one at a time, the big mechanics of its fight.
## - The pool: the mechanics of the bosses the run killed (BossFightStore.fl_beaten, from RunState.bosses_beaten):
##   the Clockwork Judge's Time Wave, the Tidecaller's Riptide, the Gatekeeper's quake pillars, the Twin Wardens'
##   ward. A boss with none of these is skipped. With none killed (a start straight at the final boss, the
##   Playground) the pool is Time Wave and Riptide. Never the same twice running when the pool holds more than one
##   (one draw from the ai stream).
## - The rhythm (owner: "space mechanics a bit a give it a good fight rythm not everything happening at the same
##   time"): one as soon as the HP falls to each gate (66 %, 33 %) and otherwise one every every_ticks counted from
##   the end of the last; never sooner than first_ticks after the body may first act, nor calm_ticks after the last
##   one ended. A cast waits while a mimic window runs, its warning shows, or one is due within calm_ticks or ended
##   less than calm_ticks ago; and a window waits while a mechanic runs and for calm_ticks after (holds_window,
##   FinalPace). Never two at once.
## - Each begins with a cast of cast_ticks (the body stands still; event CAST, amount = its ticks, amount_applied =
##   the kind, whose source boss is SOURCES[kind]), only while the body is between attacks (MOVE) and not dashing.
##   From the tick one is due until it ends the body starts no attack of its own (think keeps its cooldown up); the
##   quake pillars use its dash (FallenQuake).
## - The mechanics are the source bosses' own pieces, run with The Fallen's numbers and needing no source boss:
##   FallenTime (BossSlow, BossPickups, BossTime.place_orbs), FallenRiptide (BossDance's row), FallenQuake
##   (BossQuake), FallenWard (the ward and the amber Warden's shade, its charge and burst).
## - Everything ends with the body (on_boss_gone) and when the hero is dead (stop).
## Pure: the ai stream only (the pick; the pieces draw their own spots from it).

const NONE := 0
const TIME := 1
const RIPTIDE := 2
const QUAKE := 3
const WARD := 4
const KINDS: Array[int] = [TIME, RIPTIDE, QUAKE, WARD]
## The pool when the run killed none of the four.
const FALLBACK: Array[int] = [TIME, RIPTIDE]
## Each mechanic's source boss (its content id): the boss the run must have killed, and the colour a view gives it.
const SOURCES := {
	TIME: &"clockwork_judge",
	RIPTIDE: &"tidecaller",
	QUAKE: &"gatekeeper",
	WARD: &"twin_wardens",
}
const STAGE_NONE := 0
const STAGE_CAST := 1
const STAGE_RUN := 2
## STATUS_APPLY effects (source The Fallen): a cast begins (amount = its ticks, amount_applied = the kind); the
## mechanic begins (amount_applied = the kind); it ends (amount_applied = the kind).
const CAST := &"fallen_remembered_cast"
const BEGIN := &"fallen_remembered"
const END := &"fallen_remembered_end"
## The room's radius when no wall is found round the fight's centre (a test world), and its most (m).
const FALLBACK_R := 12.0
const MAX_R := 20.0


## The table of the body fighting now, or null.
static func table_of(w: World) -> FallenRememberedTable:
	var t := FinalPace.table(w)
	return t.remembered if t != null else null


## The actor index of The Fallen that runs the mechanics, or -1. The current body with remembered mechanics takes
## the clocks the first tick it may act (its rise over).
static func _fallen(w: World) -> int:
	var fs := w.boss_fight
	var a := w.actors
	if fs.fl_boss >= 0:
		var j := a.index_of(fs.fl_boss)
		return j if j >= 0 and a.dead[j] == 0 else -1
	var m := table_of(w)
	var i := FinalBoss.body_index(w)
	if m == null or i < 0 or a.dead[i] == 1 or a.state[i] == EnemyAi.State.SPAWN:
		return -1
	fs.clear_fallen()
	fs.fl_boss = a.ids[i]
	fs.fl_open = w.tick + m.first_ticks
	fs.fl_next = fs.fl_open
	fs.fl_r = _radius(w)
	return i


## The fight room's radius round its centre: the shortest clear run of sixteen ways (FALLBACK_R with no wall near,
## at most MAX_R).
static func _radius(w: World) -> float:
	var home := w.final_fight.home
	var best := 99.0
	for k in 16:
		best = minf(best, EnemyAi.clear_run(w, home, k * 256, 60.0, 0.05))
	return FALLBACK_R if best > 50.0 else minf(best, MAX_R)


## The floor its mechanics cut: the square round the fight's round room (Riptide's strips cover all of it).
static func room_of(w: World) -> Rect2:
	var r := w.boss_fight.fl_r
	return Rect2(w.final_fight.home - Vector2(r, r), Vector2(r, r) * 2.0)


## The square inside the round room (the orbs and the pillars rise there, so none is beyond its wall).
static func inner_of(w: World) -> Rect2:
	var h := w.boss_fight.fl_r * 0.7071
	return Rect2(w.final_fight.home - Vector2(h, h), Vector2(h, h) * 2.0)


## The mechanics it may cast: those of the bosses the run killed, else FALLBACK.
static func pool(w: World) -> Array[int]:
	var out: Array[int] = []
	for k in KINDS:
		if w.boss_fight.fl_beaten.has(String(SOURCES[k])):
			out.append(k)
	return out if not out.is_empty() else FALLBACK.duplicate()


# --- the rhythm ---------------------------------------------------------------------------------------------------


## The first HP gate reached and not yet cast (an index into the table's gates), or -1.
static func _gate_due(w: World, i: int, m: FallenRememberedTable) -> int:
	var a := w.actors
	for g in m.gates.size():
		if w.boss_fight.fl_gates & (1 << g) == 0 and a.hp[i] * 1000 <= m.gates[g] * a.max_hp[i]:
			return g
	return -1


## True when a mechanic is due now (its clock or a gate) and the calm since the last is over.
static func _due(w: World, i: int, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	if fs.fl_stage != STAGE_NONE or w.tick < fs.fl_open or w.player_dead():
		return false
	if fs.fl_end >= 0 and w.tick < fs.fl_end + m.calm_ticks:
		return false
	return w.tick >= fs.fl_next or _gate_due(w, i, m) >= 0


## True when the mimic windows leave room for a cast now: none runs or warns, none is due within calm_ticks and
## none ended less than calm_ticks ago (always true for a body without windows).
static func window_clear(w: World, m: FallenRememberedTable) -> bool:
	var t := FinalPace.table(w)
	if t == null or t.window_ticks <= 0:
		return true
	if FinalPace.window(w) != FinalPace.Mimic.OFF:
		return false
	var clock := FinalPace.window_clock(w)  # Off: [ticks to the next warning, the off stretch's length]
	return clock[0] >= m.calm_ticks and clock[1] - clock[0] >= m.calm_ticks


## True when a cast may begin as soon as the body is free.
static func may_cast(w: World, i: int, m: FallenRememberedTable) -> bool:
	return _due(w, i, m) and window_clear(w, m)


## FinalPace.advance: true while a mimic window must wait (a mechanic is cast or runs, or ended less than calm_ticks
## before the next tick).
static func holds_window(w: World) -> bool:
	var fs := w.boss_fight
	var m := table_of(w)
	if fs.fl_boss < 0 or m == null:
		return false
	if fs.fl_stage != STAGE_NONE:
		return true
	return fs.fl_end >= 0 and w.tick + 1 < fs.fl_end + m.calm_ticks


## BossAi.think (tick phase 3), body i with mimic rules: while a mechanic is due or runs it starts no attack of its
## own (its cooldown is kept up, so the pick waits).
static func think(w: World, i: int) -> void:
	var fs := w.boss_fight
	if fs.fl_boss != w.actors.ids[i]:
		return
	var m := table_of(w)
	if m != null and (fs.fl_stage != STAGE_NONE or may_cast(w, i, m)):
		w.actors.cd[i] = maxi(w.actors.cd[i], 1)


## BossNemesis.moves: true while body i stands still for its mechanic (the cast, the ward).
static func holds_still(w: World, i: int) -> bool:
	var fs := w.boss_fight
	if fs.fl_boss < 0 or fs.fl_boss != w.actors.ids[i]:
		return false
	return fs.fl_stage == STAGE_CAST or (fs.fl_stage == STAGE_RUN and fs.fl_kind == WARD)


# --- tick phase 6 -------------------------------------------------------------------------------------------------


## BossSignatures.advance: the cast begins when due, ends into its mechanic, and the mechanic runs to its end.
static func advance(w: World) -> void:
	var i := _fallen(w)
	if i < 0:
		return
	var fs := w.boss_fight
	var t := BossAi.table_of(w, i)
	var m := t.remembered
	if m == null:
		return
	if w.player_dead():
		stop(w, i)
		return
	match fs.fl_stage:
		STAGE_NONE:
			if (
				may_cast(w, i, m)
				and w.actors.state[i] == EnemyAi.State.MOVE
				and not BossNemesis.dashing(w, i)
			):
				_cast(w, i, m)
		STAGE_CAST:
			if w.tick - fs.fl_from >= m.cast_ticks:
				_begin(w, i, t, m)
		_:
			if _step(w, i, t, m):
				_end(w, i, m)


static func _cast(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	var f := w.final_fight
	var choices := pool(w)
	if choices.size() > 1 and choices.has(fs.fl_last):
		choices.remove_at(choices.find(fs.fl_last))
	var kind := choices[w.rng_ai.range_int(0, choices.size() - 1)]
	var g := _gate_due(w, i, m)
	if g >= 0:
		fs.fl_gates |= 1 << g
	fs.fl_kind = kind
	fs.fl_last = kind
	fs.fl_stage = STAGE_CAST
	fs.fl_from = w.tick
	fs.fl_n += 1
	f.rd_pending = 0  # No dash of its own leaves during the cast
	f.rd_t = 0
	f.dash_t = 0
	var e := _event(w, i, CAST)
	e.amount = m.cast_ticks
	e.amount_applied = kind


static func _begin(w: World, i: int, t: BossTable, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	fs.fl_stage = STAGE_RUN
	fs.fl_from = w.tick
	_event(w, i, BEGIN).amount_applied = fs.fl_kind
	var began := false
	match fs.fl_kind:
		TIME:
			began = FallenTime.begin(w, i, m)
		RIPTIDE:
			began = FallenRiptide.begin(w, i, m)
		QUAKE:
			began = FallenQuake.begin(w, i, t, m)
		WARD:
			began = FallenWard.begin(w, i, m)
	if not began:  # Nothing fitted the room: it is over at once
		_end(w, i, m)


## One tick of the mechanic running; true when it is over.
static func _step(w: World, i: int, t: BossTable, m: FallenRememberedTable) -> bool:
	match w.boss_fight.fl_kind:
		TIME:
			return FallenTime.step(w, i, m)
		RIPTIDE:
			return FallenRiptide.step(w, i, m)
		QUAKE:
			return FallenQuake.step(w, i, t, m)
		WARD:
			return FallenWard.step(w, i, m)
	return true


static func _end(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	var kind := fs.fl_kind
	_finish(w, i)
	fs.fl_end = w.tick
	fs.fl_next = w.tick + m.every_ticks
	_event(w, i, END).amount_applied = kind


## The mechanic running is put away (its orbs, strips, pillars, ward and shade), whatever its stage.
static func _finish(w: World, i: int) -> void:
	var fs := w.boss_fight
	if fs.fl_stage == STAGE_RUN:
		match fs.fl_kind:
			TIME:
				FallenTime.finish(w, i)
			RIPTIDE:
				FallenRiptide.finish(w)
			QUAKE:
				FallenQuake.finish(w, i)
			WARD:
				FallenWard.finish(w, i)
	fs.fl_stage = STAGE_NONE
	fs.fl_kind = NONE
	fs.fl_from = -1


## The hero is dead: the mechanic running ends at once.
static func stop(w: World, i: int) -> void:
	if w.boss_fight.fl_stage != STAGE_NONE:
		_finish(w, i)


## BossSignatures.on_boss_gone: The Fallen that ran them takes them with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var fs := w.boss_fight
	if fs.fl_boss != boss_id:
		return
	FallenTime.finish_for(w, boss_id)
	FallenRiptide.finish(w)
	FallenQuake.finish_for(w, boss_id)
	FallenWard.clear(w)
	fs.clear_fallen()


static func _event(w: World, i: int, effect: StringName) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_fallen) --------------------------------------------------------------------


## WorldReader.boss_fallen's dictionary (see there).
static func state(w: World) -> Dictionary:
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.fl_boss) if fs.fl_boss >= 0 else -1
	var m := table_of(w)
	if i < 0 or m == null:
		return {}
	var cast := -1
	var cast_left := 0
	if fs.fl_stage == STAGE_CAST:
		cast = clampi((w.tick - fs.fl_from) * 1000 / maxi(1, m.cast_ticks), 0, 1000)
		cast_left = maxi(0, fs.fl_from + m.cast_ticks - w.tick)
	var next_in := -1
	if fs.fl_stage == STAGE_NONE:
		var at := maxi(fs.fl_open, fs.fl_next)
		if _gate_due(w, i, m) >= 0:
			at = fs.fl_open
		if fs.fl_end >= 0:
			at = maxi(at, fs.fl_end + m.calm_ticks)
		next_in = maxi(0, at - w.tick)
	var gate := -1
	for g in m.gates.size():
		if fs.fl_gates & (1 << g) == 0:
			gate = m.gates[g]
			break
	return {
		"boss": i,
		"running": fs.fl_kind,
		"source": SOURCES.get(fs.fl_kind, &""),
		"stage": fs.fl_stage,
		"cast": cast,
		"cast_left": cast_left,
		"left": _left(w, m),
		"ended": fs.fl_last if fs.fl_stage == STAGE_NONE else NONE,
		"count": fs.fl_n,
		"next_in": next_in,
		"gate": gate,
		"pool": pool(w),
		"room": room_of(w),
		"ward": FallenWard.ward_state(w, m),
		"shade": FallenWard.shade_state(w, m, i),
		"burst": FallenWard.burst_state(w, m),
		"pillar_dash": FallenQuake.dash_state(w, i),
	}


## Ticks until the mechanic running ends by its own time (-1 none, or one that ends by what the hero does).
static func _left(w: World, m: FallenRememberedTable) -> int:
	var fs := w.boss_fight
	if fs.fl_stage != STAGE_RUN:
		return -1
	var since := w.tick - fs.fl_from
	match fs.fl_kind:
		TIME:
			return maxi(0, m.time_ticks - since)
		QUAKE:
			return maxi(0, m.pillar_ticks - since)
		WARD:
			if fs.fl_stun_until >= 0:
				return maxi(0, fs.fl_stun_until - w.tick)
			return maxi(0, m.ward_ticks - since)
	return -1
