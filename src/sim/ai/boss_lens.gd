class_name BossLens
extends RefCounted
## The Hive Lens's drones (BossTable.lens, a BossLensTable; BossFightStore.hl_*): they feed it, its own Focus Beam
## cuts them, and they come back. The burnt glass is BossGlass's and the Lattice BossLattice's; this file runs them.
## - Feeding, from feed_phase: each living drone of drone_kind takes feed_cut per mille off every hit and damage tick
##   from the hero on the boss, at most feed_cap (Damage, taken_permille). With none alive nothing changes.
## - The cut: while one of the boss's Focus Beams (beams) burns, a drone its lane touches (the same lane test the hero
##   is hit by: BossAi.lane_slice) is cut down by the boss itself; so a drone between the hero and the boss is one the
##   beam takes. The kill is the boss's (DRONE_CUT names it).
## - Sent again: resend_ticks after no drone is alive, arriving or being split off, the boss casts split_attack again
##   (BossTide.due, through due()), and a Lattice due with fewer than lat_min drones casts the split first.
## - The rhythm: while a Lattice is cast or runs the boss starts none of `holds` (may_use, unless_held); the Gaze and
##   the Lattice never overlap, neither starts during the other and calm_ticks of calm part them: a Gaze does not
##   start when a Lattice is due before the Gaze and its calm would be over.
## - Nothing begins while the boss kneels at a phase change; with the hero dead or outside the room the Lattice ends
##   and the glass goes (cancel); with the boss gone everything goes (on_boss_gone).
## Pure: the Lattice's turn is the only draw (ai stream); everything else follows from the clock and the positions.

const S := EnemyAi.State
const M := BossAttackTable.Move
## STATUS_APPLY effects for the views and the tests (source the boss). DRONE_CUT: its Focus Beam cut a drone down
## (target the drone, pos where it was).
const DRONE_CUT := &"lens_drone_cut"
## The damage effect id of the beam's cut.
const CUT_EFFECT := &"lens_beam_cut"


## Tick phase 6 (BossSignatures.advance, after the boss's own strikes): the boss with a lattice runs it.
static func advance(w: World) -> void:
	var i := _lens(w)
	if i < 0:
		return
	if BossSlow.fight_over(w):
		cancel(w)
		return
	var f := BossAi.table_of(w, i).lens
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	_watch_gaze(w, i)
	_cut(w, i, f)
	BossGlass.lay(w, i, f, phase)
	_resend_clock(w, i, f, phase)
	BossGlass.advance(w, i, f)
	BossLattice.advance(w, i, f, phase)
	if BossSlow.fight_over(w):  # A strand or the glass just killed the hero
		cancel(w)


## The boss that runs the lattice (its actor index), or -1. The first live one with a lattice takes the clocks once it
## has reached the lattice's first phase (so its earlier phase hashes as before); one at a time.
static func _lens(w: World) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	if fs.hl_boss >= 0:
		var i := a.index_of(fs.hl_boss)
		return i if i >= 0 and a.dead[i] == 0 else -1
	for b in bs.size():
		var t: BossTable = w.boss_tables[bs.table[b]]
		var i := a.index_of(bs.ids[b])
		if t.lens == null or i < 0 or a.dead[i] == 1 or a.state[i] == S.SPAWN:
			continue
		if bs.phase[b] < t.lens.first_phase():
			continue
		fs.clear_lens()
		fs.hl_boss = bs.ids[b]
		return i
	return -1


## The lattice of boss i when it runs one, else null.
static func lens_of(w: World, i: int) -> BossLensTable:
	if i < 0 or w.boss_fight.hl_boss < 0 or w.actors.ids[i] != w.boss_fight.hl_boss:
		return null
	return BossAi.table_of(w, i).lens


## The drones of drone_kind alive now (actor indices, ascending).
static func drones(w: World, f: BossLensTable) -> PackedInt32Array:
	var out := PackedInt32Array()
	if f.drone_kind < 0:
		return out
	var a := w.actors
	for j in range(1, a.size()):
		if a.kinds[j] == f.drone_kind and a.dead[j] == 0:
			out.append(j)
	return out


# --- feeding --------------------------------------------------------------------------------------------------------


