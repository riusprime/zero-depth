class_name FallenTheft
extends RefCounted
## The Fallen takes your cards (its signature; FallenRememberedTable.theft_*, BossFightStore.fl_tk_*).
## - When: at each theft gate (66 % and 33 % of its HP, each once) as a big beat of BossRemembered's rhythm. It waits
##   while a remembered mechanic is due by its own HP gate, cast or running, for the calm after one, and for the
##   mimic windows (BossRemembered.window_clear); then, the body between attacks and not dashing, a cast of
##   theft_cast_ticks begins. Nothing else starts during it (no mechanic, no window, no attack of its own: the same
##   holds BossRemembered uses), and its end counts as a mechanic's end (fl_end), so the calm follows it too.
## - What: the hero's strongest card (NemesisBuild.pick_cards' order) not already held; its wand slot stays where it is
##   but the card does nothing (WandLock). At most theft_held at once; a gate met while that many are held, or with no
##   card to take, passes with nothing cast. The card is among the casts of its mimic windows (FinalFight.casts):
##   nothing new is cast outside them.
## - Back: while it holds a card, a mark is on its back. Every hero hit that lands (HP taken) from its rear arc
##   (theft_half_arc either side of straight behind its facing) counts toward the oldest card held; theft_hits of them
##   give that card back. Hits from the front or the sides do not count.
## - Always back: every card goes back with the body (on_boss_gone, or a body no longer there on the next tick), when
##   the hero is dead, and with the world itself (a new floor, a new loop: a new World holds no theft).
## Events (STATUS_APPLY, source The Fallen): CAST (amount = its ticks), TAKEN (amount = the slot, amount_applied = the
## card's code), MARK_HIT (amount = the hits still needed, amount_applied = the card's code), RETURNED (amount = the
## slot, amount_applied = the card's code). Pure: no stream is drawn.

const CAST := &"fallen_theft_cast"
const TAKEN := &"fallen_card_taken"
const MARK_HIT := &"fallen_mark_hit"
const RETURNED := &"fallen_card_returned"
## As many cards as a wand may hold: the ranking reads them all.
const ALL_CARDS := 64


## True while its cast runs.
static func casting(w: World) -> bool:
	return w.boss_fight.fl_tk_from >= 0


## The first theft gate reached and not yet met (an index into theft_gates), or -1.
static func gate_due(w: World, i: int, m: FallenRememberedTable) -> int:
	var a := w.actors
	for g in m.theft_gates.size():
		if (
			w.boss_fight.fl_tk_gates & (1 << g) == 0
			and a.hp[i] * 1000 <= m.theft_gates[g] * a.max_hp[i]
		):
			return g
	return -1


## The card it would take now (the strongest not held), or -1.
static func target(w: World) -> int:
	var held := w.boss_fight.fl_tk_code
	for c in NemesisBuild.pick_cards(w, ALL_CARDS):
		if not held.has(c[0]):
			return c[0]
	return -1


## BossRemembered: true while the theft holds the rhythm (its cast runs, or it may be cast as soon as the body is
## free), so no remembered mechanic begins by its clock and the body starts no attack of its own meanwhile.
static func holds(w: World, i: int, m: FallenRememberedTable) -> bool:
	return casting(w) or _ready(w, i, m)


