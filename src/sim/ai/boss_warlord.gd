class_name BossWarlord
extends RefCounted
## The Warlord's own mechanics (BossTable.warlord, a BossWarlordTable; BossFightStore.wl_*): a War Banner in one
## phase and the Duel's javelin cage in another (BossDuel), one big mechanic at a time.
## - The rhythm: each of those phases has one big mechanic. Its first is due banner_first_ticks / duel_first_ticks
##   after the phase's gate (the first tick the boss stands in it), each next one banner_gap_ticks / duel_gap_ticks
##   after the last one ended. Once due it begins when the boss is between attacks (an attack in progress, its
##   follow-up and its recovery finish first) and no great javelin of its is out (thrown, embedded or flying back);
##   it waits otherwise. While its cast runs the boss stands and starts nothing (BossTide.due answers HOLD, the
##   cooldown kept up a tick so the pick waits too); while a banner or a duel stands it throws no great javelin
##   (may_use). A banner standing as its phase ends falls.
## - The War Banner: after its cast a circle of banner_radius_m stands where the boss stood, banner_ticks, or until
##   the lane a charge of the boss's sweeps (its body plus the contact slop) passes within banner_pole_m of its pole.
##   While the boss's centre is inside it its attack cooldowns run at banner_cooldown per mille of their length (a
##   cooldown tick counts 1000 / banner_cooldown ticks); while the hero's centre is inside it the hero's hits and damage
##   ticks on the boss are worth banner_damage per mille (Damage, taken_permille). So the fight inside is shorter and
##   more dangerous, and a charge drawn through the pole ends it.
## - With the hero dead or outside the room the banner falls and a duel ends without its recall (cancel); with the
##   boss gone everything goes (on_boss_gone). The clocks start once the boss reaches its first phase with either, so
##   the phases before hash as before.
## Pure: no stream is drawn; everything follows from the clock and the positions.

const S := EnemyAi.State
const M := BossAttackTable.Move
## The big mechanics (state "running" / "next").
const NONE := 0
const BANNER := 1
const DUEL := 2
## The banner's stages (BossFightStore.wl_bn_stage).
const CAST := 1
const STANDS := 2
## Why a banner fell (BANNER_FALLEN's amount): its time, a charge through its pole, the phase or the fight ending.
const FELL_TIME := 0
const FELL_CHARGE := 1
const FELL_CLEARED := 2
## STATUS_APPLY effects, source the boss. BANNER_CAST: it begins planting (amount = the cast's ticks). PLANTED: the
## banner stands (pos = its pole, amount = its ticks). FALLEN: it is gone (pos = its pole, amount = FELL_*).
const BANNER_CAST := &"warlord_banner_cast"
const BANNER_PLANTED := &"warlord_banner_planted"
const BANNER_FALLEN := &"warlord_banner_fallen"


## Tick phase 6 (BossSignatures.advance, before a charge's burst arms): the Warlord runs its rhythm, its banner and
## its duel.
static func advance(w: World) -> void:
	var i := _runner(w)
	if i < 0:
		return
	if BossSlow.fight_over(w):
		cancel(w)
		return
	var wt := BossAi.table_of(w, i).warlord
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	_clock(w, i, wt, phase)
	_banner(w, i, wt)
	BossDuel.advance(w, i, wt)
	if may_begin(w, i):
		_begin(w, i, wt, phase)
	_cooldown(w, i, wt)


## The boss that runs them (its actor index), or -1. The first live one with them takes the clocks once it has
## reached their first phase; one at a time.
static func _runner(w: World) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	if fs.wl_boss >= 0:
		var i := a.index_of(fs.wl_boss)
		return i if i >= 0 and a.dead[i] == 0 else -1
	for b in bs.size():
		var t: BossTable = w.boss_tables[bs.table[b]]
		var i := a.index_of(bs.ids[b])
		if t.warlord == null or i < 0 or a.dead[i] == 1 or a.state[i] == S.SPAWN:
			continue
		if bs.phase[b] < t.warlord.first_phase():
			continue
		fs.clear_warlord()
		fs.wl_boss = bs.ids[b]
		return i
	return -1


## The table of boss i when it runs the Warlord's mechanics, else null.
static func table_of(w: World, i: int) -> BossWarlordTable:
	if i < 0 or w.boss_fight.wl_boss < 0 or w.actors.ids[i] != w.boss_fight.wl_boss:
		return null
	return BossAi.table_of(w, i).warlord


## The big mechanic `phase` plays (NONE when it plays none).
static func kind_of(wt: BossWarlordTable, phase: int) -> int:
	if phase == wt.banner_phase:
		return BANNER
	return DUEL if phase == wt.duel_phase else NONE


## True while a banner or a duel runs (its cast included).
static func running(w: World) -> bool:
	return w.boss_fight.wl_bn_stage != 0 or w.boss_fight.wl_du_stage != 0