## Damage: the share of a hit or tick from the hero that boss `target` (an actor index) takes: feed_cut per mille less
## for each living drone from feed_phase (at most feed_cap less), else 1000.
static func taken_permille(w: World, target: int) -> int:
	var f := lens_of(w, target)
	if f == null or w.bosses.phase[BossAi.entry_of(w, target)] < f.feed_phase:
		return 1000
	return 1000 - cut_permille(w, f)


## The cut the living drones give now (per mille).
static func cut_permille(w: World, f: BossLensTable) -> int:
	return mini(f.feed_cap, drones(w, f).size() * f.feed_cut)


# --- the cut ----------------------------------------------------------------------------------------------------------


## True while boss i burns one of its Focus Beams.
static func burning(w: World, i: int, f: BossLensTable) -> bool:
	var b := BossAi.entry_of(w, i)
	var atk := BossAi.attack_of(w, i)
	return (
		atk != null
		and w.actors.state[i] == S.ACTIVE
		and w.actors.state_t[i] < atk.active_ticks
		and f.beams.has(w.bosses.attack[b])
	)


## Every drone a burning Focus Beam's lane touches this tick is cut down by the boss.
static func _cut(w: World, i: int, f: BossLensTable) -> void:
	if not burning(w, i, f):
		return
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	var st := a.state_t[i]
	for j in drones(w, f):
		for k in atk.count:
			var o := BossAi.lane_slice(w, i, k, st)
			if o == null or Collide.circle_vs_obb(a.pos(j), a.radius[j], o) == Vector2.ZERO:
				continue
			var at := a.pos(j)
			var id := a.ids[i]
			var hp := a.hp[j]
			a.invuln[j] = 0
			Damage.hit(
				w,
				j,
				maxi(1, a.max_hp[j]) * 100,
				id,
				id,
				w.take_root(),
				SimEvent.TAG_AREA,
				at,
				at,
				CUT_EFFECT
			)
			if a.dead[j] == 1:
				w.boss_fight.hl_cuts += 1
				var e := event(w, i, DRONE_CUT, at)
				e.target_id = a.ids[j]
				e.amount = hp
			break


# --- sent again ---------------------------------------------------------------------------------------------------


static func _splitting(w: World, i: int, f: BossLensTable) -> bool:
	var s := w.actors.state[i]
	return (
		w.bosses.attack[BossAi.entry_of(w, i)] == f.split_attack
		and (s == S.WINDUP or s == S.ACTIVE)
	)


## The clock of the drones sent again: it runs while none is alive, arriving or being split off.
static func _resend_clock(w: World, i: int, f: BossLensTable, phase: int) -> void:
	var fs := w.boss_fight
	if phase < f.feed_phase or f.drone_kind < 0:
		return
	if BossAi.alive_of(w, f.drone_kind) > 0 or _splitting(w, i, f):
		fs.hl_empty_at = -1
	elif fs.hl_empty_at < 0:
		fs.hl_empty_at = w.tick


## True when boss i should cast its split now: the drones' re-send is due, or a Lattice is due with too few drones.
static func split_wanted(w: World, i: int, f: BossLensTable) -> bool:
	var fs := w.boss_fight
	if f.split_attack < 0 or _splitting(w, i, f) or w.pending_enemies_of(f.drone_kind) > 0:
		return false
	if fs.hl_empty_at >= 0 and w.tick - fs.hl_empty_at >= f.resend_ticks:
		return true
	return BossLattice.due(w) and drones(w, f).size() < f.lat_min


## BossTide.due for a boss with a lattice (entry b, cooldown `cd`): its split when split_wanted and the cooldown is
## over; HOLD while it waits on the cooldown (the punish and the gap-closer wait too); else -1.
static func due(w: World, i: int, b: int, _t: BossTable, cd: int) -> int:
	var f := lens_of(w, i)
	if f == null or w.player_dead() or w.bosses.phase[b] < f.feed_phase:
		return -1
	if not split_wanted(w, i, f):
		return -1
	return BossTide.HOLD if cd > 0 else f.split_attack


# --- the rhythm ---------------------------------------------------------------------------------------------------


## Notes the last tick the Gaze winds up or burns.
static func _watch_gaze(w: World, i: int) -> void:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if atk != null and atk.move == M.GAZE and (s == S.WINDUP or s == S.ACTIVE):
		w.boss_fight.hl_gaze_end = w.tick


## True while a Gaze of boss i winds up or burns.
static func gazing(w: World, i: int) -> bool:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	return atk != null and atk.move == M.GAZE and (s == S.WINDUP or s == S.ACTIVE)