## BossRemembered.advance, every tick before the mechanics (body i The Fallen running them, -1 none): the cards go back
## when the body that holds them is gone or the hero is dead; a cast due begins; a cast over takes its card. True when
## the theft used the tick (its cast runs), so no mechanic begins on it.
static func advance(w: World, i: int, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	if fs.fl_tk_boss >= 0:
		var j := w.actors.index_of(fs.fl_tk_boss)
		if j < 0 or w.actors.dead[j] == 1 or j != i:
			give_back_all(w)
			fs.clear_theft()
			return false
	if w.player_dead():
		give_back_all(w)
		fs.fl_tk_from = -1
		return false
	if i < 0 or m == null:
		return false
	if casting(w):
		if w.tick - fs.fl_tk_from >= m.theft_cast_ticks:
			_take(w, i)
		return true
	var g := gate_due(w, i, m)
	if g < 0 or fs.fl_stage != BossRemembered.STAGE_NONE:
		return false
	if fs.fl_tk_code.size() >= m.theft_held or target(w) < 0:
		fs.fl_tk_gates |= 1 << g  # Nothing it can take: the gate passes silently
		return false
	if not _ready(w, i, m) or w.actors.state[i] != EnemyAi.State.MOVE or BossNemesis.dashing(w, i):
		return false
	fs.fl_tk_gates |= 1 << g
	fs.fl_tk_boss = w.actors.ids[i]
	fs.fl_tk_from = w.tick
	var f := w.final_fight
	f.rd_pending = 0  # No dash of its own leaves during the cast
	f.rd_t = 0
	f.dash_t = 0
	_event(w, i, CAST).amount = m.theft_cast_ticks
	return true


## A cast may begin as soon as the body is free: a theft gate is reached with a card to take and room to hold it, no
## mechanic is cast or runs, the calm after the last is over, a remembered gate is not waiting first and the windows
## leave room.
static func _ready(w: World, i: int, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	if (
		i < 0
		or m == null
		or fs.fl_boss != w.actors.ids[i]
		or fs.fl_stage != BossRemembered.STAGE_NONE
	):
		return false
	if gate_due(w, i, m) < 0 or fs.fl_tk_code.size() >= m.theft_held or w.player_dead():
		return false
	if w.tick < fs.fl_open or (fs.fl_end >= 0 and w.tick < fs.fl_end + m.calm_ticks):
		return false
	if BossRemembered.gate_pending(w, i, m) or not BossRemembered.window_clear(w, m):
		return false
	return target(w) >= 0


## The cast is over: the strongest card not held goes dark (none left to take: nothing happens), and the calm
## after a mechanic begins.
static func _take(w: World, i: int) -> void:
	var fs := w.boss_fight
	fs.fl_tk_from = -1
	fs.fl_end = w.tick
	var code := target(w)
	if code < 0:
		return
	fs.fl_tk_code.append(code)
	fs.fl_tk_hits.append(BossRemembered.table_of(w).theft_hits)
	w.refresh_build(false)
	_ensure_cast(w, i, code)
	var e := _event(w, i, TAKEN)
	e.amount = w.mod_slots.find(code)
	e.amount_applied = code


## The card held is among the casts its mimic windows use (the first card_casts): when the ranking moved since the
## body read the build, its copy takes the last place not held by another taken card.
static func _ensure_cast(w: World, i: int, code: int) -> void:
	var f := w.final_fight
	var t := BossAi.table_of(w, i)
	var n := t.card_casts
	for k in mini(n, f.casts.size()):
		if f.casts[k].code == code:
			return
	var c := NemesisBuild.compile_card(w, t, code, CardLevels.base_level(w, code))
	if f.casts.size() < n:
		f.casts.append(c)
		return
	for k in range(n - 1, -1, -1):
		if not w.boss_fight.fl_tk_code.has(f.casts[k].code):
			f.casts[k] = c
			return


## Damage.hit, a hero hit on `target` that took HP, arriving from `from`: counts on the mark when it lands in the rear
## arc of The Fallen that holds a card.
static func on_hit(w: World, target: int, from: Vector2) -> void:
	var fs := w.boss_fight
	if fs.fl_tk_code.is_empty() or w.actors.ids[target] != fs.fl_tk_boss:
		return
	var a := w.actors
	var m := BossRemembered.table_of(w)
	if m == null or from == a.pos(target):
		return
	var off := Kin.angle_diff(Kin.angle_of(from - a.pos(target)), a.facing[target])
	if off < 2048 - m.theft_half_arc:
		return
	fs.fl_tk_hits[0] -= 1
	var e := _event(w, target, MARK_HIT)
	e.amount = fs.fl_tk_hits[0]
	e.amount_applied = fs.fl_tk_code[0]
	if fs.fl_tk_hits[0] <= 0:
		_give_back(w, 0, target)


## Card k held goes back to its slot (an event at the body `at`, or at the hero when the body is gone).
static func _give_back(w: World, k: int, at: int) -> void:
	var fs := w.boss_fight
	var code := fs.fl_tk_code[k]
	fs.fl_tk_code.remove_at(k)
	fs.fl_tk_hits.remove_at(k)
	w.refresh_build(false)
	var id := w.actors.ids[at]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(at))
	e.effect_id = RETURNED
	e.amount = w.mod_slots.find(code)
	e.amount_applied = code


## Every card held goes back (the body gone, the hero dead).
static func give_back_all(w: World) -> void:
	var fs := w.boss_fight
	if fs.fl_tk_code.is_empty():
		return
	var j := w.actors.index_of(fs.fl_tk_boss) if fs.fl_tk_boss >= 0 else -1
	var at := j if j >= 0 else 0
	while not fs.fl_tk_code.is_empty():
		_give_back(w, 0, at)


## BossSignatures.on_boss_gone (through BossRemembered): the body that holds the cards gives them back.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var fs := w.boss_fight
	if fs.fl_tk_boss != boss_id:
		return
	fs.fl_tk_boss = -1
	give_back_all(w)
	fs.clear_theft()


static func _event(w: World, i: int, effect: StringName) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_fallen) --------------------------------------------------------------------


## The theft's part of WorldReader.boss_fallen: `taken` ([{slot, card (its id), code, hits_left, hits}], oldest
## first), `mark` ({} with none held, else `on` true, `dir` the rear arc's centre (a unit vector from the body),
## `half_arc` its half width (1/4096 turns), `hits_left`, `hits`), `theft_cast` (0..1000 through its cast, -1 none).
static func state(w: World, i: int, m: FallenRememberedTable) -> Dictionary:
	var fs := w.boss_fight
	var taken: Array[Dictionary] = []
	for k in fs.fl_tk_code.size():
		var code := fs.fl_tk_code[k]
		(
			taken
			. append(
				{
					"slot": w.mod_slots.find(code),
					"card":
					w.item_tables[code].id if code >= 0 and code < w.item_tables.size() else &"",
					"code": code,
					"hits_left": fs.fl_tk_hits[k],
					"hits": m.theft_hits,
				}
			)
		)
	var mark := {}
	if not taken.is_empty() and i >= 0:
		mark = {
			"on": true,
			"dir": -Kin.dir(w.actors.facing[i]),
			"half_arc": m.theft_half_arc,
			"hits_left": fs.fl_tk_hits[0],
			"hits": m.theft_hits,
		}
	var cast := -1
	if casting(w):
		cast = clampi((w.tick - fs.fl_tk_from) * 1000 / maxi(1, m.theft_cast_ticks), 0, 1000)
	return {"taken": taken, "mark": mark, "theft_cast": cast}
