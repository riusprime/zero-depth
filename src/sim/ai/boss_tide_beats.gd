class_name BossTideBeats
extends RefCounted
## The Tidecaller's fight rhythm: one big mechanic at a time (BossDanceTable.calm_ticks, resume_ticks, beat_*;
## BossStore.dance_beat_*). The big mechanics are the Pull (its bell, the pull and the push), a row of Riptide (all its
## casts) and a High Tide (its cast and its flood): the player can follow one, not three on their own clocks.
## - The order: a phase plays the big mechanics it has, the latest one first, then round again: High Tide (from
##   ht_phase), Riptide (from rip_phase), the Pull (before mael_phase, when the phase has a `tide` attack). So the
##   first phase is Pull after Pull, the second opens with the Riptide it brings, and the Maelstrom's has no Pull.
## - The spacing: the phase's first beat beat_first_ticks after it begins (after its gate, on the first tick the boss
##   stands); each next one calm_ticks and then the phase's beat_gap_ticks after the last one ended. Never two at once,
##   and never one sooner than calm_ticks after the last.
## - The hold: from the tick the next beat is due (it may wait for an attack already under way to finish), through
##   the beat, to resume_ticks after it ends, the ring stream and the crossing waves form nothing (BossStream) and the
##   boss starts no other attack (BossTide.due answers HOLD, the cooldown kept up a tick so the pick waits too).
## - The Pull is the boss's own attack: it starts through BossTide.due when its beat is due and the boss is between
##   attacks with its cooldown over; a Pull that starts some other way (a test, the dev panel) is still taken as the
##   beat running. Riptide and High Tide ask may_begin (BossDance) and report begin and end.
## Pure: no stream is drawn.

const NONE := 0
const PULL := 1
const RIPTIDE := 2
const HIGH_TIDE := 3


## Tick phase 6 (BossDance.advance, before its casts), boss i in `phase`: a Pull over ends its beat; the first tick
## the boss stands in a new phase starts that phase's order.
static func advance(w: World, i: int, t: BossTable, d: BossDanceTable, phase: int) -> void:
	var bs := w.bosses
	if bs.dance_beat_run == NONE and pulling(w, i):
		begin(w, t, d, phase, PULL)
	elif bs.dance_beat_run == PULL and not pulling(w, i):
		end(w, d, phase)
	if w.actors.state[i] == BossAi.GATE or phase == bs.dance_beat_phase:
		return
	bs.dance_beat_phase = phase
	bs.dance_beat_k = 0
	bs.dance_beat_at = w.tick + d.first_ticks(phase)