## BossAi._choose: false for an attack boss i may not start now (the Siege Engine's cover rule first): one of `holds`
## while a Lattice is cast or runs, and a Gaze that would meet a Lattice or its calm.
static func may_use(w: World, i: int, atk: BossAttackTable) -> bool:
	if not BossSiege.may_use(w, i, atk):
		return false
	var f := lens_of(w, i)
	if f == null:
		return true
	if BossLattice.busy(w) and _held(w, i, f, atk):
		return false
	return atk.move != M.GAZE or _gaze_may_start(w, f, atk)


## BossChallenge's punish and gap-closer: attack k of boss entry b, or -1 while may_use holds it back.
static func unless_held(w: World, b: int, k: int) -> int:
	if k < 0:
		return k
	var i := w.actors.index_of(w.bosses.ids[b])
	if i < 0 or lens_of(w, i) == null:
		return k
	return k if may_use(w, i, BossAi.table_of(w, i).attacks[k]) else -1


static func _held(w: World, i: int, f: BossLensTable, atk: BossAttackTable) -> bool:
	var t := BossAi.table_of(w, i)
	for k in f.holds:
		if t.attacks[k] == atk:
			return true
	return false


## A Gaze may start when no Lattice is cast or runs, the calm after the last is over, and the next is not due before
## this Gaze and its calm would be over.
static func _gaze_may_start(w: World, f: BossLensTable, atk: BossAttackTable) -> bool:
	var fs := w.boss_fight
	if BossLattice.busy(w):
		return false
	if fs.hl_end >= 0 and w.tick - fs.hl_end < f.calm_ticks:
		return false
	if fs.hl_due < 0:
		return true
	return fs.hl_due - w.tick >= atk.windup_ticks + atk.active_ticks + f.calm_ticks


# --- the end of a fight -------------------------------------------------------------------------------------------


## The hero is dead or outside the room: the Lattice ends and the glass goes (the feeding stays with the drones).
static func cancel(w: World) -> void:
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.hl_boss) if fs.hl_boss >= 0 else -1
	BossLattice.stop(w, i)
	BossGlass.clear(w, i)


## BossSignatures.on_boss_gone: the boss that ran the lattice takes it and its glass with it (its drones go back to
## their own ways).
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.boss_fight.hl_boss != boss_id:
		return
	BossLattice.free_drones(w)
	w.boss_fight.clear_lens()


## A STATUS_APPLY event of boss i's (BossLattice's and BossGlass's too).
static func event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_lens) ----------------------------------------------------------------------


## {} with no boss running a lattice; else "boss" (its actor index), "drones" ([{"id", "position"}]: the drones that
## feed it), "taken" (the share of the hero's damage it takes now, per mille), "cut" (1000 - taken), "cuts" (drones
## its beam has cut down), "resend_in" (ticks until its split is due again, -1 none counting), "lattice"
## (BossLattice.state), "lattice_in" (ticks until the next is due, 0 when due, -1 not in its phase yet), "gazing",
## "calm_left" (ticks of calm left after the last Lattice, 0 none), "glass" (BossGlass.rows).
static func state(w: World) -> Dictionary:
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.hl_boss) if fs.hl_boss >= 0 else -1
	if i < 0:
		return {}
	var f := BossAi.table_of(w, i).lens
	var feeders: Array[Dictionary] = []
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	if phase >= f.feed_phase:
		for j in drones(w, f):
			feeders.append({"id": w.actors.ids[j], "position": w.actors.pos(j)})
	var taken := taken_permille(w, i)
	var resend := -1
	if fs.hl_empty_at >= 0:
		resend = maxi(0, fs.hl_empty_at + f.resend_ticks - w.tick)
	var calm := 0
	if fs.hl_end >= 0:
		calm = maxi(0, fs.hl_end + f.calm_ticks - w.tick)
	return {
		"boss": i,
		"drones": feeders,
		"taken": taken,
		"cut": 1000 - taken,
		"cuts": fs.hl_cuts,
		"resend_in": resend,
		"lattice": BossLattice.state(w, i, f),
		"lattice_in": maxi(0, fs.hl_due - w.tick) if fs.hl_due >= 0 else -1,
		"gazing": gazing(w, i),
		"calm_left": calm,
		"glass": BossGlass.rows(w, f),
	}