## The phase's clock: a new phase (once its gate is over) starts its first beat's wait; a banner of another phase
## falls at once (at the gate).
static func _clock(w: World, i: int, wt: BossWarlordTable, phase: int) -> void:
	var fs := w.boss_fight
	if fs.wl_bn_stage != 0 and phase != wt.banner_phase:
		_fall(w, i, wt, FELL_CLEARED)
	if w.actors.state[i] == BossAi.GATE or phase == fs.wl_phase:
		return
	fs.wl_phase = phase
	match kind_of(wt, phase):
		BANNER:
			fs.wl_next = w.tick + wt.banner_first_ticks
		DUEL:
			fs.wl_next = w.tick + wt.duel_first_ticks
		_:
			fs.wl_next = -1


## True when boss i may begin its phase's big mechanic now: it is due, none runs, the boss is between attacks and no
## great javelin of its is out.
static func may_begin(w: World, i: int) -> bool:
	var wt := table_of(w, i)
	var fs := w.boss_fight
	if wt == null or running(w) or fs.wl_next < 0 or w.tick < fs.wl_next or w.player_dead():
		return false
	if fs.wl_phase != w.bosses.phase[BossAi.entry_of(w, i)]:
		return false
	if w.actors.state[i] != S.MOVE or BossGreatJavelin.is_out(w, w.actors.ids[i]):
		return false
	return kind_of(wt, fs.wl_phase) != NONE


static func _begin(w: World, i: int, wt: BossWarlordTable, phase: int) -> void:
	var fs := w.boss_fight
	fs.wl_next = -1
	if kind_of(wt, phase) == DUEL:
		BossDuel.begin(w, i, wt)
		return
	fs.wl_bn_stage = CAST
	fs.wl_bn_from = w.tick
	event(w, i, BANNER_CAST, w.actors.pos(i)).amount = wt.banner_cast_ticks


## True while boss i casts its banner or its duel: it stands and starts nothing.
static func casting(w: World, i: int) -> bool:
	var fs := w.boss_fight
	if fs.wl_boss < 0 or w.actors.ids[i] != fs.wl_boss:
		return false
	return fs.wl_bn_stage == CAST or fs.wl_du_stage == BossDuel.CAST


## Tick phase 5 (BossMaelstrom.holds): true while boss i casts, or its cast begins this tick: it takes no step.
static func stands(w: World, i: int) -> bool:
	return casting(w, i) or may_begin(w, i)


## BossTide.due for the Warlord (tick phase 3, between attacks): HOLD while it casts or its big mechanic may begin
## this tick (so no attack starts before tick phase 6 begins the cast), the cooldown kept up a tick so the pick waits
## as well as the punish and the gap-closer; else -1.
static func due(w: World, i: int) -> int:
	if not casting(w, i) and not may_begin(w, i):
		return -1
	w.actors.cd[i] = maxi(w.actors.cd[i], 1)
	return BossTide.HOLD


## BossAi._choose (through BossGreatJavelin.may_use): boss i may start attack atk now: no great javelin while a
## banner or a duel runs, and inside the cage only the duel's attacks.
static func may_use(w: World, i: int, atk: BossAttackTable) -> bool:
	var wt := table_of(w, i)
	if wt == null:
		return true
	if atk.move == M.GREAT_JAVELIN and running(w):
		return false
	if w.boss_fight.wl_du_stage < BossDuel.CAGE:
		return true
	var t := BossAi.table_of(w, i)
	for k in wt.duel_attacks:
		if t.attacks[k] == atk:
			return true
	return false


# --- the banner ---------------------------------------------------------------------------------------------------