## The beats `phase` plays, in order.
static func order(t: BossTable, d: BossDanceTable, phase: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if phase >= d.ht_phase:
		out.append(HIGH_TIDE)
	if phase >= d.rip_phase:
		out.append(RIPTIDE)
	if phase < d.mael_phase and BossTide.signature_of(t, phase) >= 0:
		out.append(PULL)
	return out


## The next beat of `phase` (NONE when it plays none).
static func next_of(w: World, t: BossTable, d: BossDanceTable, phase: int) -> int:
	var o := order(t, d, phase)
	return NONE if o.is_empty() else o[w.bosses.dance_beat_k % o.size()]


## True when boss i (between attacks) may begin the big mechanic `kind` now: it is the next beat of this phase's
## order, its time has come, none runs and the calm since the last is over.
static func may_begin(
	w: World, i: int, t: BossTable, d: BossDanceTable, phase: int, kind: int
) -> bool:
	var bs := w.bosses
	if bs.dance_boss != w.actors.ids[i] or bs.dance_beat_run != NONE:
		return false
	if bs.dance_beat_phase != phase or bs.dance_beat_at < 0 or w.tick < bs.dance_beat_at:
		return false
	if bs.dance_beat_end >= 0 and w.tick < bs.dance_beat_end + d.calm_ticks:
		return false
	return w.actors.state[i] == EnemyAi.State.MOVE and next_of(w, t, d, phase) == kind


## The big mechanic `kind` begins now (the next beat of the order when it is that one).
static func begin(w: World, t: BossTable, d: BossDanceTable, phase: int, kind: int) -> void:
	var bs := w.bosses
	if bs.dance_beat_phase == phase and next_of(w, t, d, phase) == kind:
		bs.dance_beat_k += 1
	bs.dance_beat_run = kind
	bs.dance_beat_at = -1


## The big mechanic running ends now: the next beat comes after the calm and the phase's gap.
static func end(w: World, d: BossDanceTable, phase: int) -> void:
	var bs := w.bosses
	bs.dance_beat_run = NONE
	bs.dance_beat_end = w.tick
	bs.dance_beat_at = w.tick + d.calm_ticks + d.gap_ticks(phase)


## A beat that could not begin (a High Tide with no dry floor to give) is passed: the next one after the calm.
static func skip(w: World, t: BossTable, d: BossDanceTable, phase: int, kind: int) -> void:
	begin(w, t, d, phase, kind)
	end(w, d, phase)


## True while boss i (the one running the dance) holds its stream, its waves and its other attacks: a big mechanic
## runs, or the next is due, or the last ended less than resume_ticks ago.
static func holds(w: World, i: int) -> bool:
	var bs := w.bosses
	if bs.dance_boss != w.actors.ids[i]:
		return false
	if bs.dance_beat_run != NONE or pulling(w, i):
		return true
	var t := BossAi.table_of(w, i)
	if t.dance == null:
		return false
	if bs.dance_beat_at >= 0 and w.tick >= bs.dance_beat_at:  # Due (a phase with no beat holds nothing)
		if next_of(w, t, t.dance, bs.dance_beat_phase) != NONE:
			return true
	return bs.dance_beat_end >= 0 and w.tick < bs.dance_beat_end + t.dance.resume_ticks


## True while boss i's Pull runs: its bell rings, or the room pulls or pushes.
static func pulling(w: World, i: int) -> bool:
	var atk := BossAi.attack_of(w, i)
	if atk == null or atk.move != BossAttackTable.Move.TIDE:
		return false
	var st := w.actors.state[i]
	return st == EnemyAi.State.WINDUP or BossTide.phase_of(w, i) != BossTide.NONE


## BossTide.due for a boss with a dance (entry b, cooldown `cd`): its phase's Pull when the Pull's beat may begin and
## the cooldown is over; HOLD when it waits on the cooldown, or while the rhythm holds the boss's attacks; else -1.
static func pull_due(w: World, i: int, b: int, t: BossTable, cd: int) -> int:
	if w.player_dead():
		return -1
	var phase := w.bosses.phase[b]
	if may_begin(w, i, t, t.dance, phase, PULL):
		return BossTide.HOLD if cd > 0 else BossTide.signature_of(t, phase)
	if holds(w, i):
		w.actors.cd[i] = maxi(w.actors.cd[i], 1)  # The pick waits as well as the punish and the gap-closer
		return BossTide.HOLD
	return -1


## The cancel of the dance (the hero dead or out of the room): the beat running ends now.
static func cancel(w: World) -> void:
	var bs := w.bosses
	if bs.dance_beat_run == NONE:
		return
	var i := w.actors.index_of(bs.dance_boss)
	var d: BossDanceTable = BossAi.table_of(w, i).dance if i >= 0 else null
	if d == null:
		bs.dance_beat_run = NONE
		return
	end(w, d, bs.dance_beat_phase)


## The reader's "beats" (BossDance.state): "running" (NONE, PULL, RIPTIDE or HIGH_TIDE), "next" (the next beat's
## kind, NONE when the phase plays none), "in" (ticks until it may begin, 0 when due, -1 while one runs or before
## the phase's order starts), "held" (the stream and the other attacks wait) and "order" (the phase's beats).
static func state(w: World, i: int, t: BossTable, d: BossDanceTable, phase: int) -> Dictionary:
	var bs := w.bosses
	var running := bs.dance_beat_run
	if running == NONE and pulling(w, i):
		running = PULL
	return {
		"running": running,
		"next": next_of(w, t, d, phase),
		"in": maxi(0, bs.dance_beat_at - w.tick) if bs.dance_beat_at >= 0 else -1,
		"held": holds(w, i),
		"order": order(t, d, phase),
	}