static func _banner(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	if fs.wl_bn_stage == CAST:
		if w.tick - fs.wl_bn_from >= wt.banner_cast_ticks:
			var at := w.actors.pos(i)
			fs.wl_bn_stage = STANDS
			fs.wl_bn_from = w.tick
			fs.wl_bn_x = at.x
			fs.wl_bn_y = at.y
			event(w, i, BANNER_PLANTED, at).amount = wt.banner_ticks
	elif fs.wl_bn_stage == STANDS:
		if w.tick - fs.wl_bn_from >= wt.banner_ticks:
			_fall(w, i, wt, FELL_TIME)
		elif charge_through(w, i, pole(w), wt.banner_pole_m):
			_fall(w, i, wt, FELL_CHARGE)


## The banner's pole (its circle's centre).
static func pole(w: World) -> Vector2:
	return Vector2(w.boss_fight.wl_bn_x, w.boss_fight.wl_bn_y)


## True while boss i runs a charge whose swept lane (from where the run began to where the body is, its radius plus
## the contact slop each side) passes within `reach` of p.
static func charge_through(w: World, i: int, p: Vector2, reach: float) -> bool:
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	if a.state[i] != S.ACTIVE or atk == null or atk.move != M.CHARGE:
		return false
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	var half := a.radius[i] + EnemyAi.CONTACT_SLOP_M
	var run := maxf((a.pos(i) - from).dot(Kin.dir(a.lock_a[i])), 0.0) + half
	var lane := AttackShapes.lane(from, a.lock_a[i], run, half)
	return Collide.circle_vs_obb(p, maxf(reach, 0.01), lane) != Vector2.ZERO


static func _fall(w: World, i: int, wt: BossWarlordTable, why: int) -> void:
	var fs := w.boss_fight
	if fs.wl_bn_stage == 0:
		return
	var planted := fs.wl_bn_stage == STANDS
	fs.wl_bn_stage = 0
	fs.wl_bn_from = -1
	fs.wl_cd_acc = 0
	fs.wl_next = w.tick + wt.banner_gap_ticks
	if planted or why == FELL_CLEARED:
		event(w, i, BANNER_FALLEN, pole(w) if planted else w.actors.pos(i)).amount = why


## True when p is inside the standing banner's circle.
static func in_banner(w: World, wt: BossWarlordTable, p: Vector2) -> bool:
	if w.boss_fight.wl_bn_stage != STANDS:
		return false
	var off := p - pole(w)
	return off.x * off.x + off.y * off.y <= wt.banner_radius_m * wt.banner_radius_m


## Inside the banner the boss's cooldown runs ahead: each tick it adds 1000000 / banner_cooldown - 1000 per mille of
## a tick, and a whole tick taken off for each 1000.
static func _cooldown(w: World, i: int, wt: BossWarlordTable) -> void:
	var fs := w.boss_fight
	var a := w.actors
	if a.cd[i] <= 0 or a.state[i] != S.MOVE or not in_banner(w, wt, a.pos(i)):
		fs.wl_cd_acc = 0
		return
	fs.wl_cd_acc += 1000000 / maxi(1, wt.banner_cooldown) - 1000
	while fs.wl_cd_acc >= 1000 and a.cd[i] > 0:
		fs.wl_cd_acc -= 1000
		a.cd[i] -= 1


## Damage: the share of a hit or tick from the hero that boss `target` (an actor index) takes: banner_damage while the
## hero stands in its banner, else 1000.
static func taken_permille(w: World, target: int) -> int:
	var wt := table_of(w, target)
	if wt == null or not in_banner(w, wt, w.player_pos()):
		return 1000
	return wt.banner_damage


# --- the end of a fight -------------------------------------------------------------------------------------------


## The hero is dead or outside the room: the banner falls and the duel ends without its recall (the clocks stay).
static func cancel(w: World) -> void:
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.wl_boss) if fs.wl_boss >= 0 else -1
	if i < 0 or not running(w):
		return
	var wt := BossAi.table_of(w, i).warlord
	_fall(w, i, wt, FELL_CLEARED)
	BossDuel.end(w, i, wt, false)


## BossSignatures.on_boss_gone: the Warlord that ran them takes them with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.boss_fight.wl_boss == boss_id:
		w.boss_fight.clear_warlord()


static func event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_warlord) -------------------------------------------------------------------


## {} with no Warlord running them; else "boss" (its actor index), "running" (NONE, BANNER, DUEL), "next" (the big
## mechanic of this phase), "next_in" (ticks until it is due, 0 when due and waiting, -1 while one runs or the phase
## has none), "held" (it casts: it stands and starts nothing), "banner" ({} or "cast" (0..1000 through the cast, -1
## once it stands), "centre" (the pole; during the cast where the boss stands), "radius", "left" (ticks it still
## stands, -1 during the cast), "boss_inside", "hero_inside", "cooldown" and "damage" (per mille inside)) and "duel"
## (BossDuel.state: {} or the cage).
static func state(w: World) -> Dictionary:
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.wl_boss) if fs.wl_boss >= 0 else -1
	if i < 0:
		return {}
	var wt := BossAi.table_of(w, i).warlord
	var run := NONE
	if fs.wl_bn_stage != 0:
		run = BANNER
	elif fs.wl_du_stage != 0:
		run = DUEL
	var banner := {}
	if fs.wl_bn_stage != 0:
		var cast := fs.wl_bn_stage == CAST
		var at := w.actors.pos(i) if cast else pole(w)
		banner = {
			"cast":
			(
				clampi((w.tick - fs.wl_bn_from) * 1000 / maxi(1, wt.banner_cast_ticks), 0, 1000)
				if cast
				else -1
			),
			"centre": at,
			"radius": wt.banner_radius_m,
			"left": -1 if cast else maxi(0, fs.wl_bn_from + wt.banner_ticks - w.tick),
			"boss_inside": in_banner(w, wt, w.actors.pos(i)),
			"hero_inside": in_banner(w, wt, w.player_pos()),
			"cooldown": wt.banner_cooldown,
			"damage": wt.banner_damage,
		}
	return {
		"boss": i,
		"running": run,
		"next": kind_of(wt, fs.wl_phase),
		"next_in": maxi(0, fs.wl_next - w.tick) if fs.wl_next >= 0 else -1,
		"held": casting(w, i),
		"banner": banner,
		"duel": BossDuel.state(w, i, wt),
	}
